# using indexed drawing to draw a quad.
# a quad is made up of 4 vertices, while a triangle is made up of 3 vertices.
# we can't draw a quad directly in SDL GPU so we draw it as 2 triangles,
# but using indexed drawing we can draw a quad with 4 vertices by reusing 2 vertices
# for the 2 triangles. Otherwise, we would need 6 vertices to draw a quad without
# indexed drawing.
#
# what is an index (indices)?
# basically just an index of a vertex in the vertex buffer.
# this means we can specify the same vertex multiple times and reuse it multiple times.

import std/[os, osproc, math]
import pkg/[sdl3, glm]

type
    VertexData = object
        position: Vec3f
        color: SDL_FColor
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

    let gpu = SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_SPIRV, false, nil)
    assert gpu != nil, "SDL_CreateGPUDevice failed: " & $SDL_GetError()
    let claimed = SDL_ClaimWindowForGPUDevice(gpu, window)
    assert claimed, "SDL_ClaimWindowForGPUDevice failed: " & $SDL_GetError()

    let
        vertShader = gpu.loadShader(currentSourcePath.parentDir() / "index.spv.vert",
                                    SDL_GPU_SHADERSTAGE_VERTEX, SDL_GPU_SHADERFORMAT_SPIRV, 1)
        fragShader = gpu.loadShader(currentSourcePath.parentDir() / "index.spv.frag",
                                    SDL_GPU_SHADERSTAGE_FRAGMENT, SDL_GPU_SHADERFORMAT_SPIRV, 0)

    var vertexData = @[
        VertexData(position: vec3f(-0.5, 0.5, 0), color: SDL_FColor(r: 1, g: 1, b: 0, a: 1)), # tl
        VertexData(position: vec3f(0.5, 0.5, 0), color: SDL_FColor(r: 0, g: 1, b: 0, a: 1)), # tr
        VertexData(position: vec3f(-0.5, -0.5, 0), color: SDL_FColor(r: 1, g: 1, b: 0, a: 1)), # bl
        VertexData(position: vec3f(0.5, -0.5, 0), color: SDL_FColor(r: 0, g: 1, b: 1, a: 1)) # br
    ]
    let
        verticesByteSize = vertexData.len * sizeof(vertexData[0])
        vertexBuffInfo = SDL_GPUBufferCreateInfo(
            usage: SDL_GPU_BUFFERUSAGE_VERTEX,
            size: uint32 verticesByteSize
            )
        vertexBuff = SDL_CreateGPUBuffer(gpu, addr vertexBuffInfo)

    let # note: this can either be uint16 or uint32 (depending on size of vertex buffer)
        indices: seq[uint16] = @[
            0'u16, 1, 2,
            2, 1, 3
        ] # notice we are reusing vertices 1 and 2 for the 2nd triangle
        indicesByteSize = indices.len * sizeof(indices[0])
        indexBuffInfo = SDL_GPUBufferCreateInfo(
            usage: SDL_GPU_BUFFERUSAGE_INDEX,
            size: uint32 indicesByteSize
        ) # index buffer is created exactly like a vertex buffer, but with SDL_GPU_BUFFERUSAGE_INDEX
        indexBuff = SDL_CreateGPUBuffer(gpu, addr indexBuffInfo)

    let
        transferBuffInfo = SDL_GPUTransferBufferCreateInfo(
            usage: SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            size: uint32 (verticesByteSize + indicesByteSize) # we need to upload both the vertex and index buffers
                                                              # and can do so in a single transfer buffer
        )
        transferBuff = SDL_CreateGPUTransferBuffer(gpu, addr transferBuffInfo)
        transferBuffLocation = SDL_GPUTransferBufferLocation(
            transfer_buffer: transferBuff,
            offset: uint32 0
        )
        transferBuffLocation2 = SDL_GPUTransferBufferLocation(
            transfer_buffer: transferBuff,
            offset: uint32 verticesByteSize # we need to upload the indices after the vertices
        )

    let transferMem = SDL_MapGPUTransferBuffer(gpu, transferBuff, cycle=false)
    # below we are copying the indices to the transfer buffer after the vertex data.
    # we create a ptr to an array of bytes, copying the vertex data to the start of the transfer buffer
    # and then copying the indices to the transfer buffer after the vertex data.
    var bytePtr = cast[ptr UncheckedArray[byte]](transferMem)
    copyMem(bytePtr[0].addr, addr vertexData[0], verticesByteSize)
    copyMem(bytePtr[verticesByteSize].addr, addr indices[0], indicesByteSize)
    SDL_UnmapGPUTransferBuffer(gpu, transferBuff)
    let copyCmdBuff = SDL_AcquireGPUCommandBuffer(gpu)
    let copyPass = SDL_BeginGPUCopyPass(copyCmdBuff)
    let vertexBuffDest = SDL_GPUBufferRegion(
        buffer: vertexBuff,
        offset: 0, # starting byte within the buffer
        size: uint32 verticesByteSize
    )
    let indexBuffDest = SDL_GPUBufferRegion(
        buffer: indexBuff,
        offset: 0, # starting byte within the buffer
        size: uint32 indicesByteSize
    )
    SDL_UploadToGPUBuffer(copyPass, addr transferBuffLocation, addr vertexBuffDest, cycle=false)
    SDL_UploadToGPUBuffer(copyPass, addr transferBuffLocation2, addr indexBuffDest, cycle=false)

    SDL_EndGPUCopyPass(copyPass)
    assert SDL_SubmitGPUCommandBuffer(copyCmdBuff), "SDL_SubmitGPUCommandBuffer failed: " & $SDL_GetError()
    SDL_ReleaseGPUTransferBuffer(gpu, transferBuff)

    let vertexBuffBinding = [SDL_GPUBufferBinding(
        buffer: vertexBuff,
        offset: 0
    )]
    let indexBuffBinding = SDL_GPUBufferBinding(
        buffer: indexBuff,
        offset: 0
    )
    let vbDescriptions = [
        SDL_GPUVertexBufferDescription(
            slot: 0,
            pitch: uint32 sizeof(VertexData),
            input_rate: SDL_GPU_VERTEXINPUTRATE_VERTEX 
        )]
    let vertexAttrs = [
        SDL_GPUVertexAttribute(
            location: 0,
            buffer_slot: 0,
            format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
            offset: uint32 offsetOf(VertexData, position)
        ),
        SDL_GPUVertexAttribute(
            location: 1,
            format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,
            offset: uint32 offsetOf(VertexData, color)
        ),
    ]
    let ctDescriptions = [
    SDL_GPUColorTargetDescription(
        format: SDL_GetGPUSwapchainTextureFormat(gpu, window))
    ]
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
    
    let projectionMatrix = perspective[float32](degToRad(90.0),
                                                                      windowSize.x.float / windowSize.y.float,
                                                                      0.0001, 1000.0)
    let rotationSpeed = degToRad(90.0'f32) # 90 degrees per second
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

        let cmdBuff = SDL_AcquireGPUCommandBuffer(gpu)
        var swapchainTxtr: SDL_GPUTexture
        let acquired: bool = SDL_WaitAndAcquireGPUSwapchainTexture(cmdBuff, window, addr swapchainTxtr, nil, nil)
        assert acquired, "SDL_WaitAndAcquireGPUSwapchainTexture failed: " & $SDL_GetError()
    
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
            SDL_BindGPUIndexBuffer(renderPass, addr indexBuffBinding, SDL_GPU_INDEXELEMENTSIZE_16BIT) # for uint16 indices
            SDL_PushGPUVertexUniformData(cmdBuff, slot_index= 0, addr ubo, uint32 sizeof(ubo))
            SDL_DrawGPUIndexedPrimitives(renderPass, 6, 1, 0, 0, 0) # drawing "indexed" primitives
                                                                    # note: notice how we can only bind 1 index buffer
                                                                    # 
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
        vertPath = "glslc " & currentSourcePath.parentDir() / "index.glsl.vert -o " &
                           currentSourcePath.parentDir() / "index.spv.vert"
        compiledVert = execCmdEx(vertPath)
    if compiledVert.exitCode != 0:
        echo compiledVert.output
        quit(QuitFailure)
    let
        fragPath = "glslc " & currentSourcePath.parentDir() / "index.glsl.frag -o " &
                           currentSourcePath.parentDir() / "index.spv.frag"
        compiledFrag = execCmdEx(fragPath)
    if compiledFrag.exitCode != 0:
        echo compiledFrag.output
        quit(QuitFailure)
    main()