extends GutTest


class SignalEmitter extends RefCounted:
	signal no_arguments
	signal succeeded(value: Variant)
	signal failed(reason: Variant)
	signal multiple(first: Variant, second: Variant)


func test_default_constructor_resolves_with_null() -> void:
	var promise := GdPromise.new()

	assert_true(promise.is_resolved)
	assert_null(promise.value)


func test_constructor_calls_executor_synchronously() -> void:
	var data := {"called": false}

	var promise := GdPromise.new(func(_resolve, _reject) -> void:
		data.called = true
	)

	assert_true(data.called)
	assert_false(promise.is_settled)
	promise.resolve()


func test_pending_state_and_public_properties() -> void:
	var promise := _new_pending()

	assert_eq(promise.status, GdPromise.Status.PENDING)
	assert_false(promise.is_settled)
	assert_false(promise.is_resolved)
	assert_false(promise.is_rejected)
	assert_null(promise.value)
	assert_null(promise.result)
	promise.resolve()


func test_resolve_sets_state_and_emits_signals_in_order() -> void:
	var promise := _new_pending()
	var events: Array = []

	promise.settled.connect(func(state: GdPromise.Status, value: Variant) -> void:
		events.append(["settled", state, value])
	)
	promise.resolved.connect(func(value: Variant) -> void:
		events.append(["resolved", value])
	)

	promise.resolve("value")

	assert_true(promise.is_settled)
	assert_true(promise.is_resolved)
	assert_false(promise.is_rejected)
	assert_eq(promise.status, GdPromise.Status.RESOLVED)
	assert_eq(promise.value, "value")
	assert_eq(promise.result, "value")
	assert_eq(events, [
		["settled", GdPromise.Status.RESOLVED, "value"],
		["resolved", "value"],
	])


func test_reject_sets_state_and_emits_signals_in_order() -> void:
	var promise := _new_pending()
	var events: Array = []

	promise.settled.connect(func(state: GdPromise.Status, reason: Variant) -> void:
		events.append(["settled", state, reason])
	)
	promise.rejected.connect(func(reason: Variant) -> void:
		events.append(["rejected", reason])
	)

	promise.reject("reason")

	assert_true(promise.is_settled)
	assert_false(promise.is_resolved)
	assert_true(promise.is_rejected)
	assert_eq(promise.status, GdPromise.Status.REJECTED)
	assert_eq(promise.value, "reason")
	assert_eq(promise.result, "reason")
	assert_eq(events, [
		["settled", GdPromise.Status.REJECTED, "reason"],
		["rejected", "reason"],
	])


func test_only_first_settlement_applies() -> void:
	var resolved := _new_pending()
	resolved.resolve("first")
	resolved.reject("second")
	resolved.resolve("third")

	var rejected := _new_pending()
	rejected.reject("first")
	rejected.resolve("second")
	rejected.reject("third")

	assert_true(resolved.is_resolved)
	assert_eq(resolved.value, "first")
	assert_true(rejected.is_rejected)
	assert_eq(rejected.value, "first")


func test_resolve_and_reject_default_to_null() -> void:
	var resolved := _new_pending()
	var rejected := _new_pending()

	resolved.resolve()
	rejected.reject()

	assert_true(resolved.is_resolved)
	assert_null(resolved.value)
	assert_true(rejected.is_rejected)
	assert_null(rejected.value)


func test_ids_are_unique_and_to_string_uses_public_name_and_state() -> void:
	var first := GdPromise.new_resolved()
	var second := GdPromise.new_rejected()

	assert_ne(first.id, second.id)
	assert_eq(str(first), "GdPromise(%s:RESOLVED)" % first.id)
	assert_eq(str(second), "GdPromise(%s:REJECTED)" % second.id)


func test_asynchronous_executor_settles_later() -> void:
	var promise := GdPromise.new(func(resolve, _reject) -> void:
		await get_tree().process_frame
		resolve.call("later")
	)

	assert_false(promise.is_settled)
	await get_tree().process_frame

	assert_true(promise.is_resolved)
	assert_eq(promise.value, "later")


