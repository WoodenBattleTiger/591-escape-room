extends Node3D

var isInteractable = false
var interactableText = "Press \"e\" to use 3D printer"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func interact():
	print("do something here")
	
	#printer can't be interacted with anymore
	isInteractable = false
	
	#
	%ItemSnapLocation.object.isInteractable = true
	%ItemSnapLocation.object.currFossilState = FossilItem.FossilState.PRINTED
