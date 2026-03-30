# jacketed_fossil.gd
extends "res://src/Items/fossil_item.gd"

func _ready() -> void:
	super._ready()
	interactableText = "Press \"e\" to pickup jacketed fossil"

func interact() -> void:
	print("fossil is in it's jacket...")
	pickup()
