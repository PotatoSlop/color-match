extends Node2D

@export var card_scene: PackedScene

@onready var button = $CanvasLayer/Button
@onready var player_hand = $CanvasLayer/PlayerHand
@onready var hand_counter_label = $CanvasLayer/HandCounterLabel 

var is_draw_button_enabled: bool = true

func _ready():
	button.pressed.connect(_on_draw_card_button_pressed)
	update_hand_counter()

func _on_draw_card_button_pressed():
	if !player_hand.can_accept_card():
		flash_deck_full_warning()
		return

	if !card_scene:
		return

	var new_card = card_scene.instantiate()

	if player_hand.add_card_to_hand(new_card):
		var color_card = new_card.get_node("SubViewport/ColorCard")
		update_hand_counter()
		update_draw_button_state()

# Update card counter display
func update_hand_counter():
	if hand_counter_label:
		var current = player_hand.hand_cards.size()
		var max_size = player_hand.max_hand_size
		hand_counter_label.text = "%d/%d" % [current, max_size]

		if current >= max_size:
			hand_counter_label.modulate = Color.RED
		else:
			hand_counter_label.modulate = Color.WHITE

func update_draw_button_state():
	var can_draw = player_hand.can_accept_card()
	button.disabled = not can_draw

	if can_draw:
		button.modulate = Color.WHITE
	else:
		button.modulate = Color.GRAY

# Flash red when trying to draw with full hand
func flash_deck_full_warning():
	var flash_tween = create_tween()
	flash_tween.tween_property(button, "modulate", Color.RED, 0.1)
	flash_tween.tween_property(button, "modulate", Color.GRAY, 0.1)
	flash_tween.tween_property(button, "modulate", Color.RED, 0.1)
	flash_tween.tween_property(button, "modulate", Color.GRAY, 0.2)

func remove_card_from_hand(card):
	player_hand.remove_card_from_hand(card)
	update_hand_counter()
	update_draw_button_state()
