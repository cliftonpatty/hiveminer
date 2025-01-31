# main.gd
extends Node

var game_scene_path = "res://scenes/game_world.tscn"
var current_scene = null

func _ready():
	# For development, immediately switch to game
	switch_to_game()

func switch_to_game():
	if current_scene:
		current_scene.queue_free()  # Clear current scene if it exists
	
	var game_scene = load(game_scene_path).instantiate()
	add_child(game_scene)
	current_scene = game_scene
