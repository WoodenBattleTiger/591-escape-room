extends Node

var triceratopsIndex = 0

var fossil_item_scene = preload("res://src/Items/fossil_item.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	getRandomFossil.call_deferred()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func getRandomFossil():
	#spawn fossilItem
	if triceratopsIndex >= GlobalInfo.shuffled_triceratops_scenes.size():
		#TODO DO SOMETHING HERE
		print("You got all fossils. Trigger something now")
		return
	var fossil = fossil_item_scene.instantiate()
	triceratopsIndex += 1
	fossil.position = self.position
	
	#put the fossil into the world
	get_parent().add_child(fossil)
	fossil.assign_fossil(GlobalInfo.shuffled_triceratops_scenes[triceratopsIndex])