func test_unowned_asynchronous_promise_stays_alive_until_settlement() -> void:
	var state := {"settled": false}

	_start_unowned_async_promise(state)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(state.settled)


func test_await_methods_return_observed_values() -> void:
	var resolved := GdPromise.new(func(resolve, _reject) -> void:
		await get_tree().process_frame
		resolve.call("resolved")
	)
	var rejected := GdPromise.new(func(_resolve, reject) -> void:
		await get_tree().process_frame
		reject.call("rejected")
	)
	var settled := GdPromise.new(func(resolve, _reject) -> void:
		await get_tree().process_frame
		resolve.call("settled")
	)

	assert_eq(await resolved.await_resolved(), "resolved")
	assert_eq(await resolved.await_then(), "resolved")
	assert_eq(await rejected.await_rejected(), "rejected")
	assert_eq(await rejected.await_catch(), "rejected")
	await settled.await_settled()
	await settled.await_finally()
	assert_true(settled.is_resolved)


func test_then_transforms_pending_resolution() -> void:
	var root := _new_pending()
	var child := root.then(func(value: int) -> int:
		return value + 1
	)

	root.resolve(2)

	assert_true(child.is_resolved)
	assert_eq(child.value, 3)


func test_then_on_resolved_promise_runs_in_same_call() -> void:
	var data := {"called": false}
	var promise := GdPromise.new_resolved("value")

	var child := promise.then(func(value: String) -> String:
		data.called = true
		return value + "!"
	)

	assert_true(data.called)
	assert_true(child.is_resolved)
	assert_eq(child.value, "value!")


func test_then_on_rejected_promise_skips_callback_and_propagates_reason() -> void:
	var called := false
	var promise := GdPromise.new_rejected("reason")

	var child := promise.then(func(_value: Variant) -> void:
		called = true
	)

	assert_false(called)
	assert_true(child.is_rejected)
	assert_eq(child.value, "reason")


func test_then_adopts_resolved_and_rejected_promises() -> void:
	var resolved_child := GdPromise.new_resolved(1).then(func(value: int) -> GdPromise:
		return GdPromise.new_resolved(value + 1)
	)
	var rejected_child := GdPromise.new_resolved(1).then(func(_value: int) -> GdPromise:
		return GdPromise.new_rejected("nested")
	)

	assert_true(resolved_child.is_resolved)
	assert_eq(resolved_child.value, 2)
	assert_true(rejected_child.is_rejected)
	assert_eq(rejected_child.value, "nested")


func test_then_adopts_pending_promise() -> void:
	var nested := _new_pending()
	var child := GdPromise.new_resolved().then(func(_value: Variant) -> GdPromise:
		return nested
	)

	assert_false(child.is_settled)
	nested.resolve("nested")

	assert_true(child.is_resolved)
	assert_eq(child.value, "nested")


func test_then_awaits_coroutine_callback() -> void:
	var child := GdPromise.new_resolved("start").then(func(value: String) -> String:
		await get_tree().process_frame
		return value + " end"
	)

	assert_false(child.is_settled)
	await get_tree().process_frame

	assert_true(child.is_resolved)
	assert_eq(child.value, "start end")


func test_catch_on_resolved_promise_skips_callback_and_propagates_value() -> void:
	var called := false
	var child := GdPromise.new_resolved("value").catch(func(_reason: Variant) -> void:
		called = true
	)

	assert_false(called)
	assert_true(child.is_resolved)
	assert_eq(child.value, "value")


func test_catch_non_promise_return_becomes_rejection_reason() -> void:
	var child := GdPromise.new_rejected("original").catch(func(reason: String) -> String:
		return "handled %s" % reason
	)

	assert_true(child.is_rejected)
	assert_eq(child.value, "handled original")


func test_catch_adopts_returned_promises() -> void:
	var resolved_child := GdPromise.new_rejected("original").catch(
		func(_reason: String) -> GdPromise:
			return GdPromise.new_resolved("recovered")
	)
	var rejected_child := GdPromise.new_rejected("original").catch(
		func(_reason: String) -> GdPromise:
			return GdPromise.new_rejected("replacement")
	)

	assert_true(resolved_child.is_resolved)
	assert_eq(resolved_child.value, "recovered")
	assert_true(rejected_child.is_rejected)
	assert_eq(rejected_child.value, "replacement")


