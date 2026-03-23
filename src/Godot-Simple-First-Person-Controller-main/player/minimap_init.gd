extends SubViewportContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	
	# world_2d = get_tree().root.world_2d
	var world = get_tree().root.world_3d
	if world:
		$SubViewport.world_3d = world


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
