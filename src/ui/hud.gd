extends CanvasLayer

# This controls the point at which the stamina bar begins to fade out.
# Specifically, when stamina / max_stamina > FADE_START_RATIO, the bar will fade out linearly, reaching full transparency at max_stamina.
const FADE_START_RATIO := 0.9

# This controls the amplitude of the flashing effect when stamina is too low to sprint. 
# We are basically trying to have an oscillating alpha value in the range [1.0 - FLASH_ALPHA_AMPLITUDE, 1.0] to create a flashing effect.
const FLASH_ALPHA_AMPLITUDE := 0.8

# This controls the speed of the flashing effect when stamina is too low to sprint.
# The actual oscillation is a sine wave, so the alpha will oscillate smoothly between its min and max values. 
# The speed is in oscillations per second, so higher values will make the bar flash faster. 
const FLASH_SPEED := 6.0

# This controls the normal color of the stamina bar when sprinting is available.
# Note that this should be the same as the fill color in hud.tscn for consistency.
const NORMAL_COLOR := Color(0.749958, 0.5650139, 0.2277576, 1.0)

# This controls the color of the stamina bar when stamina is too low to sprint. 
# It's a bright red to contrast with the normal golden color.
const LOW_COLOR := Color(1.0, 0.25, 0.25, 1.0)

@onready var stamina_bar: ProgressBar = $Control/StaminaBar

# Internal state for stamina bar visuals. 

# _current and _max track the current and maximum stamina values for visual purposes.
var _current := 0.0
var _max := 1.0

# _time is used to create a time-based flashing effect when stamina is low. It accumulates the elapsed time in seconds.
var _time := 0.0

# _fill_style will hold a reference to the duplicated StyleBoxFlat used for the fill of the stamina bar, 
# allowing us to modify its color without affecting other UI elements that might share the same style.
var _fill_style: StyleBoxFlat

# _can_sprint tracks whether the player is currently able to sprint, which affects the visual state of the stamina bar (e.g. flashing and color change).
# This should be set based on explicit values from the player node's function call parameters.
var _can_sprint := true

## Called when the node is added to the scene. Initializes the stamina bar visuals by duplicating the style and applying the initial visual state.
func _ready() -> void:
	# Duplicate the fill style so we don't mutate a shared resource.
	_fill_style = stamina_bar.get_theme_stylebox("fill")
	if _fill_style and _fill_style is StyleBoxFlat:
		_fill_style = _fill_style.duplicate()
		stamina_bar.add_theme_stylebox_override("fill", _fill_style)

	_apply_visuals()


## Called every frame. 
## Updates the internal time state and reapplies visuals to handle any dynamic changes 
## such as flashing when stamina is low or fading as stamina approaches max.
## [br]
## **param** delta The time in seconds since the last frame, used to update the flashing effect timing.
func _process(delta: float) -> void:
	_time += delta
	_apply_visuals()
	
	if Input.is_action_just_pressed("esc") && $Control/Panel.is_visible_in_tree():
		$Control/Panel.hide()


## Updates the stamina bar with the current stamina values and sprinting state.
## This should be called by the player node whenever stamina changes to ensure the HUD reflects the current state.
## [br]
## **param** current The player's current stamina value, which will be clamped to the range [0, max_val] for display purposes.
## [br]
## **param** max_val The player's maximum stamina value, which should be a positive number. This is used to determine the fill ratio of the stamina bar and should be greater than 0 to avoid division by zero.
## [br]
## **param** can_sprint A boolean indicating whether the player is currently able to sprint. This affects the visual state of the stamina bar, such as flashing and color changes when false.
func set_stamina(current: float, max_val: float, can_sprint: bool = true) -> void:
	if stamina_bar == null:
		return

	_max = max_val

	# We clamp current stamina to the range [0, max] to ensure the bar doesn't display invalid values.
	_current = clamp(current, 0.0, _max)
	_can_sprint = can_sprint
	stamina_bar.max_value = _max
	stamina_bar.value = _current

	# We immediately apply visuals after updating the stamina values 
	# to ensure the bar's appearance reflects the new state without waiting for the next frame.
	_apply_visuals()


## Applies the visual effects to the stamina bar based on the current stamina ratio and sprinting state.
## This includes fading the bar as stamina approaches max and flashing/recoloring when stamina is too low to sprint. 
## This should be called every frame to ensure the visuals are updated in response to changes in stamina and sprinting state.
func _apply_visuals() -> void:
	# No stamina bar = nothing to apply visuals to.
	if stamina_bar == null:
		return

	# We need to use the ratio rather than any absolute stamina values to determine how to apply the fading effect as stamina approaches max.
	var ratio := _current / _max

	# Base alpha: fully opaque until fade start, then fade to 0 at full.
	var alpha := 1.0

	# Handle fading when stamina is full/nearly full. 
	if ratio >= FADE_START_RATIO:
		var t := (ratio - FADE_START_RATIO) / (1.0 - FADE_START_RATIO)
		alpha = 1.0 - clamp(t, 0.0, 1.0)

	# Handle flashing and color change when stamina is too low to sprint.
	var fill_color := NORMAL_COLOR

	# Compute the color and how much alpha to apply for the flashing effect when stamina is too low to sprint.
	if not _can_sprint:
		fill_color = LOW_COLOR
		var flash_term := FLASH_ALPHA_AMPLITUDE * (0.5 * (1.0 + sin(_time * FLASH_SPEED)))
		alpha *= (1.0 - flash_term)

	# Apply the color and alpha to the stamina bar. 
	# We clamp alpha to ensure it stays within valid bounds, 
	# and we set the fill color based on whether the player can sprint or not.
	stamina_bar.modulate.a = clamp(alpha, 0.0, 1.0)
	if _fill_style:
		_fill_style.bg_color = Color(fill_color.r, fill_color.g, fill_color.b, 1.0)
