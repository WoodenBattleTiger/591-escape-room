extends ColorRect

var tween

func flash() -> void:
	if tween:
		tween.kill()
	color.a = 0.4
	tween = create_tween()
	tween.tween_property(self, "color:a", 0.0, 1.5)
