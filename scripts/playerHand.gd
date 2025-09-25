extends Control

@export var max_hand_size: int = 5
@export var card_spacing: float = 200.0
@export var card_scene: PackedScene
@export var deck_button_path: NodePath

@onready var end_turn_button = $"../EndTurnBtn"
@onready var chroma_count_text = $"../ChromaCounter"

signal card_fused(fusion_position: Vector2)
signal card_discarded(discard_position: Vector2)

# --- State Variables ---
var chroma_count: int = 3;
var hand_cards: Array[Node] = []
var slot_positions: Array[Vector2] = []
var is_animating: bool = false
var dragged_card: Node = null
var hover_target_card: Node = null

# --- Animation Settings ---
const SLIDE_DURATION: float = 0.35
const SLIDE_EASE: Tween.EaseType = Tween.EASE_OUT
const SLIDE_TRANS: Tween.TransitionType = Tween.TRANS_BACK

func _ready() -> void:
	_recalculate_slot_positions()
	end_turn_button.pressed.connect(reset_chroma_counter)
	var normal_style = end_turn_button.get_theme_stylebox("normal")
	end_turn_button.add_theme_stylebox_override("hover", normal_style)
	end_turn_button.add_theme_stylebox_override("pressed", normal_style)
	end_turn_button.add_theme_stylebox_override("focus", normal_style)
	end_turn_button.add_theme_stylebox_override("disabled", normal_style)

# region: Public Card Management

func can_accept_card() -> bool:
	return hand_cards.size() < max_hand_size

func add_card_to_hand(card: Node, is_from_deck: bool = true) -> bool:
	if not can_accept_card():
		card.queue_free() # Ensure we don't leave orphaned nodes
		return false

	var color_card = card.get_node("SubViewport/ColorCard")
	if color_card and color_card.current_color == Color(0,0,0):
		color_card.generate_random_color()

	add_child(card)

	# Set its starting global position for the animation
	if is_from_deck:
		var deck_button = get_node_or_null(deck_button_path)
		if deck_button:
			card.global_position = deck_button.global_position + (deck_button.size / 2.0)
	
	_connect_card_signals(card)
	
	hand_cards.append(card)
	_reorganize_hand_animated()
	
	return true

func remove_card_from_hand(card: Node):
	if not card in hand_cards:
		return

	_remove_card_silently(card)
	
	var main = get_tree().current_scene
	if main and main.has_method("is_cursor_over_discard"):
		if main.is_cursor_over_discard() and chroma_count > 0:
			chroma_count -= 1
			update_chroma_counter_text()
			emit_signal("card_discarded", card.global_position)
	
	_reorganize_hand_animated()
func _remove_card_silently(card: Node):
	if not card in hand_cards:
		return
	hand_cards.erase(card)
	_disconnect_card_signals(card)
# endregion

# region: Card Interaction and Fusion

func _on_card_drag_started(card: Node):
	if is_animating: return
	dragged_card = card

func _on_card_hover_entered(card: Node):
	if is_animating: return
	if dragged_card and card != dragged_card:
		hover_target_card = card

func _on_card_hover_exited(card: Node):
	if is_animating: return
	if card == hover_target_card:
		hover_target_card = null

func _on_card_drag_ended(_card: Node):
	if is_animating: return

	# Fusion Logic
	if dragged_card and hover_target_card and chroma_count > 0:
		_perform_card_fusion(dragged_card, hover_target_card)

	# Reset dragged card states
	dragged_card = null
	hover_target_card = null

