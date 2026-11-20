extends SceneTree
## 单独运行：实时时长验收，约30秒，不计入每次快速回归。
func _initialize() -> void:
	await process_frame
	var intro := ContractIntro.new()
	root.add_child(intro)
	var started := Time.get_ticks_msec()
	await intro.finished
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	print("INTRO_REAL_SECONDS=%.3f" % seconds)
	var passed := seconds >= 29.0 and seconds <= 33.0
	var audio := root.get_node_or_null("Audio")
	if audio != null:
		audio.shutdown()
	await process_frame
	quit(0 if passed else 1)
