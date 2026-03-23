extends Resource

class_name ItemStack

@export var item: Item
@export var quantity: int = 0

## Initializes the stack with an optional item and quantity so callers can construct filled slots in one call.
## [br]
## **param** p_item Item to assign to the stack (can be null for empty slots).
## [br]
## **param** p_quantity Starting quantity; ignored if p_item is null.
func _init(p_item: Item = null, p_quantity: int = 0) -> void:
	item = p_item
	quantity = p_quantity

## Checks whether this slot should be treated as empty for inventory logic.
## [br]
## **returns** True when no item or zero quantity is present.
func is_empty() -> bool:
	return item == null or quantity <= 0 # Slot treated as empty when no item or zero count.

## Computes the weight contribution of this stack to aggregate carry weight.
## [br]
## **returns** Total weight (item weight * quantity) or 0 if empty.
func get_total_weight() -> float:
	if item == null:
		return 0.0
	return item.weight * quantity

## Indicates whether another item can be merged into this stack based on item identity.
## [br]
## **param** other The item to test for merge compatibility.
## [br]
## **returns** True if ids match and this stack is currently holding an item.
func can_merge(other: Item) -> bool:
	if item == null or other == null:
		return false
	return item.id == other.id # Only stacks with same logical item id to avoid mixed stacks.

## Attempts to add a quantity to this stack, respecting its max stack size.
## [br]
## **param** amount How many units to add.
## [br]
## **returns** Units that did not fit (0 when fully added).
func add(amount: int) -> int:
	if item == null:
		return amount # Cannot add to an empty stack without assigning an item first.

	var max_stack := item.stack_size
	var space_left := max_stack - quantity
	if space_left <= 0:
		# Already full; return all leftover remains to caller so they can decide what to do (e.g. try another stack, drop on ground, etc).
		return amount

	var to_add: int = min(space_left, amount)
	quantity += to_add
	return amount - to_add

## Removes up to the requested amount from this stack, clearing the item reference if empty.
## [br]
## **param** amount Units to remove.
## [br]
## **returns** Units actually removed.
func remove(amount: int) -> int:
	if amount <= 0 or is_empty():
		return 0

	var removed : int = min(amount, quantity)
	quantity -= removed
	if quantity <= 0:
		item = null # Clear item reference so the slot is reusable without stale data.
		quantity = 0
	return removed
