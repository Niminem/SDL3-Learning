import std/[tables, sequtils]

type
    Event* = ref object of RootObj
        e*: string # event type
        # data: T # let's just allow developers to inherit from this type and add their own field(s)
    EventHandler* = proc(event: Event) {.gcsafe.}
    EventDispatcher* = ref object of RootObj
        listeners*: Table[string, seq[EventHandler]]

proc newEventDispatcher*(): EventDispatcher = new result

proc `$`*(self: EventDispatcher): string =
    result = "EventDispatcher:\n"
    for e, handlers in self.listeners.pairs():
        result.add("  event: " & e & ", handlers: " & $handlers.len & "\n")

proc addEventListener*(self: EventDispatcher, eventType: string, handler: EventHandler) =
    if not self.listeners.hasKey(eventType):
        self.listeners[eventType] = @[]
    self.listeners[eventType].add(handler)

proc removeEventListener*(self: EventDispatcher, eventType: string, handler: EventHandler) =
    if self.listeners.hasKey(eventType):
        self.listeners[eventType] = self.listeners[eventType].filterIt(it != handler)

proc dispatchEvent*(self: EventDispatcher, event: Event) =
    if self.listeners.hasKey(event.e):
        for handler in self.listeners[event.e]:
            event.handler()

when isMainModule:
    type
        Car = ref object of EventDispatcher
        CarEvent = ref object of Event
            msg*: string

    proc newCar(): Car = new result

    proc drive(self: Car) =
        let event = CarEvent(e: "drive", msg: "Car is driving")
        self.dispatchEvent(event)
    
    proc driveEvent(event: Event) = echo CarEvent(event).msg
    let car = newCar()
    car.addEventListener("drive", driveEvent)
    car.drive()
    assert car.listeners.len == 1
    assert car.listeners["drive"].len == 1
    car.removeEventListener("drive", driveEvent)
    assert car.listeners.len == 1
    assert car.listeners["drive"].len == 0
    car.addEventListener("drive", driveEvent)
    car.addEventListener("drive", driveEvent)
    assert car.listeners.len == 1
    assert car.listeners["drive"].len == 2
    echo car