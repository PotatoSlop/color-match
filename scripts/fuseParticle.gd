extends Node2D

@onready var particle_emitter = $CPUParticles2D

func _on_card_fused(world_pos: Vector2):
	self.global_position = world_pos
	particle_emitter.emitting = true
