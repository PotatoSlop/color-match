extends Control

@export var max_hand_size: int = 5
@export var card_spacing: float = 200.0
@export var hand_width: float = 600.0

var hand_cards: Array = []
var slot_positions: Array[Vector2] = []

func _ready() -> void:
	slot_positions.clear()
	calculate_slot_positions()

# Calculate slot positions relative to this node
func calculate_slot_positions():
	var area2d = $Area2D
	var collision_shape = area2d.get_node("CollisionShape2D") if area2d else null
	var area_offset = Vector2.ZERO

	if collision_shape:
		area_offset = collision_shape.position 

	# Calculate total width needed for all cards
	var total_width = (max_hand_size - 1) * card_spacing
	var start_x = area_offset.x - (total_width / 2.0) # Center card x with Collision shape
	var y_pos = area_offset.y

	for i in range(max_hand_size):
		var x_pos = start_x + (i * card_spacing)
		slot_positions.append(Vector2(x_pos, y_pos))

func get_card_hsv(card) -> Vector3:
	var color_card = card.get_node("SubViewport/ColorCard")
	var color = color_card.current_color # RGBA

	return Vector3(color.h, color.s, color.v)

func compare_cards_by_color(card_a, card_b) -> bool:
	var hsv_a = get_card_hsv(card_a)
	var hsv_b = get_card_hsv(card_b)

	# Primary sort: Hue (0 to 1 represents 0deg to 360deg)
	if abs(hsv_a.x - hsv_b.x) > 0.01:
		return hsv_a.x < hsv_b.x

	# Secondary sort: Saturation (higher saturation first)
	if abs(hsv_a.y - hsv_b.y) > 0.01:
		return hsv_a.y > hsv_b.y

	# Tertiary sort: Value/Brightness (higher value first)
	return hsv_a.z > hsv_b.z

# Find index where a new card should be inserted in the hand
func get_insertion_index(new_card) -> int:
	var new_hsv = get_card_hsv(new_card)

	for i in range(hand_cards.size()):
		var existing_hsv = get_card_hsv(hand_cards[i])

		if compare_cards_by_color(new_card, hand_cards[i]):
			# New card should go before card at index i
			return i
			
	# New card that have higher hue, lower sat, or lower val should go at end
	return hand_cards.size()  # Insert at end if it belongs after all existing cards

func can_accept_card() -> bool:
	return hand_cards.size() < max_hand_size

# Run after insertion/removal
func update_all_card_slot_indices():
	for i in range(hand_cards.size()):
		hand_cards[i].hand_slot_index = i

func add_card_to_hand(card) -> bool:
	if !can_accept_card():
		return false

	# Safety check to ensure the card has color
	var color_card = card.get_node("SubViewport/ColorCard")
	if color_card and color_card.current_color == Color(0,0,0):
		color_card.generate_random_color()

	var insert_index = get_insertion_index(card)
	hand_cards.insert(insert_index, card) # How nice of GDScript to have insert method :D

	# Parent the card to the hand
	if card.get_parent():
		card.get_parent().remove_child(card)

	add_child(card)
	card.set_parent_hand(self, insert_index) # Set up card's hand reference
	update_all_card_slot_indices()
	animate_card_insertion(card, insert_index) 	# Animate card to its position
	return true

func remove_card_from_hand(card):
	var index = hand_cards.find(card)
	if index == -1: #Card is not in array
		return

	card.clear_parent_hand()
	hand_cards.remove_at(index)
	update_all_card_slot_indices()
	animate_cards_shift_left(index)

	if card.get_parent() == self:
		remove_child(card)

# Animation Helpers
func animate_card_insertion(new_card, insert_index: int):
	# Set card's initial position; For now, start from center and animate to slot
	new_card.position = Vector2.ZERO
	var card_tween = create_tween()
	card_tween.tween_property(new_card, "position", slot_positions[insert_index], 0.2)
	card_tween.set_trans(Tween.TRANS_BACK)
	card_tween.set_ease(Tween.EASE_OUT)
	
	# Update the card's hand position reference
	card_tween.finished.connect(func(): new_card.original_hand_position = new_card.position)
	
	# Animate all cards that need to shift right  (All cards right of removed card)
	for i in range(insert_index + 1, hand_cards.size()):
		var card = hand_cards[i]
		var shift_tween = create_tween()
		shift_tween.tween_property(card, "position", slot_positions[i], 0.2)
		shift_tween.set_trans(Tween.TRANS_BACK)
		shift_tween.set_ease(Tween.EASE_OUT)
		shift_tween.finished.connect(func(): card.original_hand_position = card.position)

# Animate cards shifting left to fill a gap
func animate_cards_shift_left(removed_index: int):
	# Animate all cards after the removed index to shift left
	for i in range(removed_index, hand_cards.size()):
		var card = hand_cards[i]
		var shift_tween = create_tween()
		shift_tween.tween_property(card, "position", slot_positions[i], 0.2)
		shift_tween.set_trans(Tween.TRANS_BACK)
		shift_tween.set_ease(Tween.EASE_OUT)

# Get the world position for a specific slot index
func get_slot_world_position(index: int) -> Vector2:
	if index >= 0 and index < slot_positions.size():
		return global_position + slot_positions[index]
	return global_position

# Check if a position is within the hand's valid area
func is_position_in_hand(world_pos: Vector2) -> bool:
	var hand_area = $Area2D
	if not hand_area:
		return false
	
	var distance = world_pos.distance_to(global_position)
	return distance < 400