func _perform_card_fusion(card1: Node, card2: Node):
	if not card1 or not card2 or not card1 in hand_cards or not card2 in hand_cards:
		return

	is_animating = true
	set_all_cards_interaction(false)

	var color1 = card1.get_node("SubViewport/ColorCard").current_color
	var color2 = card2.get_node("SubViewport/ColorCard").current_color
	var fusion_position = card2.position
	emit_signal("card_fused", card2.global_position)
	if chroma_count >= 1:
		chroma_count -= 1
	update_chroma_counter_text()

	_remove_card_silently(card1)
	card1.queue_free()

	# Animate the target card (card2) disappearing
	var disappear_tween = create_tween()
	disappear_tween.tween_property(card2, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await disappear_tween.finished

	# Clean up the target card after its animation
	_remove_card_silently(card2)
	card2.queue_free()

	# Create the new fused card
	var new_card = card_scene.instantiate()
	var new_color = _mix_colors_additive(color1, color2)
	new_card.get_node("SubViewport/ColorCard").set_color(new_color)
	new_card.position = fusion_position
	new_card.scale = Vector2.ZERO
	new_card.modulate = Color(1, 1, 1, 0) # Make it transparent to start

	add_card_to_hand(new_card, false)

	# Update the main UI
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("update_hand_counter"):
		main_scene.update_hand_counter()
		main_scene.update_draw_button_state()
# endregion

# region: Animation and Positioning
func _reorganize_hand_animated():
	is_animating = true
	set_all_cards_interaction(false)

	var master_tween = create_tween()
	master_tween.set_parallel(true)

	for i in range(hand_cards.size()):
		var card = hand_cards[i]
		var target_pos = slot_positions[i]

		master_tween.tween_property(card, "position", target_pos, SLIDE_DURATION)\
			.set_trans(SLIDE_TRANS)\
			.set_ease(SLIDE_EASE)\
			.set_delay(i * 0.04)

		if card.modulate.a < 0.01:
			master_tween.tween_property(card, "scale", card.base_scale, SLIDE_DURATION)\
				.set_trans(SLIDE_TRANS)\
				.set_ease(SLIDE_EASE)
			master_tween.tween_property(card, "modulate:a", 1.0, SLIDE_DURATION * 0.8)\
				.set_ease(SLIDE_EASE)


	await master_tween.finished

	for card in hand_cards:
		if is_instance_valid(card):
			card.original_hand_position = card.position
			if card.has_method("reset_visuals"):
				card.reset_visuals()

	is_animating = false
	set_all_cards_interaction(true)

func _recalculate_slot_positions():
	slot_positions.clear()
	var area2d = get_node_or_null("Area2D")
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
# endregion

# region: Color Logic

# Mixes two colors using additive (RGB) model.
func _mix_colors_additive(color1: Color, color2: Color) -> Color:
	var new_r = (color1.r + color2.r) / 2.0
	var new_g = (color1.g + color2.g) / 2.0
	var new_b = (color1.b + color2.b) / 2.0
	return Color(new_r, new_g, new_b)
# endregion

# region: Helpers
func _connect_card_signals(card: Node):
	card.card_drag_started.connect(_on_card_drag_started)
	card.card_drag_ended.connect(_on_card_drag_ended)
	card.card_hover_entered.connect(_on_card_hover_entered)
	card.card_hover_exited.connect(_on_card_hover_exited)
	if card.has_method("set_parent_hand"):
		card.set_parent_hand(self, hand_cards.find(card))

func _disconnect_card_signals(card: Node):
	if card.is_connected("card_drag_started", _on_card_drag_started):
		card.card_drag_started.disconnect(_on_card_drag_started)
	if card.is_connected("card_drag_ended", _on_card_drag_ended):
		card.card_drag_ended.disconnect(_on_card_drag_ended)
	if card.is_connected("card_hover_entered", _on_card_hover_entered):
		card.card_hover_entered.disconnect(_on_card_hover_entered)
	if card.is_connected("card_hover_exited", _on_card_hover_exited):
		card.card_hover_exited.disconnect(_on_card_hover_exited)

	if card.has_method("clear_parent_hand"):
		card.clear_parent_hand()

func set_all_cards_interaction(enabled: bool):
	for card in hand_cards:
		if is_instance_valid(card):
			card.is_hoverable = enabled

func update_chroma_counter_text():
	chroma_count_text.text = "●".repeat(chroma_count) + " " + str(chroma_count)

func reset_chroma_counter():
	chroma_count = 3
	update_chroma_counter_text()
# endregion
