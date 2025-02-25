import std/[oids]
import pkg/glm
import event_dispatcher

type
    Object3D* = ref object of EventDispatcher # NOTE: some fields commented out or non-existent for now
        # base properties
        uuid*: Oid # Unique number for this object instance.
        name*: string # Optional name of the object (doesn't need to be unique). Default is an empty string.
        parent*: Object3D
        children*: seq[Object3D]
        # Transform properties
        position*: Vec3f # A Vector3 representing the object's local position. Default is (0, 0, 0).
        rotation*: Vec3f # object's local rotation using Euler angles (pitch, yaw, roll)
        quaternion*: Quatf # Object's local rotation as a Quaternion.
        scale*: Vec3f # The object's local scale. Default is Vector3( 1, 1, 1 ).
        up*: Vec3f # This is used by the `lookAt` method, for example, to determine the orientation of the result.
                   # Default is Vector3( 0, 1, 0 ).
        # Transformation matrices
        matrix*: Mat4f # local transformation matrix
        matrixWorld*: Mat4f # The global transform of the object. If the Object3D has no parent,
                            # then it's identical to the local transform.
        modelViewMatrix*: Mat4f # This is passed to the shader and used to calculate the
                                # position of the object.
        # Flags
        visible*: bool # Object gets rendered if true. Default is true.
        frustumCulled*: bool # When this is set, it checks every frame if the object is in the
                             # frustum of the camera before rendering the object. If set to false
                             # the object gets rendered every frame even if it is not in the frustum
                             # of the camera. Default is true.
        matrixAutoUpdate*: bool # When this is set, it calculates the matrix of position,
                                # (rotation or quaternion) and scale every frame and also recalculates
                                # the matrixWorld property. Default is true.
        matrixWorldNeedsUpdate*: bool # When this is set, it calculates the matrixWorld in that frame
                                      # and resets this property to false. Default is false.
        # additional properties
        renderOrder*: int # This value allows the default rendering order of scene graph objects to be
                          # overridden although opaque and transparent objects remain sorted independently.
                          # When this property is set for an instance of Group, all descendants objects
                          # will be sorted and rendered together. Sorting is from lowest to highest
                          # renderOrder. Default value is 0.

# NOTE: I believe we need to have some global variables like we see in Three.js (ex: _position)
# I think this is used to avoid creating new objects every time we need to do some calculations.