func test_catch_on_pending_rejection_runs_callback() -> void:
	var root := _new_pending()
	var data := {"observed_reason": null}
	var child := root.catch(func(reason: Variant) -> Variant:
		data.observed_reason = reason
		return reason
	)

	root.reject("reason")

	assert_eq(data.observed_reason, "reason")
	assert_true(child.is_rejected)
	assert_eq(child.value, "reason")


func test_finally_runs_immediately_and_returns_original_promise() -> void:
	var promise := _new_pending()
	var data := {"called": false}

	var returned := await promise.finally(func() -> void:
		data.called = true
	)

	assert_true(data.called)
	assert_same(returned, promise)
	assert_false(promise.is_settled)
	promise.resolve()


func test_all_empty_resolves_with_empty_array() -> void:
	var promise := GdPromise.all([])

	assert_true(promise.is_resolved)
	assert_eq(promise.value, [])


func test_all_preserves_order_for_mixed_pending_and_resolved_promises() -> void:
	var first := _new_pending()
	var third := _new_pending()
	var combined := GdPromise.all([
		first,
		GdPromise.new_resolved("second"),
		third,
	])

	third.resolve("third")
	assert_false(combined.is_settled)
	first.resolve("first")

	assert_true(combined.is_resolved)
	assert_eq(combined.value, ["first", "second", "third"])


func test_all_rejects_with_first_observed_rejection() -> void:
	var first := _new_pending()
	var second := _new_pending()
	var combined := GdPromise.all([first, second])

	second.reject("second")
	first.reject("first")

	assert_true(combined.is_rejected)
	assert_eq(combined.value, "second")


func test_all_detects_already_rejected_input() -> void:
	var pending := _new_pending()
	var combined := GdPromise.all([
		GdPromise.new_resolved(1),
		GdPromise.new_rejected("reason"),
		pending,
	])

	assert_true(combined.is_rejected)
	assert_eq(combined.value, "reason")
	pending.resolve()


func test_race_empty_remains_pending() -> void:
	var race_promise := GdPromise.race([])

	await get_tree().process_frame
	assert_false(race_promise.is_settled)
	race_promise.resolve()


func test_race_uses_first_already_settled_input_in_array_order() -> void:
	var resolved_race := GdPromise.race([
		GdPromise.new_resolved("first"),
		GdPromise.new_resolved("second"),
	])
	var rejected_race := GdPromise.race([
		GdPromise.new_rejected("first"),
		GdPromise.new_resolved("second"),
	])

	assert_true(resolved_race.is_resolved)
	assert_eq(resolved_race.value, "first")
	assert_true(rejected_race.is_rejected)
	assert_eq(rejected_race.value, "first")


func test_race_uses_first_later_settlement() -> void:
	var first := _new_pending()
	var second := _new_pending()
	var race_promise := GdPromise.race([first, second])

	second.reject("second")
	first.resolve("first")

	assert_true(race_promise.is_rejected)
	assert_eq(race_promise.value, "second")


func test_to_promise_returns_same_promise_and_wraps_plain_values() -> void:
	var original := GdPromise.new_resolved("value")

	assert_same(GdPromise.to_promise(original), original)
	assert_eq(GdPromise.to_promise(42).value, 42)
	assert_null(GdPromise.to_promise(null).value)


func test_to_promise_awaits_sync_and_async_callables() -> void:
	var sync_promise := GdPromise.to_promise(func() -> int:
		return 2
	)
	var async_promise := GdPromise.to_promise(func() -> int:
		await get_tree().process_frame
		return 3
	)

	assert_eq(await sync_promise.await_resolved(), 2)
	assert_eq(await async_promise.await_resolved(), 3)


func test_to_promise_awaits_single_and_multiple_argument_signals() -> void:
	var emitter := SignalEmitter.new()
	var single := GdPromise.to_promise(emitter.succeeded)
	var multiple := GdPromise.to_promise(emitter.multiple)

	emitter.succeeded.emit("value")
	emitter.multiple.emit("first", "second")

	assert_eq(await single.await_resolved(), "value")
	assert_eq(await multiple.await_resolved(), ["first", "second"])


