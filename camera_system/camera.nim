import std/[os, osproc, math]
import pkg/[glm, stb_image/read]
import ../vendor/sdl3/sdl3
import perspective_camera, basic_controller, input_manager
# note: only using load function and RGBA constant from stb_image

type
    VertexData = object
        position: Vec3f
        color: SDL_FColor
        uv: Vec2f
    UBO = object
        mvp {.align(16).}: Mat4[float32]

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
                format: SDL_GPUShaderFormat; uniformBuffersCount: uint32;
                num_samplers: uint32): SDL_GPUShader =

    var code = readFileAsUint8(filename)
    assert code.len > 0, "Failed to read shader file: " & filename

    let shaderInfo = SDL_GPUShaderCreateInfo(
        code_size: code.len.uint32,
        code: cast[ptr UncheckedArray[uint8]](addr code[0]),
        entrypoint: cstring"main",
        format: format,
        stage: stage,
        num_uniform_buffers: uniformBuffersCount,
        num_samplers: num_samplers
    )
    result = SDL_CreateGPUShader(gpu, addr shaderInfo)

proc main =
    SDL_SetLogPriorities(SDL_LOG_PRIORITY_VERBOSE)

    let init = SDL_Init(SDL_INIT_VIDEO)
    assert init, "SDL_Init failed: " & $SDL_GetError()

    let window = SDL_CreateWindow("Wubba lubba dub duuuuuuub!!!", 2000, 1200, 0)
    assert window != nil, "SDL_CreateWindow failed: " & $SDL_GetError()

    let gpu = SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_SPIRV, false, nil)
    assert gpu != nil, "SDL_CreateGPUDevice failed: " & $SDL_GetError()
    let claimed = SDL_ClaimWindowForGPUDevice(gpu, window)
    assert claimed, "SDL_ClaimWindowForGPUDevice failed: " & $SDL_GetError()

    let
        vertShader = gpu.loadShader(currentSourcePath.parentDir() / "camera.spv.vert",
                                    SDL_GPU_SHADERSTAGE_VERTEX, SDL_GPU_SHADERFORMAT_SPIRV,
                                    uniformBuffersCount=1, num_samplers=0)
        fragShader = gpu.loadShader(currentSourcePath.parentDir() / "camera.spv.frag",
                                    SDL_GPU_SHADERSTAGE_FRAGMENT, SDL_GPU_SHADERFORMAT_SPIRV,
                                    uniformBuffersCount=0, num_samplers=1)

    var imgSizeX, imgSizeY: int
    var channelsInFile: int
    let
        pixels = load(currentSourcePath.parentDir() / "cobblestone.png", imgSizeX, imgSizeY,
                      channelsInFile, desired_channels=RGBA)
        pixelsByteSize = imgSizeX * imgSizeY * RGBA

    let
        textureInfo = SDL_GPUTextureCreateInfo(
            `type`: SDL_GPU_TEXTURETYPE_2D,
            format: SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
            usage: SDL_GPU_TEXTUREUSAGE_SAMPLER,
            width: uint32 imgSizeX,
            height: uint32 imgSizeY,
            layer_count_or_depth: 1,
            num_levels: 1,
        )
        texture = SDL_CreateGPUTexture(gpu, addr textureInfo)
    
    const White = SDL_FColor(r: 1, g: 1, b: 1, a: 1)

    var vertexData = @[
        VertexData(position: vec3f(-0.5, 0.5, 0),
                   color: White,
                   uv: vec2f(0, 0)),
        VertexData(position: vec3f(0.5, 0.5, 0),
                   color: White,
                   uv: vec2f(1, 0)),
        VertexData(position: vec3f(-0.5, -0.5, 0),
                   color: White,
                   uv: vec2f(0, 1)),
        VertexData(position: vec3f(0.5, -0.5, 0),
                   color: White,
                   uv: vec2f(1, 1))
        ]
    let
        verticesByteSize = vertexData.len * sizeof(vertexData[0])
        vertexBuffInfo = SDL_GPUBufferCreateInfo(
            usage: SDL_GPU_BUFFERUSAGE_VERTEX,
            size: uint32 verticesByteSize
            )
        vertexBuff = SDL_CreateGPUBuffer(gpu, addr vertexBuffInfo)

    let
        indices: seq[uint16] = @[
            0'u16, 1, 2,
            2, 1, 3
        ]
        indicesByteSize = indices.len * sizeof(indices[0])
        indexBuffInfo = SDL_GPUBufferCreateInfo(
            usage: SDL_GPU_BUFFERUSAGE_INDEX,
            size: uint32 indicesByteSize
        )
        indexBuff = SDL_CreateGPUBuffer(gpu, addr indexBuffInfo)

    let
        transferBuffInfo = SDL_GPUTransferBufferCreateInfo(
            usage: SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            size: uint32 (verticesByteSize + indicesByteSize)
        )
        transferBuff = SDL_CreateGPUTransferBuffer(gpu, addr transferBuffInfo)
        transferBuffLocation = SDL_GPUTransferBufferLocation(
            transfer_buffer: transferBuff,
            offset: uint32 0
        )
        transferBuffLocation2 = SDL_GPUTransferBufferLocation(
            transfer_buffer: transferBuff,
            offset: uint32 verticesByteSize
        )

    let transferMem = SDL_MapGPUTransferBuffer(gpu, transferBuff, cycle=false)
    var bytePtr = cast[ptr UncheckedArray[byte]](transferMem)
    copyMem(bytePtr[0].addr, addr vertexData[0], verticesByteSize)
    copyMem(bytePtr[verticesByteSize].addr, addr indices[0], indicesByteSize)
    SDL_UnmapGPUTransferBuffer(gpu, transferBuff)

    let
        textureTransferBuffInfo = SDL_GPUTransferBufferCreateInfo(
            usage: SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            size: uint32 pixelsByteSize
        )
        textureTransferBuff = SDL_CreateGPUTransferBuffer(gpu, addr textureTransferBuffInfo)
        textureTransferMem = SDL_MapGPUTransferBuffer(gpu, textureTransferBuff, cycle=false)
    copyMem(textureTransferMem, addr pixels[0], pixelsByteSize)
    SDL_UnmapGPUTransferBuffer(gpu, textureTransferBuff)

    let copyCmdBuff = SDL_AcquireGPUCommandBuffer(gpu)
    let copyPass = SDL_BeginGPUCopyPass(copyCmdBuff)
    let vertexBuffDest = SDL_GPUBufferRegion(
        buffer: vertexBuff,
        offset: 0,
        size: uint32 verticesByteSize
    )
    let indexBuffDest = SDL_GPUBufferRegion(
        buffer: indexBuff,
        offset: 0,
        size: uint32 indicesByteSize
    )
    SDL_UploadToGPUBuffer(copyPass, addr transferBuffLocation, addr vertexBuffDest, cycle=false)
    SDL_UploadToGPUBuffer(copyPass, addr transferBuffLocation2, addr indexBuffDest, cycle=false)

    let
        textureSrc = SDL_GPUTextureTransferInfo(
            transfer_buffer: textureTransferBuff,
            offset: uint32 0,
        )
        textureDest = SDL_GPUTextureRegion(
            texture: texture,
            mip_level: uint32 0,
            layer: uint32 0,
            x: uint32 0,
            y: uint32 0,
            z: uint32 0,
            w: uint32 imgSizeX,
            h: uint32 imgSizeY,
            d: uint32 1
        )
    SDL_UploadToGPUTexture(copyPass, addr textureSrc, addr textureDest, cycle=false)

    SDL_EndGPUCopyPass(copyPass)
    assert SDL_SubmitGPUCommandBuffer(copyCmdBuff), "SDL_SubmitGPUCommandBuffer failed: " & $SDL_GetError()
    SDL_ReleaseGPUTransferBuffer(gpu, transferBuff)
    SDL_ReleaseGPUTransferBuffer(gpu, textureTransferBuff)

    let
        samplerInfo = SDL_GPUSamplerCreateInfo()
    var sampler = SDL_CreateGPUSampler(gpu, addr samplerInfo)
    var textureSamplerBindings = @[SDL_GPUTextureSamplerBinding(
                texture: texture,
                sampler: sampler
                )]

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
        SDL_GPUVertexAttribute(
            location: 2,
            format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
            offset: uint32 offsetOf(VertexData, uv)
        )
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
    
    let cam = newCamera(45.0'f32, windowSize.x.float / windowSize.y.float, 0.1'f32, 100.0'f32)
    cam.position = vec3f(0, 0, 3)

    var controls = initBasicController(cam)
    var ubo: UBO # Uniform buffer object

    var lastTick = SDL_GetTicks() # init time
    while pollInputEvents() and not isKeyPressed(SDL_SCANCODE_ESCAPE):
        let
            newTick = SDL_GetTicks()
            deltaTime = (newTick - lastTick).float32 / 1000.0'f32
        lastTick = newTick

        # Update camera
        controls.update(deltaTime)

        let cmdBuff = SDL_AcquireGPUCommandBuffer(gpu)
        var swapchainTxtr: SDL_GPUTexture
        let acquired: bool = SDL_WaitAndAcquireGPUSwapchainTexture(cmdBuff, window, addr swapchainTxtr, nil, nil)
        assert acquired, "SDL_WaitAndAcquireGPUSwapchainTexture failed: " & $SDL_GetError()
    
        # rotation += rotationSpeed * deltaTime
        # let modelMatrix = mat4(1.0'f32).translate(0, 0, -1.5).rotate(rotation, vec3(0'f32,1,0))
        # ubo.mvp = projectionMatrix * modelMatrix

        ubo.mvp = cam.projectionMatrix * cam.viewMatrix

        if swapchainTxtr != nil: # can be nil if the window is minimized, mouse clicks (holds) window borders, etc.
            let colorTargetInfo = SDL_GPUColorTargetInfo(
                texture: swapchainTxtr,
                load_op: SDL_GPULoadOp.SDL_GPU_LOADOP_CLEAR,
                store_op: SDL_GPUStoreOp.SDL_GPU_STOREOP_STORE,
                clear_color: SDL_FColor(r: 0.2, g: 0.2, b: 0.2, a: 1.0)
            )
            let renderPass = SDL_BeginGPURenderPass(cmdBuff, addr colorTargetInfo, 1, nil)
            SDL_BindGPUGraphicsPipeline(renderPass, pipeline)
            SDL_BindGPUVertexBuffers(renderPass, 0, addr vertexBuffBinding[0], 1)
            SDL_BindGPUIndexBuffer(renderPass, addr indexBuffBinding, SDL_GPU_INDEXELEMENTSIZE_16BIT)
            SDL_PushGPUVertexUniformData(cmdBuff, slot_index= 0, addr ubo, uint32 sizeof(ubo))
            SDL_BindGPUFragmentSamplers(renderPass, first_slot = uint32 0,
                                        addr textureSamplerBindings[0], num_bindings = uint32 1)
            SDL_DrawGPUIndexedPrimitives(renderPass, 6, 1, 0, 0, 0)
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
        vertPath = "glslc " & currentSourcePath.parentDir() / "camera.glsl.vert -o " &
                           currentSourcePath.parentDir() / "camera.spv.vert"
        compiledVert = execCmdEx(vertPath)
    if compiledVert.exitCode != 0:
        echo compiledVert.output
        quit(QuitFailure)
    let
        fragPath = "glslc " & currentSourcePath.parentDir() / "camera.glsl.frag -o " &
                           currentSourcePath.parentDir() / "camera.spv.frag"
        compiledFrag = execCmdEx(fragPath)
    if compiledFrag.exitCode != 0:
        echo compiledFrag.output
        quit(QuitFailure)
    main()