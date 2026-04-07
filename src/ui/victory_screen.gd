extends Control

@onready var textureSet = $Background/TextureSet
@onready var textureSet2 = $Background/TextureSet2
@onready var starSet = $Background/StarSet

func _ready() -> void:
	# Start fully transparent
	modulate.a = 0.0
	
	# Fade in over 2 seconds
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 3.0)
	
	var stars = starSet.get_children()
	
	for star in stars:
		star.scale = Vector2.ZERO

	# Scale each star in sequence with 1 second gaps
	var star_tween = create_tween()
	star_tween.tween_property(stars[0], "scale", Vector2.ONE, 0.5)
	star_tween.tween_interval(2.0)
	star_tween.tween_property(stars[1], "scale", Vector2.ONE, 0.5)
	star_tween.tween_interval(2.0)
	star_tween.tween_property(stars[2], "scale", Vector2.ONE, 0.5)

func _process(delta: float) -> void:
	# Rotate all TextureRects infinitely
	for child in textureSet.get_children():
		if child is TextureRect:
			child.rotation += delta * 1.0
			
	for child in textureSet2.get_children():
		if child is TextureRect:
			child.rotation += delta * -1.0