func test_from_signals_resolves_or_rejects() -> void:
	var success_emitter := SignalEmitter.new()
	var failure_emitter := SignalEmitter.new()
	var success := GdPromise.from_signals(success_emitter.succeeded, success_emitter.failed)
	var failure := GdPromise.from_signals(failure_emitter.succeeded, failure_emitter.failed)

	success_emitter.succeeded.emit("value")
	failure_emitter.failed.emit("reason")

	assert_true(success.is_resolved)
	assert_eq(success.value, "value")
	assert_true(failure.is_rejected)
	assert_eq(failure.value, "reason")


func test_from_signals_keeps_first_settlement() -> void:
	var emitter := SignalEmitter.new()
	var promise := GdPromise.from_signals(emitter.succeeded, emitter.failed)

	emitter.succeeded.emit("value")
	emitter.failed.emit("reason")

	assert_true(promise.is_resolved)
	assert_eq(promise.value, "value")


func test_from_signals_argumentless_signal_errors_and_stays_pending() -> void:
	var emitter := SignalEmitter.new()
	var promise := GdPromise.from_signals(emitter.no_arguments)

	emitter.no_arguments.emit()

	assert_engine_error_count(1)
	assert_false(promise.is_settled)
	promise.resolve()


func test_sleep_resolves_and_timeout_rejects() -> void:
	var sleeping := GdPromise.sleep(0.01)
	var timing_out := GdPromise.timeout(0.01)
	var custom_timeout := GdPromise.timeout(0.01, "custom")

	await sleeping.await_settled()
	await timing_out.await_settled()
	await custom_timeout.await_settled()

	assert_true(sleeping.is_resolved)
	assert_true(timing_out.is_rejected)
	assert_eq(timing_out.value, GdPromise.ERR_TIMEOUT)
	assert_true(custom_timeout.is_rejected)
	assert_eq(custom_timeout.value, "custom")


func test_depth_cap_defers_only_after_eight_nested_emissions() -> void:
	await get_tree().process_frame
	var seven_root := _new_pending()
	var eight_root := _new_pending()
	var seven := _build_increment_chain(seven_root, 7)
	var eight := _build_increment_chain(eight_root, 8)
	var data := {
		"seven_emitted": false,
		"eight_emitted": false,
	}
	seven.resolved.connect(func(_value: Variant) -> void:
		data.seven_emitted = true
	)
	eight.resolved.connect(func(_value: Variant) -> void:
		data.eight_emitted = true
	)

	seven_root.resolve(0)
	eight_root.resolve(0)

	assert_true(data.seven_emitted)
	assert_false(data.eight_emitted)
	await get_tree().process_frame
	assert_true(data.eight_emitted)
	assert_eq(eight.value, 8)


func test_very_deep_chain_completes_without_stack_overflow() -> void:
	var root := _new_pending()
	var chain := _build_increment_chain(root, 500)

	root.resolve(0)
	var result = await chain.await_resolved()

	assert_eq(result, 500)


func test_many_already_settled_promises_complete_aggregates() -> void:
	var promises: Array = []
	for i in range(40):
		promises.append(GdPromise.new_resolved(i))

	var all_result: Array = await GdPromise.all(promises).await_resolved()
	var race_result: Variant = await GdPromise.race(promises).await_resolved()

	assert_eq(all_result.size(), 40)
	assert_eq(all_result[0], 0)
	assert_eq(all_result[39], 39)
	assert_eq(race_result, 0)


func _new_pending() -> GdPromise:
	return GdPromise.new(func(_resolve, _reject) -> void:
		pass
	)


func _build_increment_chain(root: GdPromise, length: int) -> GdPromise:
	var chain := root
	for _i in range(length):
		chain = chain.then(func(value: int) -> int:
			return value + 1
		)
	return chain


func _start_unowned_async_promise(state: Dictionary) -> void:
	GdPromise.new(func(resolve, _reject) -> void:
		await get_tree().process_frame
		state.settled = true
		resolve.call()
	)
