extends Sprite2D

@export var sub_viewport: SubViewport
@export var card_scene: PackedScene

signal card_drag_started(card)
signal card_drag_ended(card)
signal card_hover_entered(card)
signal card_hover_exited(card)

# Tweens 
var hover_tween: Tween
var shadow_tween: Tween
var lift_tween: Tween

# Animation Properties
var shadow_offset_visible: Vector2 = Vector2(0, -70) 
var shadow_offset_hidden: Vector2 = Vector2.ZERO 
var click_cooldown_time: float = 0.2
var last_click_time: float = 0.0

# State Variables
var is_dragging: bool = false 
var is_animating: bool = false
var is_hoverable: bool = true

var drag_offset: Vector2
var lift_offset_vector: Vector2 = Vector2.ZERO
var base_scale: Vector2 = Vector2(0.65, 0.65)
var hover_scale: Vector2 = Vector2(0.75, 0.75)

# Hand Integration
var parent_hand = null  # Reference to PlayerHand if this card is in a hand
var hand_slot_index: int = -1  # Which slot this card occupies in the hand
var original_hand_position: Vector2  # Position to return to if drag is cancelled

func _ready():
	material = material.duplicate()
	z_as_relative = false
	var area = $Area2D

	area.input_event.connect(_on_input_event)
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)

@warning_ignore("unused_parameter") 
func _process(delta: float):
	RenderingServer.global_shader_parameter_set("mouse_screen_pos", get_global_mouse_position())

	if is_dragging:
		var lift_offset = Vector2.ZERO if is_animating else lift_offset_vector
		global_position = get_global_mouse_position() - drag_offset
		_set_card_rotation(delta)

	else:
		self.rotation_degrees = lerp(self.rotation_degrees, 0.0, 22*delta)

@warning_ignore("unused_parameter")
func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	# Only allow clicking if the card is hoverable and no other card is being dragged
	if event.is_action_pressed("click") and is_hoverable and GlobalState.node_being_dragged == null:
		var current_time = Time.get_ticks_msec() / 1000.0
		
		if current_time - last_click_time >= click_cooldown_time:
			last_click_time = current_time
			start_drag()

# Letting go of drag
func _unhandled_input(event: InputEvent):
	if event.is_action_released("click") and is_dragging:
		stop_drag()

func start_drag():
	is_animating = false
	is_dragging = true 
	is_hoverable = false
	GlobalState.node_being_dragged = self
	original_hand_position = position

	drag_offset = get_global_mouse_position() - global_position
	z_index = 20 
	animate_shadow(true)
	animate_hover_effect(true)
	emit_signal("card_drag_started", self)

	# Kill any previous animation
	if lift_tween and lift_tween.is_running():
		lift_tween.kill()

	# Create and start the new lift animation
	lift_tween = create_tween()

	var lift_target = -shadow_offset_visible
	lift_tween.tween_property(self, "lift_offset_vector", lift_target, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func stop_drag():
	is_animating = true
	is_dragging = false
	is_hoverable = true
	animate_hover_effect(false)
	GlobalState.node_being_dragged = null
	z_index = 7
	
	# Emit drag ended signal BEFORE handling drop logic
	emit_signal("card_drag_ended", self)
	
	# Check if card is over discard area
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("handle_potential_discard"):
		if main_scene.handle_potential_discard(self):
			return
	
	# Return to hand or stay where dropped
	handle_drop_logic()

func handle_drop_logic():
	var target_position = original_hand_position  # Default: return to hand
	if is_card_in_hand_area():
		target_position = original_hand_position
	else:
		target_position = original_hand_position
	
	animate_return_to_position(target_position)

# Check if the card is currently over the player hand area
func is_card_in_hand_area() -> bool:
	if not parent_hand:
		return false
	
	var hand_area = parent_hand.get_node("Area2D")
	if not hand_area:
		return false
	
	# Simple distance check - if card is reasonably close to hand, consider it "in hand"
	var distance_to_hand = global_position.distance_to(parent_hand.global_position)
	return distance_to_hand < 400  # Adjust this threshold as needed

# ======================== Helpers to set up hand indexes ============================
# Set the parent hand reference (called by PlayerHand when card is added)
func set_parent_hand(hand_node, slot_index: int):
	parent_hand = hand_node
	hand_slot_index = slot_index

# Clear the parent hand reference (called when card leaves hand)
func clear_parent_hand():
	parent_hand = null
	hand_slot_index = -1

# ======================= Animation Helper functions ==========================
# Animate the card returning to its position
func animate_return_to_position(target_pos: Vector2):
	# Stop any other animations
	animate_hover_effect(false)
	if lift_tween and lift_tween.is_running():
		lift_tween.kill()

	lift_tween = create_tween()
	lift_tween.set_parallel()

	var duration = 0.25
	var ease_type = Tween.EASE_OUT
	var trans_type = Tween.TRANS_BACK

	# Animate
	lift_tween.tween_property(self, "position", target_pos, duration)\
		.set_ease(ease_type).set_trans(trans_type)

	lift_tween.tween_property(self, "lift_offset_vector", Vector2.ZERO, duration)\
		.set_ease(ease_type).set_trans(trans_type)

	lift_tween.tween_property(material, "shader_parameter/shadow_offset", shadow_offset_hidden, duration)\
		.set_ease(ease_type).set_trans(trans_type)

	lift_tween.finished.connect(_on_drop_animation_finished)

func _on_drop_animation_finished():
	is_animating = false

func reset_visuals():
	is_animating = false
	scale = base_scale
	rotation_degrees = 0.0
	lift_offset_vector = Vector2.ZERO
	material.set_shader_parameter("shadow_offset", shadow_offset_hidden)
	material.set_shader_parameter("hovering", 0.0)


func animate_hover_effect(is_hovering: bool):
	if hover_tween and hover_tween.is_running():
		hover_tween.kill()
	
	var target_hover_value = 1.0 if is_hovering else 0.0
	var target_scale = hover_scale if is_hovering else base_scale
	
	hover_tween = create_tween()
	hover_tween.set_parallel()
	
	if material is ShaderMaterial:
		hover_tween.tween_property(
			material, "shader_parameter/hovering", target_hover_value, 0.3
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	hover_tween.tween_property(
		self, "scale", target_scale, 0.35
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func animate_shadow(shadow_is_visible: bool):
	if shadow_tween and shadow_tween.is_running():
		shadow_tween.kill()

	# Determines which shadow position to animate to
	var target_offset = shadow_offset_visible if shadow_is_visible else shadow_offset_hidden
	shadow_tween = create_tween()
	
	if material is ShaderMaterial:
		shadow_tween.tween_property(
			material, "shader_parameter/shadow_offset", target_offset, 0.2
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

var last_pos: Vector2
var max_rotation: float = 12.5

# Rotating drag effect
func _set_card_rotation(delta: float) -> void: 
	var rotate_amount: float = clamp((global_position - last_pos).x*0.85, - max_rotation, max_rotation)
	self.rotation_degrees = lerp(self.rotation_degrees, rotate_amount, 12.0*delta)
	last_pos = global_position

# ======================================= Hover Enter and Exit ==========================================
func _on_mouse_entered():
	# Only emit hover signals if the card is hoverable
	if is_hoverable:
		emit_signal("card_hover_entered", self)
		animate_hover_effect(true)

func _on_mouse_exited():
	# Always emit hover exit signal to clean up any state
	emit_signal("card_hover_exited", self)
	if is_hoverable:
		animate_hover_effect(false)

# =============================== Gameplay Helper Functions =========================================
