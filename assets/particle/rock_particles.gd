extends GPUParticles3D

# Determines whether the node should automatically be freed after the particle effect has finished playing.
@export var queue_free_after_finish := false

# Simple delay to allow particles to finish playing before the node is freed.
@export var cleanup_delay := 1.5

# Internal token to track the current playback instance, used to ensure that only the most recent play call can trigger a queue_free.
var _playback_token := 0

func _ready() -> void:
	one_shot = true
	emitting = false

## This function can be called to play the particle effect with a specified number of particles. 
## It will restart the particle system and emit the particles. 
## If queue_free_after_finish is true, it will automatically queue_free the node after the particles have finished playing, using a timer based on cleanup_delay.
## [br]
##  **Param**: particle_count (int) - The number of particles to emit. Defaults to the value of the 'amount' property of the GPUParticles3D.
func play_particles(particle_count: int = amount) -> void:

	# Ensure the amount is at least 1
	amount = max(particle_count, 1)

	# Keep track of the current playback instance to ensure that only the most recent play call can trigger a queue_free.
	_playback_token += 1
	var playback_token := _playback_token

	# Restart the particle system to play the new effect. 
	# Setting emitting to false and then true again ensures that the particles will play from the start.
	emitting = false
	restart()
	emitting = true

	# Try to locate the audio manager by node name in the active scene tree.
	# TODO re invent the audio manager (do not do that for sfx!!!)
	var audio_manager = get_tree().root.get_node("Node3D/DungeonCrawlerAudioManager")
	if audio_manager and audio_manager.has_method("play_sound_effect"):
		# Randomly select one of the rock sounds to play for variety.
		# audio_manager.play_sound_effect("rockSound" + str(randi_range(1, 6)))
		# Also with a random pitch scale up or down between -0.3 and 0.3.
		var pitch_scale = 1.0 + randf_range(-0.3, 0.3)
		audio_manager.play_sound_effect("rockSound" + str(randi_range(1, 6)), pitch_scale, 0.25)

	# If configured to queue_free after finishing, set up a timer to call the cleanup function after the specified delay.
	if queue_free_after_finish:
		_queue_free_after_play(playback_token)


## This function returns the current cleanup delay, which is the time in seconds that the system waits after playing the particles before it queues the node for freeing. 
## This can be useful for external code to know how long the particle effect will last before the node is removed from the scene.
## [br]
##  **Returns**: float - The cleanup delay in seconds.
func get_cleanup_delay() -> float:
	return cleanup_delay


## This function is responsible for queuing the node for freeing after the particle effect has finished playing.
## It takes a playback_token as an argument to ensure that only the most recent play call can trigger the queue_free.
## The function waits for the specified cleanup_delay using a timer, and then checks if the playback
## token matches the current _playback_token and if the node is still inside the scene tree before calling queue_free.
## [br]
##  **Param**: playback_token (int) - The token associated with the current playback instance, used to ensure that only the most recent play call can trigger the queue_free.
func _queue_free_after_play(playback_token: int) -> void:
	await get_tree().create_timer(cleanup_delay).timeout
	if playback_token == _playback_token and is_inside_tree():
		queue_free()
