import std/[os, osproc, math]
import pkg/[sdl3, glm]

type
    UBO = object
        mvp {.align(16).}: Mat4[float32] # must be aligned to 16 bytes

proc readFileAsUint8(filename: string): seq[uint8] =
  let fileSize = getFileSize(filename)
  var file: File
  if not open(file, filename, fmRead):
    raise newException(IOError, "Failed to open shader file: " & filename)
  result = newSeq[uint8](fileSize)
  let bytesRead = readBytes(file, result, 0, fileSize)
  close(file)
  if bytesRead != fileSize:
    raise newException(IOError, "Failed to read the entire shader file: " & filename)

proc loadShader(gpu: SDL_GPUDevice; filename: string; stage: SDL_GPUShaderStage; 
                format: SDL_GPUShaderFormat; uniformBuffersCount: uint32 = 0): SDL_GPUShader =

    var code = readFileAsUint8(filename)
    assert code.len > 0, "Failed to read shader file: " & filename

    let shaderInfo = SDL_GPUShaderCreateInfo(
        code_size: code.len.uint32,
        code: cast[ptr UncheckedArray[uint8]](addr code[0]),
        entrypoint: cstring"main",
        format: format,
        stage: stage,
        num_uniform_buffers: uniformBuffersCount
    )
    result = SDL_CreateGPUShader(gpu, addr shaderInfo)

