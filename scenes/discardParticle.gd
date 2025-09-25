extends Node2D

@onready var particle_emitter = $CPUParticles2D

func _on_player_hand_card_discarded(discard_position: Vector2):
	# Set to center of the parent Discard node
	# The Discard area uses a 250x350 card size at 0.65 scale
	var card_center = Vector2(125, 175)  # Half of the base card size (250x350)
	self.position = card_center
	particle_emitter.emitting = true
