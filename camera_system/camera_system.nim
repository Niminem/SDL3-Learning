import ../vendor/sdl3/sdl3
import pkg/[glm]

# NOTE: probably should add to a shared constants module
const WorldUp* = vec3f(0, 1, 0) # (global) World's `up` vector

type
    PerspectiveCamera* = ref object
        position*: Vec3f
        front*: Vec3f
        up*: Vec3f
        right*: Vec3f
        yaw*: float32
        pitch*: float32
        fov*: float32
        aspectRatio*: float32
        nearPlane*: float32
        farPlane*: float32
        sensitivity*: float32
        velocity*: float32
        projectionMatrix*: Mat4f # MUST be updated after modifying camera fov, aspect ratio, near, far
        viewMatrix*: Mat4f # MUST be updated after modifying camera position, front, up

proc updateCameraVectors*(cam: PerspectiveCamera) # fwd decl
proc updateProjectionMatrix*(cam: PerspectiveCamera) # fwd decl
proc initCamera*(fov, aspect, near, far: float32): PerspectiveCamera =
    # fov — Camera frustum vertical field of view.
    # aspect — Camera frustum aspect ratio.
    # near — Camera frustum near plane.
    # far — Camera frustum far plane.
    # Together these define the camera's viewing frustum.
    new result
    result.position = vec3f(0, 0, 0)
    result.front = vec3f(0, 0, -1)
    result.up = vec3f(0, 1, 0)
    result.yaw = -90.0'f32
    result.pitch = 0.0'f32
    result.fov = fov
    result.aspectRatio = aspect
    result.nearPlane = near
    result.farPlane = far
    result.sensitivity = 0.1'f32 # mouse sensitivity
    result.velocity = 2.0'f32 # units per second
    result.projectionMatrix = mat4f(1)
    result.viewMatrix = mat4f(1)
    result.updateCameraVectors()
    result.updateProjectionMatrix()

proc updateProjectionMatrix*(cam: PerspectiveCamera) =
    cam.projectionMatrix = perspective(cam.fov.radians, cam.aspectRatio, cam.nearPlane, cam.farPlane)

proc updateCameraVectors*(cam: PerspectiveCamera) =
    let front = vec3f(
        cos(cam.yaw.radians) * cos(cam.pitch.radians),
        sin(cam.pitch.radians),
        sin(cam.yaw.radians) * cos(cam.pitch.radians)
    )
    cam.front = normalize(front)
    cam.right = normalize(cross(cam.front, WorldUp))
    cam.up = normalize(cross(cam.right, cam.front))
    cam.viewMatrix = lookAt(cam.position, cam.position + cam.front, cam.up)

proc processKeyboard*(cam: PerspectiveCamera, direction: SDL_Scancode, deltaTime: float32) =
    let velocity = cam.velocity * deltaTime
    case direction
    of SDL_Scancode_W: cam.position += cam.front * velocity # forward
    of SDL_Scancode_S: cam.position -= cam.front * velocity # backward
    of SDL_Scancode_A: cam.position -= cam.right * velocity # left
    of SDL_Scancode_D: cam.position += cam.right * velocity # right
    of SDL_Scancode_Q: cam.position += cam.up * velocity # up
    of SDL_Scancode_E: cam.position -= cam.up * velocity # down
    else: discard
    cam.updateCameraVectors()

proc processMouseMovement*(cam: PerspectiveCamera, xoffset, yoffset: cfloat,
                           deltaTime: float32, constrainPitch = true) =
    let
        scaledXOffset = xoffset * cam.sensitivity
        scaledYOffset = yoffset * cam.sensitivity
    cam.yaw += scaledXOffset
    cam.pitch += scaledYOffset
    if constrainPitch:
        cam.pitch = clamp(cam.pitch, -89.0'f32, 89.0'f32)
    cam.updateCameraVectors()