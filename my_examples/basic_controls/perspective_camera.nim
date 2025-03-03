import pkg/[glm]
import constants

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
        projectionMatrix*: Mat4f # MUST be updated after modifying camera fov, aspect ratio, near, far
        viewMatrix*: Mat4f # MUST be updated after modifying camera position, front, up

proc updateCameraVectors*(cam: PerspectiveCamera) # fwd decl
proc updateProjectionMatrix*(cam: PerspectiveCamera) # fwd decl
proc newCamera*(fov, aspect, near, far: float32, position = vec3f(0,0,3)): PerspectiveCamera =
    # fov — Camera frustum vertical field of view.
    # aspect — Camera frustum aspect ratio.
    # near — Camera frustum near plane.
    # far — Camera frustum far plane.
    # Together these define the camera's viewing frustum.
    new result
    result.position = position
    result.front = vec3f(0, 0, -1)
    result.up = vec3f(0, 1, 0)
    result.yaw = -90.0'f32
    result.pitch = 0.0'f32
    result.fov = fov
    result.aspectRatio = aspect
    result.nearPlane = near
    result.farPlane = far
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