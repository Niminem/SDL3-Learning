import pkg/[glm]
import ../vendor/sdl3/sdl3
import perspective_camera, input_manager

type
    BasicController* = object
        camera*: PerspectiveCamera
        sensitivity*: float32 # mouse sensitivity
        velocity*: float32 # units per second (camera speed)
        panSpeed*: float32 # units per pixel (camera pan speed)
        velocityMultiplier*: float32 # speed multiplier for camera movement

proc initBasicController*(camera: PerspectiveCamera, sensitivity = 0.1'f32, velocity = 2.0'f32,
                          velocityMultiplier = 2.5'f32, panSpeed = 0.005'f32): BasicController =
    result.camera = camera
    result.sensitivity = sensitivity # mouse sensitivity (camera rotation speed)
    result.velocity = velocity # units per second (camera movement speed)
    result.panSpeed = panSpeed # units per pixel (camera pan speed)
    result.velocityMultiplier = velocityMultiplier # speed multiplier for camera movement

proc processKeyboard*(controller: var BasicController, deltaTime: float32) =
    if isKeyHeld(SDL_Scancode_Z): # reset camera position, orientation, and return early
        controller.camera.position = vec3f(0, 0, 3)
        controller.camera.yaw = -90.0'f32
        controller.camera.pitch = 0.0'f32
        controller.camera.updateCameraVectors()
        return

    let
        multiplier = if isKeyHeld(SDL_SCANCODE_LSHIFT): controller.velocityMultiplier else: 1.0'f32
        velocity = controller.velocity * multiplier * deltaTime
    var moveDir = vec3f(0, 0, 0)  # Accumulate movement directions
    if isKeyHeld(SDL_Scancode_W): moveDir += controller.camera.front   # forward
    if isKeyHeld(SDL_Scancode_S): moveDir -= controller.camera.front   # backward
    if isKeyHeld(SDL_Scancode_A): moveDir -= controller.camera.right   # left
    if isKeyHeld(SDL_Scancode_D): moveDir += controller.camera.right   # right
    if isKeyHeld(SDL_Scancode_E): moveDir += controller.camera.up      # up
    if isKeyHeld(SDL_Scancode_Q): moveDir -= controller.camera.up      # down

    if moveDir.length() > 0:
        moveDir = moveDir.normalize() * velocity  # Normalize and scale movement

    controller.camera.position += moveDir
    controller.camera.updateCameraVectors()

proc rotateCamera*(controller: var BasicController, xoffset, yoffset: cfloat, constrainPitch = true) =
    let
        scaledXOffset = xoffset * controller.sensitivity
        scaledYOffset = yoffset * controller.sensitivity
    controller.camera.yaw += scaledXOffset
    controller.camera.pitch += scaledYOffset
    if constrainPitch:
        controller.camera.pitch = clamp(controller.camera.pitch, -89.0'f32, 89.0'f32)
    controller.camera.updateCameraVectors()

proc panCamera*(controller: var BasicController, xoffset, yoffset: cfloat) =
    let
        panSpeed = controller.panSpeed
        rightMove = xoffset * panSpeed
        upMove = yoffset * panSpeed
    controller.camera.position += controller.camera.right * rightMove
    controller.camera.position -= controller.camera.up * upMove
    controller.camera.updateCameraVectors()

proc update*(controller: var BasicController, deltaTime: float32) =
    controller.processKeyboard(deltaTime) # process keyboard input

    if isMouseButtonPressed(SDL_BUTTON_RIGHT): # mouse look
        let (xoffset, yoffset) = getMouseDelta()
        controller.rotateCamera(xoffset, -yoffset)
    elif isMouseButtonPressed(SDL_BUTTON_MIDDLE): # mouse pan
        let (xoffset, yoffset) = getMouseDelta()
        controller.panCamera(xoffset, yoffset)

    let mouseWheelDelta = getMouseWheelDelta()
    if  mouseWheelDelta != 0: # mouse wheel zoom
        controller.camera.position += controller.camera.front *  mouseWheelDelta
        controller.camera.updateCameraVectors()