proc main =
    SDL_SetLogPriorities(SDL_LOG_PRIORITY_VERBOSE)

    let init = SDL_Init(SDL_INIT_VIDEO)
    assert init, "SDL_Init failed: " & $SDL_GetError()

    let window = SDL_CreateWindow("Hello, World!", 1280, 720, 0)
    assert window != nil, "SDL_CreateWindow failed: " & $SDL_GetError()

    var gpu = SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_SPIRV, false, nil)
    assert gpu != nil, "SDL_CreateGPUDevice failed: " & $SDL_GetError()
    let claimed = SDL_ClaimWindowForGPUDevice(gpu, window)
    assert claimed, "SDL_ClaimWindowForGPUDevice failed: " & $SDL_GetError()

    let
        vertShader = gpu.loadShader(currentSourcePath.parentDir() / "vertex.spv.vert",
                                    SDL_GPU_SHADERSTAGE_VERTEX, SDL_GPU_SHADERFORMAT_SPIRV, 1)
        fragShader = gpu.loadShader(currentSourcePath.parentDir() / "vertex.spv.frag",
                                    SDL_GPU_SHADERSTAGE_FRAGMENT, SDL_GPU_SHADERFORMAT_SPIRV, 0)

    # Setting up Vertex Buffer
    # - create vertex data
    var vertexData: seq[Vec3f]  = @[vec3f(-0.5, -0.5, 0), vec3f(0, 0.5, 0), vec3f(0.5, -0.5, 0)]
    let verticesByteSize = vertexData.len * sizeof(vertexData[0])
    # - describe vertex attributes and vertex buffers in the pipeline (see pipelineInfo below)
    # - create vertex buffer
    var
        vertexBuffInfo = SDL_GPUBufferCreateInfo(
            usage: SDL_GPU_BUFFERUSAGE_VERTEX,
            size: uint32 verticesByteSize
            )
        vertexBuff = SDL_CreateGPUBuffer(gpu, addr vertexBuffInfo)
    # - upload vertex data to the vertex buffer
    #    - create a transfer buffer (basically allocate some memory on the GPU)
    let
        transferBuffInfo = SDL_GPUTransferBufferCreateInfo(
            usage: SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            size: uint32 verticesByteSize
        ) # keep in mind, the transfer buffer is simply an amount of memory we want to allocate on the GPU
          # and we can include more than just the veritces, but also indices, textures, etc. in ONE go.
        transferBuff = SDL_CreateGPUTransferBuffer(gpu, addr transferBuffInfo)
        transferBuffLocation = SDL_GPUTransferBufferLocation(
            transfer_buffer: transferBuff,
            #offset: 0 # starting byte of the buffer data in the transfer buffer
        )
    #    - map transfer buffer mem & copy from cpu
    let transferMem = SDL_MapGPUTransferBuffer(gpu, transferBuff, cycle=false)
                                               # Notes on 'cycling':
                                               # https://wiki.libsdl.org/SDL3/CategoryGPU#a-note-on-cycling
                                               # we're keeping it false here because we're not going
                                               # to update the data, and we're doing this before any binding
                                               # or drawing. Use ChatGPT for better understanding.
    copyMem(transferMem, addr vertexData[0], verticesByteSize)
    SDL_UnmapGPUTransferBuffer(gpu, transferBuff) # now the memory is on the GPU side (transfer buffer)
                                                  # we want to now invoke some commands to copy this data
                                                  # to the buffer we want to use for rendering (vertex buffer)
    #    - begin copy pass
    let
        copyCmdBuff = SDL_AcquireGPUCommandBuffer(gpu)
        copyPass = SDL_BeginGPUCopyPass(copyCmdBuff)
    #    - invoke upload commands (basically will copy data from transfer buffer to real buffers)
    let dest = SDL_GPUBufferRegion(
        buffer: vertexBuff,
        offset: 0,
        size: uint32 verticesByteSize
    )
    SDL_UploadToGPUBuffer(copyPass, addr transferBuffLocation, addr dest, cycle=false) # again, we're not updating
                                                                                       # the data, so cycle=false
    #    - end copy pass & submit the command buffer
    SDL_EndGPUCopyPass(copyPass)
    assert SDL_SubmitGPUCommandBuffer(copyCmdBuff), "SDL_SubmitGPUCommandBuffer failed: " & $SDL_GetError()
    #    - release the transfer buffer (free the memory in this case since we don't need it anymore)
    SDL_ReleaseGPUTransferBuffer(gpu, transferBuff)
    # - when we draw, we want to bind the vertex buffer to the render pass (see SDL_BindGPUVertexBuffers below)
    var vertexBuffBinding = [SDL_GPUBufferBinding(
        buffer: vertexBuff,
        offset: 0
    )]
    var vbDescriptions = [
        SDL_GPUVertexBufferDescription(
            slot: 0, # we can have multiple vertex buffers, so slots are used to differentiate them
            pitch: uint32 sizeof(Vec3f), # num of bytes between consecutive vertex
            input_rate: SDL_GPU_VERTEXINPUTRATE_VERTEX # is it a vertex buffer or instance buffer?
        )]
    var vertexAttrs = [
        SDL_GPUVertexAttribute(
            location: 0, # location in the shader where the attribute is expected
            # buffer_slot: 0, # binding slot of associated vertex buffer
            format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, # format of the attribute
            offset: 0 # offset in bytes from the start of the vertex buffer (we only have one attribute, so 0)
        )
    ]
    var ctDescriptions = [
    SDL_GPUColorTargetDescription(
        format: SDL_GetGPUSwapchainTextureFormat(gpu, window))]
    let pipelineInfo = SDL_GPUGraphicsPipelineCreateInfo(
        vertex_shader: vertShader,
        fragment_shader: fragShader,
        primitive_type: SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
        vertex_input_state: SDL_GPUVertexInputState(
            num_vertex_buffers: 1,
            vertex_buffer_descriptions: cast[ptr UncheckedArray[SDL_GPUVertexBufferDescription]](
                                        addr vbDescriptions[0]
            ),
            num_vertex_attributes: uint32 vertexAttrs.len,
            vertex_attributes: cast[ptr UncheckedArray[SDL_GPUVertexAttribute]](
                                addr vertexAttrs[0]
            )
        ),
        target_info: SDL_GPUGraphicsPipelineTargetInfo(
            num_color_targets: 1,
            color_target_descriptions: cast[ptr UncheckedArray[SDL_GPUColorTargetDescription]](
                                       addr ctDescriptions[0]
                                       )
        )
    )
    let pipeline = SDL_CreateGPUGraphicsPipeline(gpu, addr pipelineInfo)
    assert pipeline != nil, "SDL_CreateGPUGraphicsPipeline failed: " & $SDL_GetError()

    SDL_ReleaseGPUShader(gpu, vertShader)
    SDL_ReleaseGPUShader(gpu, fragShader)

    var windowSize: tuple[x,y: int32] = (0, 0)
    let gotWindowSize = SDL_GetWindowSize(window, addr windowSize.x, addr windowSize.y)
    assert gotWindowSize, "SDL_GetWindowSize failed: " & $SDL_GetError()
    
    let
        projectionMatrix = perspective[float32](degToRad(90.0), # fov
                                                                      windowSize.x.float / windowSize.y.float, # aspect
                                                                      0.0001, 1000.0) # near, far
        rotationSpeed = degToRad(90.0'f32) # 90 degrees per second
    var rotation = 0.0'f32
    var ubo: UBO

    var
        quit = false
        lastTick = SDL_GetTicks()
    while not quit:
        var
            newTick = SDL_GetTicks()
            deltaTime = (newTick - lastTick).float / 1000.0
        lastTick = newTick
        var event: SDL_Event
        while SDL_PollEvent(event):
            if event.type == SDL_EVENT_QUIT: quit = true
            elif event.type == SDL_EVENT_KEYDOWN:
                if event.key.scancode == SDL_SCANCODE_ESCAPE: quit = true
            else: continue

        var cmdBuff = SDL_AcquireGPUCommandBuffer(gpu)
        var swapchainTxtr: SDL_GPUTexture
        let acquired: bool = SDL_WaitAndAcquireGPUSwapchainTexture(cmdBuff, window, addr swapchainTxtr, nil, nil)
        assert acquired, "SDL_WaitAndAcquireGPUSwapchainTexture failed: " & $SDL_GetError()
    
        # update uniform buffer
        rotation += rotationSpeed * deltaTime
        let modelMatrix = mat4(1.0'f32).translate(0, 0, -2).rotate(rotation, vec3(0'f32,1,0))
        ubo.mvp = projectionMatrix * modelMatrix

        if swapchainTxtr != nil:
            let colorTargetInfo = SDL_GPUColorTargetInfo(
                texture: swapchainTxtr,
                load_op: SDL_GPULoadOp.SDL_GPU_LOADOP_CLEAR,
                store_op: SDL_GPUStoreOp.SDL_GPU_STOREOP_STORE,
                clear_color: SDL_FColor(r: 0.2, g: 0.2, b: 0.2, a: 1.0)
            )
            let renderPass = SDL_BeginGPURenderPass(cmdBuff, addr colorTargetInfo, 1, nil)
            SDL_BindGPUGraphicsPipeline(renderPass, pipeline)
            SDL_BindGPUVertexBuffers(renderPass, 0, addr vertexBuffBinding[0], 1)
            SDL_PushGPUVertexUniformData(cmdBuff, slot_index= 0, addr ubo, uint32 sizeof(ubo))
            SDL_DrawGPUPrimitives(renderPass, 3, 1, 0, 0)
            SDL_EndGPURenderPass(renderPass)
            let sumbitted = SDL_SubmitGPUCommandBuffer(cmdBuff)
            assert sumbitted, "SDL_SubmitGPUCommandBuffer failed: " & $SDL_GetError()

    SDL_ReleaseGPUGraphicsPipeline(gpu, pipeline)
    SDL_ReleaseWindowFromGPUDevice(gpu, window)
    SDL_DestroyWindow(window)
    SDL_DestroyGPUDevice(gpu)
    SDL_Quit()



when isMainModule:
    let
        vertPath = "glslc " & currentSourcePath.parentDir() / "vertex.glsl.vert -o " &
                           currentSourcePath.parentDir() / "vertex.spv.vert"
        compiledVert = execCmdEx(vertPath)
    if compiledVert.exitCode != 0:
        echo compiledVert.output
        quit(QuitFailure)
    let
        fragPath = "glslc " & currentSourcePath.parentDir() / "vertex.glsl.frag -o " &
                           currentSourcePath.parentDir() / "vertex.spv.frag"
        compiledFrag = execCmdEx(fragPath)
    if compiledFrag.exitCode != 0:
        echo compiledFrag.output
        quit(QuitFailure)
    main()