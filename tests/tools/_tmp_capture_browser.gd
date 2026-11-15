extends SceneTree

var _frames := 0


func _initialize() -> void:
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 30:
		return false

	var image := root.get_viewport().get_texture().get_image()
	image.save_png("res://_browser_capture.png")
	return true
