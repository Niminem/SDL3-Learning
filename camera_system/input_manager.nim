import std/[tables, packedsets]
import ../vendor/sdl3/sdl3

type
    KeyState* = enum
        Pressed, Released, Held, None
    MouseState* = object
        position*: tuple[x, y: cfloat]
        delta*: tuple[x, y: cfloat]
        wheel*: cfloat
        buttons*: PackedSet[uint8]
    InputState* = object
        keys*: Table[SDL_Scancode, KeyState]
        mouse*: MouseState

var inputState* = InputState() # Global input state (keyboard and mouse)

proc pollInputEvents*(): bool =
    result = true

    for key, state in inputState.keys.pairs():
        if state == Released: inputState.keys[key] = None

    # Reset per-frame mouse changes
    inputState.mouse.delta = (0, 0)
    inputState.mouse.wheel = 0

    var event: SDL_Event
    while SDL_PollEvent(addr event):
        case event.type
        of SDL_EVENT_QUIT:
            result = false # Exit the game loop
        of SDL_EVENT_KEYDOWN:
            let scancode = event.key.scancode
            if (not inputState.keys.hasKey(scancode)) or (inputState.keys[scancode] == None):
                inputState.keys[scancode] = Pressed
            elif inputState.keys[scancode] == Pressed:
                inputState.keys[scancode] = Held
        of SDL_EVENT_KEYUP:
            inputState.keys[event.key.scancode] = Released
        of SDL_EVENT_MOUSE_MOTION:
            inputState.mouse.position = (event.motion.x, event.motion.y)
            inputState.mouse.delta = (event.motion.xrel, event.motion.yrel)
        of SDL_EVENT_MOUSE_BUTTON_DOWN:
            inputState.mouse.buttons.incl(event.button.button)
        of SDL_EVENT_MOUSE_BUTTON_UP:
            inputState.mouse.buttons.excl(event.button.button)
        of SDL_EVENT_MOUSE_WHEEL:
            inputState.mouse.wheel = event.wheel.y
        else:
            discard
    return result

proc isKeyPressed*(key: SDL_Scancode): bool = inputState.keys.getOrDefault(key, None) == Pressed
proc isKeyHeld*(key: SDL_Scancode): bool = inputState.keys.getOrDefault(key, None) in {Pressed, Held}
proc isKeyReleased*(key: SDL_Scancode): bool = inputState.keys.getOrDefault(key, None) == Released
proc isMouseButtonPressed*(button: uint8): bool = button in inputState.mouse.buttons
proc getMouseDelta*(): tuple[x, y: cfloat] = inputState.mouse.delta
proc getMouseWheelDelta*(): cfloat = inputState.mouse.wheel
proc getMousePosition*(): tuple[x, y: cfloat] = inputState.mouse.position