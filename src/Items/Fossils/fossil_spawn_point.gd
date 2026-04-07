extends Node

var triceratopsIndex = 27
var tyrannosaurIndex = 15

var fossil_item_scene = preload("res://src/Items/fossil_item.tscn")

@onready var victory_screen_instance = preload("res://src/ui/victory_screen.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	getRandomFossil.call_deferred()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func getRandomFossil():	
	#end game because all tyrannosaur and triceratops fossils have been cycled through
	if triceratopsIndex >= GlobalInfo.shuffled_triceratops_scenes.size() && tyrannosaurIndex >= GlobalInfo.shuffled_tyrannosaur_scenes.size():
		#TODO DO SOMETHING HERE
		var victory_screen = victory_screen_instance.instantiate()
		get_tree().root.add_child(victory_screen)
		print("You got all fossils. Trigger something now")
		return
	
	#spawn fossilItem
	var fossil = fossil_item_scene.instantiate()
	
	#print(randf())
	var num = randf()
	#var triceratopsBoneSelected = num < 0.65
	var triceratopsBoneSelected = true
	print("HERE IS THE RESULT: " + str(triceratopsBoneSelected) + str(num))
	
	if !triceratopsBoneSelected && tyrannosaurIndex >= GlobalInfo.shuffled_tyrannosaur_scenes.size():
		print(str(tyrannosaurIndex) + " " + str(GlobalInfo.shuffled_tyrannosaur_scenes.size()))
		triceratopsBoneSelected = true
	
	# Spawn a triceratops bone if the triceratops bone is randomly selected and not all triceratops bones are done
	# Also spawn a triceratops bone even if the tyrannosaur bone was selected IF the tyrannosaur bones have all been deposited
	if (triceratopsBoneSelected && triceratopsIndex < GlobalInfo.shuffled_triceratops_scenes.size()):
		print("triceratops bone spawned!")
		triceratopsIndex += 1
		fossil.position = self.position
		#put the fossil into the world
		get_parent().add_child(fossil)
		fossil.assign_fossil(GlobalInfo.shuffled_triceratops_scenes[triceratopsIndex])
	else:
		print("tyrannosaur bone spawned!")
		tyrannosaurIndex += 1
		fossil.position = self.position
		#put the fossil into the world
		get_parent().add_child(fossil)
		fossil.assign_fossil(GlobalInfo.shuffled_tyrannosaur_scenes[tyrannosaurIndex])
