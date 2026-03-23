extends Node

class_name Inventory

@export var slots: Array[ItemStack] = []
signal inventory_changed

## Adds an item to inventory, preferring to fill existing stacks before consuming empty slots to keep capacity predictable.
## [br]
## **param** item The item data to add.
## [br]
## **param** count How many units to try to add.
## [br]
## **returns** Remaining units that did not fit (0 means all stored).
func add_item_to_inventory(item: Item, count: int = 1) -> int:
	if item == null or count <= 0:
		return count # Guard against bad inputs; no state change if nothing meaningful to add.

	var remaining := count # Track leftover so we can signal caller about overflow.

	# First, top off partial stacks to avoid creating fragmented inventory.
	for stack in slots:
		if stack and not stack.is_empty() and stack.can_merge(item):
			remaining = stack.add(remaining)
			if remaining <= 0:
				_emit_changed()
				return 0

	# Next, reuse empty slots instead of growing the list.
	for i in range(slots.size()):
		var stack = slots[i]
		# Check for null or empty to treat both uninitialized and cleared slots as available, so we don't have to manage nulls separately.
		if stack == null or stack.is_empty():
			var new_stack: ItemStack = stack if stack else ItemStack.new()
			new_stack.item = item # Explicitly assign to avoid stale references in reused slots.
			new_stack.quantity = 0 # Reset quantity before adding so leftover math is deterministic.
			remaining = new_stack.add(remaining)
			slots[i] = new_stack
			if remaining <= 0:
				_emit_changed()
				return 0

	# If everything is full, expand so items never silently vanish; caller can later trim or cap in gameplay rules.
	if remaining > 0:
		var extra := ItemStack.new(item, 0)
		remaining = extra.add(remaining)
		slots.append(extra)

	_emit_changed()
	return remaining

## Removes up to count of the item id, walking stacks in order so behavior is deterministic.
## [br]
## **param** item_id The identifier of the item to remove.
## [br]
## **param** count Desired number to remove.
## [br]
## **returns** Actual number removed.
func remove_item_from_inventory(item_id: String, count: int = 1) -> int:
	if count <= 0:
		# Nothing to remove.
		return 0

	var to_remove := count # Decremental counter so we can early-exit once satisfied.
	for stack in slots:
		if stack and not stack.is_empty() and stack.item.id == item_id:
			var removed := stack.remove(to_remove)
			to_remove -= removed
			if to_remove <= 0:
				# We've removed all the items we were asked to, so we're done.
				_emit_changed()
				return count

	# All stacks processed; return how many we actually removed (could be less than requested if not enough in inventory).
	_emit_changed()
	return count - to_remove

## Computes aggregate carry weight
## Currently used for stamina and movement penalties so those systems stay decoupled from slot math.
func get_total_weight() -> float:
	var total := 0.0
	for stack in slots:
		if stack:
			total += stack.get_total_weight()
	return total

## Clears slots but keeps the array shape.
func clear() -> void:
	for i in range(slots.size()):
		# Preserve slot count but reset content to avoid null surprises
		# in case this slot is being used by some UI or system or whatever.
		slots[i] = ItemStack.new() 
	_emit_changed()

## Emits the shared inventory change signal to notify any listeners that they should refresh their state.
func _emit_changed() -> void:
	emit_signal("inventory_changed")
