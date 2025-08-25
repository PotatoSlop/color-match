extends Node2D

var playerHandScene = preload("res://scenes/player_hand.tscn")
var cardScene = preload("res://scenes/card.tscn")

var player_hand

func _ready():
	player_hand = playerHandScene.instantiate()
	add_child(player_hand)
	
	spawn_cards()
	
func spawn_cards():
	for i in range(5):
		var card = cardScene.instantiate()
		
		var random_color = Color(
			randf(),
			randf(),
			randf(),
			1.0
		)
		
		player_hand.add_child(card)
		card.initalizeCard(random_color)
