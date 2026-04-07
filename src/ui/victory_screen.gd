extends Control

@onready var textureSet = $Background/TextureSet
@onready var textureSet2 = $Background/TextureSet2
@onready var starSet = $Background/StarSet

func _ready() -> void:
	# Find the audio manager
	var audio_manager : DungeonCrawlerAudioManager = get_tree().root.get_node_or_null("Level/DungeonCrawlerAudioManager")
	if audio_manager and audio_manager.has_method("play_sound_effect"):
		print("playing sound effect")
		audio_manager.play_sound_effect("starSparkle", 1.0, 0.7)
			
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
	if audio_manager and audio_manager.has_method("play_sound_effect"):
		star_tween.tween_callback(func(): audio_manager.play_sound_effect("starSparkle", 1.0, 0.7))
	star_tween.tween_property(stars[0], "scale", Vector2.ONE, 0.5)
	star_tween.tween_interval(2.0)
	if audio_manager and audio_manager.has_method("play_sound_effect"):
		star_tween.tween_callback(func(): audio_manager.play_sound_effect("starSparkle", 1.2, 0.7))
	star_tween.tween_property(stars[1], "scale", Vector2.ONE, 0.5)
	star_tween.tween_interval(2.0)
	if audio_manager and audio_manager.has_method("play_sound_effect"):
		star_tween.tween_callback(func(): audio_manager.play_sound_effect("starSparkle", 1.4, 0.7))
	star_tween.tween_property(stars[2], "scale", Vector2.ONE, 0.5)

func _process(delta: float) -> void:
	# Rotate all TextureRects infinitely
	for child in textureSet.get_children():
		if child is TextureRect:
			child.rotation += delta * 1.0
			
	for child in textureSet2.get_children():
		if child is TextureRect:
			child.rotation += delta * -1.0
