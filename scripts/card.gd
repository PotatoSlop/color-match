extends PanelContainer

# Format: [ { "name": "Red", "color": Color(...) }, ... ]
var _color_library: Array[Dictionary] = []

@onready var color_swatch = $MarginContainer/VBoxContainer/ColorSwatch
@onready var hex_label = $MarginContainer/VBoxContainer/HexLabelContainer/HexLabel
@onready var color_label = $MarginContainer/VBoxContainer/ColorLabel/ColorLabel

var current_color: Color

func _ready():
	_load_color_library()
	generate_random_color()

func _load_color_library():
	var file = FileAccess.open("res://colors.json", FileAccess.READ)
	if not file:
		push_error("Failed to load res://colors.json")
		return

	var json_data = JSON.parse_string(file.get_as_text())
	if not json_data is Array:
		push_error("JSON: Expected an Array of color objects")
		return

	for color_entry in json_data: # Push colors from jSON into arr
		_color_library.append({
			"name": color_entry["name"],
			"color": Color(color_entry["hex"])
		})

# Generate a random color and update the card
func generate_random_color():
	var r = randi_range(0, 255)
	var g = randi_range(0, 255)
	var b = randi_range(0, 255)
	current_color = Color8(r, g, b)
	update_card_display()

func set_color(color: Color):
	current_color = color
	update_card_display()

# Update all visual elements of the card
func update_card_display():
	if color_swatch:
		var style = color_swatch.get_theme_stylebox("panel").duplicate()
		style.bg_color = current_color
		color_swatch.add_theme_stylebox_override("panel", style)

	if hex_label:
		hex_label.text = "#" + current_color.to_html(false).to_upper()

	if color_label:
		color_label.text = get_closest_color_name(current_color)

func get_closest_color_name(color: Color) -> String:
	var closest_name = "Unknown"
	var min_distance_sq = 1_000_000.0 

	for entry in _color_library:
		var other_color: Color = entry.color
		var dr = color.r - other_color.r
		var dg = color.g - other_color.g
		var db = color.b - other_color.b
		var distance_sq = dr*dr + dg*dg + db*db

		if distance_sq < min_distance_sq:
			min_distance_sq = distance_sq
			closest_name = entry.name

	return format_color_name(closest_name)

func format_color_name(color_name: String) -> String:
	return color_name.capitalize()

func get_color() -> Color:
	return current_color

func get_color_name() -> String:
	return get_closest_color_name(current_color)
