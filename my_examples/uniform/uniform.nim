import std/[os, osproc, math]
import pkg/[sdl3, glm] # using nim-glm (TODO: wrap C version of GLM for real game dev)

type
    UBO = object
        mvp {.align(16).}: Mat4[float32] # must be aligned to 16 bytes according to docs

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
        vertShader = gpu.loadShader(currentSourcePath.parentDir() / "uniform.spv.vert",
                                    SDL_GPU_SHADERSTAGE_VERTEX, SDL_GPU_SHADERFORMAT_SPIRV, 1)
        fragShader = gpu.loadShader(currentSourcePath.parentDir() / "uniform.spv.frag",
                                    SDL_GPU_SHADERSTAGE_FRAGMENT, SDL_GPU_SHADERFORMAT_SPIRV)

    var colorDescriptions: array[1, SDL_GPUColorTargetDescription] = [
    SDL_GPUColorTargetDescription(
        format: SDL_GetGPUSwapchainTextureFormat(gpu, window)
    )
    ]
    let pipelineInfo = SDL_GPUGraphicsPipelineCreateInfo(
        vertex_shader: vertShader,
        fragment_shader: fragShader,
        primitive_type: SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
        target_info: SDL_GPUGraphicsPipelineTargetInfo(
            num_color_targets: 1,
            color_target_descriptions: cast[ptr UncheckedArray[SDL_GPUColorTargetDescription]](addr colorDescriptions[0])
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
                                                                      0.1, 1000.0) # near, far
        rotationSpeed = degToRad(90.0'f32) # 90 degrees per second
    var rotation = 0.0'f32

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
        let
            modelMatrix = mat4(1.0'f32).translate(0, 0, -2).rotate(rotation, vec3(0'f32,1,0))
            ubo = UBO(mvp: projectionMatrix * modelMatrix)

        if swapchainTxtr != nil:
            let colorTargetInfo = SDL_GPUColorTargetInfo(
                texture: swapchainTxtr,
                load_op: SDL_GPULoadOp.SDL_GPU_LOADOP_CLEAR,
                store_op: SDL_GPUStoreOp.SDL_GPU_STOREOP_STORE,
                clear_color: SDL_FColor(r: 0.2, g: 0.2, b: 0.2, a: 1.0)
            )
            let renderPass = SDL_BeginGPURenderPass(cmdBuff, addr colorTargetInfo, 1, nil)
            SDL_BindGPUGraphicsPipeline(renderPass, pipeline)
            # there are two main kinds of data that we can pass to the GPU:
            # 1. vertex attribute - per vertex data (e.g. position, normal, texcoord)
            # 2. uniforms - data that is uniform across the entire draw call (e.g. projection matrix, model matrix)
            # below we are pushing a uniform buffer object (UBO) to the GPU
            SDL_PushGPUVertexUniformData(cmdBuff, 0, addr ubo, uint32 sizeof(ubo)) # slot reflects binding in shader
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
        vertPath = "glslc " & currentSourcePath.parentDir() / "uniform.glsl.vert -o " &
                           currentSourcePath.parentDir() / "uniform.spv.vert"
        compiledVert = execCmdEx(vertPath)
    if compiledVert.exitCode != 0:
        echo compiledVert.output
        quit(QuitFailure)
    let
        fragPath = "glslc " & currentSourcePath.parentDir() / "uniform.glsl.frag -o " &
                           currentSourcePath.parentDir() / "uniform.spv.frag"
        compiledFrag = execCmdEx(fragPath)
    if compiledFrag.exitCode != 0:
        echo compiledFrag.output
        quit(QuitFailure)
    main()