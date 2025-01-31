# save_manager.gd (in autoload/)

extends Node

const SAVE_PATH = "user://save_game.json"

var game_data = {
	"resources": {
		"gold": 0
	},
	"buildings": {},
	"upgrades": {},
	"last_save_time": 0
}

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var json_string = JSON.stringify(game_data)
	file.store_string(json_string)

func load_game():
	if !FileAccess.file_exists(SAVE_PATH):
		return false
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	var json = JSON.parse_string(json_string)
	
	if json:
		game_data = json
		return true
	return false
