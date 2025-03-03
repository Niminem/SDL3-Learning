import ../../vendor/sdl3/sdl3

type Clock* = object
    autoStart*: bool
    startTime: uint64
    oldTime: uint64
    elapsedTime: float
    running: bool
    frameCount: int
    timeAccumulator: float  # Used for averaging FPS
    frequency: float  # SDL Performance Frequency
    lastFPS: float # Last FPS value

proc start*(clock: var Clock) # fwd decl
proc initClock*(autoStart = true): Clock =
    result = Clock(
        autoStart: autoStart,
        startTime: 0,
        oldTime: 0,
        elapsedTime: 0.0,
        running: false,
        frameCount: 0,
        timeAccumulator: 0.0,
        frequency: float SDL_GetPerformanceFrequency()
    )
    if autoStart: result.start()

proc start*(clock: var Clock) =
    clock.startTime = SDL_GetPerformanceCounter()
    clock.oldTime = clock.startTime
    clock.elapsedTime = 0.0
    clock.running = true

proc getDelta*(clock: var Clock): float =
    result = 0.0

    if clock.autoStart and not clock.running:
        clock.start()
        return 0.0

    if clock.running:
        let newTime = SDL_GetPerformanceCounter()
        result = (newTime - clock.oldTime).float / clock.frequency
        clock.oldTime = newTime
        clock.elapsedTime += result
        # FPS Tracking
        clock.frameCount += 1
        clock.timeAccumulator += result

proc getElapsedTime*(clock: var Clock): float =
    discard clock.getDelta()
    result = clock.elapsedTime

proc stop*(clock: var Clock) =
    discard clock.getElapsedTime()
    clock.running = false
    clock.autoStart = false

proc getFPS*(clock: var Clock): float =
    if clock.timeAccumulator >= 1.0'f32:
        clock.lastFPS = clock.frameCount.float / clock.timeAccumulator
        clock.frameCount = 0
        clock.timeAccumulator = 0.0'f32
    return clock.lastFPS