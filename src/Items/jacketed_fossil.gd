# jacketed_fossil.gd
extends "res://src/Items/fossil_item.gd"

func _ready() -> void:
	super._ready()
	var interactableText = "Press \"e\" to pickup jacketed fossil"

func interact() -> void:
	print("fossil is in it's jacket on the table. Do stuff here for the fossil on the table (if we have anything to do). Then it picks up")
	pickup()
