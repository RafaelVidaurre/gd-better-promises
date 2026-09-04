# GdbPromise

Inherits: `RefCounted`

Promise for GDScript.

A promise settles once, with a resolved value or a rejection reason. Create one with an executor callable that receives `resolve` and `reject` callables:

```gdscript
var loaded := GdbPromise.new(func(resolve: Callable, reject: Callable):
    var result := await load_level()
    if result.ok:
        resolve.call(result.level)
    else:
        reject.call(result.error)
)
var level = await loaded.await_resolved()
```

Chain work with `then` and `catch`, combine promises with `all` and `race`, and wrap callables and signals with `to_promise`. Settled promises are safe to await again.

## Signals

### `resolved(value: Variant)`

Emitted when the promise resolves.

### `rejected(reason: Variant)`

Emitted when the promise rejects.

### `settled(state: int, value_or_reason: Variant)`

Emitted when the promise settles with either outcome.

## Enumerations

### `Status`

- `PENDING` = `0` — The promise has not settled.
- `RESOLVED` = `1` — The promise resolved with a value.
- `REJECTED` = `2` — The promise rejected with a reason.

## Constants

- `ERR_TIMEOUT` = `&"timeout"` — Default rejection reason of `timeout`.
- `MAX_SYNC_SETTLEMENT_DEPTH` = `8` — Maximum depth of nested settlements handled in one call stack. Deeper settlements are emitted with `call_deferred()` to protect the stack.

## Properties

### `is_settled: bool`

True when the promise is no longer pending.

### `is_resolved: bool`

True when the promise resolved.

### `is_rejected: bool`

True when the promise rejected.

### `status: int`

The current promise state.

### `result: Variant`

Alias of `value`.

### `value: Variant`

The resolved value or the rejection reason.

### `id: int`

Sequence number of the promise instance.

## Methods

### `func _init(callback: Callable = <anonymous lambda>) -> void`

Creates a promise and calls `callback` with the `resolve` and `reject` callables. The callback can `await`. Without a callback the promise resolves with `null`.

### `func then(on_fulfilled: Callable) -> GdbPromise`

Returns a new promise that resolves with the return value of `on_fulfilled`, called with the resolved value. When the callback returns a promise, the new promise follows it. A rejection skips the callback and rejects the new promise with the same reason.

### `func catch(callback: Callable) -> GdbPromise`

Returns a new promise. When this promise rejects, `callback` runs with the reason and the new promise rejects with the return value of the callback. When the callback returns a promise, the new promise follows it. When this promise resolves, the new promise resolves with the same value. **Note:** Unlike JavaScript, `catch` does not recover the chain into a resolved state.

### `func finally(callback: Callable) -> GdbPromise`

Calls `callback` at once, awaits it, and returns this promise. The method does not wait for settlement. The return value of the callback is ignored, with a warning when it is not `null`.

### `func await_resolved() -> Variant`

Waits until the promise resolves and returns the value. A rejected promise never returns from this method.

### `func await_settled() -> void`

Waits until the promise settles with either outcome.

### `func await_rejected() -> Variant`

Waits until the promise rejects and returns the reason. A resolved promise never returns from this method.

### `func await_then() -> Variant`

Alias of `await_resolved`.

### `func await_catch() -> Variant`

Alias of `await_rejected`.

### `func await_finally() -> void`

Alias of `await_settled`.

### `func resolve(value_: Variant = null) -> void`

Resolves the promise with `value_`. Does nothing after settlement.

### `func reject(reason: Variant = null) -> void`

Rejects the promise with `reason`. Does nothing after settlement.

### `static func new_resolved(value_: Variant = null) -> GdbPromise`

Creates a promise resolved with `value_`.

### `static func new_rejected(reason: Variant = null) -> GdbPromise`

Creates a promise rejected with `reason`.

### `static func all(promises: Array) -> GdbPromise`

Returns a promise that resolves with an array of the results of `promises`, in the same order, once all of them resolve. It rejects with the first rejection reason. An empty array resolves with an empty array.

### `static func race(promises: Array) -> GdbPromise`

Returns a promise that settles with the outcome of the first promise in `promises` that settles. An empty array never settles.

### `static func sleep(duration: float) -> GdbPromise`

Returns a promise that resolves after `duration` seconds.

### `static func timeout(duration: float, reason: Variant = &"timeout") -> GdbPromise`

Returns a promise that rejects with `reason` after `duration` seconds.

### `static func to_promise(thing: Variant) -> GdbPromise`

Returns a promise for `thing`. A callable is called and the promise resolves with its awaited return value. A signal resolves the promise with its next emission. A promise is returned as is. Any other value becomes a resolved promise.

### `static func from_signals(success_signal: Signal, failure_signal: Signal = Signal()) -> GdbPromise`

Returns a promise that resolves with the first emission of `success_signal` or rejects with the first emission of `failure_signal`. Both signals must emit exactly one argument.
