extends PanelContainer

# Holds a performance optimized array of color names
# Format: [ { "name": "Red", "lab": Vector3(l,a,b) }, ... ]
var _processed_color_library: Array = []

@onready var color_swatch = $MarginContainer/VBoxContainer/ColorSwatch
@onready var hex_label = $MarginContainer/VBoxContainer/HexLabelContainer/HexLabel
@onready var color_label = $MarginContainer/VBoxContainer/ColorLabel/ColorLabel

var current_color: Color

func _ready():
	_load_and_prepare_color_library()
	generate_random_color() 

# Loads the color data from colors.json and processes it into the CIELAB color space
func _load_and_prepare_color_library():
	var file = FileAccess.open("res://colors.json", FileAccess.READ)

	if not file: # Safety Check if the json file exists
		push_error("Failed to load res://colors.json")
		return

	var json_data = JSON.parse_string(file.get_as_text())

	if not json_data is Array: # Safety Check
		push_error("JSON: Expected an Array of color objects")
		return

	# Loop through each color in the array to obtain name and color code
	for color_entry in json_data:
		var color_name = color_entry["name"]
		var hex_code = color_entry["hex"]
		
		var color_obj = Color(hex_code)
		# Pushes the color and its name to the array of colors (For performance reasons)
		_processed_color_library.append({
			"name": color_name,
			"lab": _rgb_to_lab(color_obj)
		})

# Generate a random color and update the card
func generate_random_color():
	var r = randf()
	var g = randf()
	var b = randf()
	current_color = Color(r, g, b)
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

# Find the closest color name using CIELAB distance
func get_closest_color_name(color: Color) -> String:
	var target_lab = _rgb_to_lab(color)
	var closest_name = "Unknown"
	var min_distance_sq = INF # Use squared distance to avoid square root operation

	for entry in _processed_color_library:
		var distance_sq = target_lab.distance_squared_to(entry.lab)
		
		if distance_sq < min_distance_sq:
			min_distance_sq = distance_sq
			closest_name = entry.name
	return format_color_name(closest_name)

# Helper function to convert sRGB to a CIELAB Vector3
func _rgb_to_lab(rgb_color: Color) -> Vector3:
	var r = rgb_color.r
	var g = rgb_color.g
	var b = rgb_color.b

	# Linearize sRGB values
	r = pow((r + 0.055) / 1.055, 2.4) if r > 0.04045 else (r / 12.92)
	g = pow((g + 0.055) / 1.055, 2.4) if g > 0.04045 else (g / 12.92)
	b = pow((b + 0.055) / 1.055, 2.4) if b > 0.04045 else (b / 12.92)

	# Convert to XYZ color space
	var x = r * 0.4124 + g * 0.3576 + b * 0.1805
	var y = r * 0.2126 + g * 0.7152 + b * 0.0722
	var z = r * 0.0193 + g * 0.1192 + b * 0.9505
	
	# Step 3: Convert XYZ to CIELAB (using D65 reference white)
	x /= 0.95047
	y /= 1.00000
	z /= 1.08883
	x = pow(x, 1.0/3.0) if x > 0.008856 else (7.787 * x + 16.0/116.0)
	y = pow(y, 1.0/3.0) if y > 0.008856 else (7.787 * y + 16.0/116.0)
	z = pow(z, 1.0/3.0) if z > 0.008856 else (7.787 * z + 16.0/116.0)

	var l = (116.0 * y) - 16.0
	var a = 500.0 * (x - y)
	var b_lab = 200.0 * (y - z)

	return Vector3(l, a, b_lab)
# Format color name for display
func format_color_name(color_name: String) -> String:
	return color_name.capitalize()

# Function to generate color with specific parameters
func generate_color_with_params(hue_range: Vector2 = Vector2(0, 1),
								saturation_range: Vector2 = Vector2(0, 1),
								value_range: Vector2 = Vector2(0, 1)):
	var h = randf_range(hue_range.x, hue_range.y)
	var s = randf_range(saturation_range.x, saturation_range.y)
	var v = randf_range(value_range.x, value_range.y)
	current_color = Color.from_hsv(h, s, v)
	update_card_display()

func get_color() -> Color:
	return current_color

func get_color_name() -> String:
	return get_closest_color_name(current_color)
