extends Node2D

@export var card_scene: PackedScene

@onready var button = $CanvasLayer/Deck
@onready var player_hand = $CanvasLayer/PlayerHand
@onready var hand_counter_label = $CanvasLayer/HandCounterLabel 
@onready var discard_area = $CanvasLayer/Discard

var is_draw_button_enabled: bool = true

var card_over_discard: Node = null

# Button animation variables
var button_hover_tween: Tween
var button_click_tween: Tween
var button_base_scale: Vector2 = Vector2(0.65, 0.65)
var button_hover_scale: Vector2 = Vector2(0.75, 0.75)
var button_click_scale: Vector2 = Vector2(0.6, 0.6)

func _ready():
	button.pressed.connect(_on_draw_card_button_pressed)
	button.mouse_entered.connect(Callable(self, "_on_button_mouse_entered"))
	button.mouse_exited.connect(Callable(self, "_on_button_mouse_exited"))
	button.focus_mode = Control.FOCUS_NONE
	
	var normal_style = button.get_theme_stylebox("normal")
	button.add_theme_stylebox_override("hover", normal_style)
	
	update_hand_counter()

func is_cursor_over_discard() -> bool:
	if not discard_area:
		return false

	var mouse_pos = discard_area.get_global_mouse_position()
	var discard_rect = discard_area.get_global_rect()

	var scaled_rect = Rect2(
		discard_rect.position,
		discard_rect.size * discard_area.scale
	)

	return scaled_rect.has_point(mouse_pos)

func handle_potential_discard(card: Node) -> bool:
	if is_cursor_over_discard() and player_hand.chroma_count > 0:
		hand_card_discard(card)
		return true
	return false

func hand_card_discard(card: Node):
	player_hand.remove_card_from_hand(card)
	card.queue_free()
	update_hand_counter()
	update_draw_button_state()

func _on_draw_card_button_pressed():
	animate_button_click_effect()
	var new_card = card_scene.instantiate()
	
	if player_hand.add_card_to_hand(new_card):
		var _color_card = new_card.get_node("SubViewport/ColorCard")
		update_hand_counter()
		update_draw_button_state()

# Button hover effect functions
func _on_button_mouse_entered():
	if not button.disabled:
		animate_button_hover_effect(true)

func _on_button_mouse_exited():
		animate_button_hover_effect(false)

func animate_button_hover_effect(is_hovering: bool):
	if button_hover_tween and button_hover_tween.is_running():
		button_hover_tween.kill()
	
	var target_scale = button_hover_scale if is_hovering else button_base_scale
	
	button_hover_tween = create_tween()
	button_hover_tween.tween_property(
		button, "scale", target_scale, 0.35
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func animate_button_click_effect():
	# Kill any existing click animation
	if button_click_tween and button_click_tween.is_running():
		button_click_tween.kill()
	
	button_click_tween = create_tween()
	button_click_tween.set_parallel()  # Allow both animations to run simultaneously
	
	button_click_tween.tween_property(button, "scale", button_click_scale, 0.25)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	button_click_tween.tween_property(button, "scale", button_hover_scale, 0.25)\
		.set_delay(0.08).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# Update card counter display
func update_hand_counter():
	if hand_counter_label:
		var current = player_hand.hand_cards.size()
		var max_size = player_hand.max_hand_size
		hand_counter_label.text = "%d/%d" % [current, max_size]
		
		if current >= max_size:
			hand_counter_label.modulate = Color.RED
			animate_button_hover_effect(false)
		else:
			hand_counter_label.modulate = Color.WHITE

func update_draw_button_state():
	var can_draw = player_hand.can_accept_card()
	button.disabled = not can_draw

func remove_card_from_hand(card):
	player_hand.remove_card_from_hand(card)
	update_hand_counter()
	update_draw_button_state()
