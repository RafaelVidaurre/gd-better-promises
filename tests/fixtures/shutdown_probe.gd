extends SceneTree


func _initialize() -> void:
	var mode := OS.get_cmdline_user_args()[0] as String

	if mode == "pending":
		GdPromise.new(func(_resolve, _reject) -> void:
			pass
		)
	elif mode == "settled":
		GdPromise.new_resolved("done")
	elif mode == "control":
		pass
	else:
		push_error("Expected shutdown probe mode: control, pending, or settled.")
		quit(2)
		return

	_finish.call_deferred(mode)


func _finish(mode: String) -> void:
	await process_frame
	print("shutdown_probe=%s" % mode)
	quit()
