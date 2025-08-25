extends PanelContainer

func initalizeCard(new_color: Color):
	$CardColorDisplay.color = new_color
	
	$HexLabel.text = "#" + new_color.to_html(false)
	
	$SaturationBar.value = new_color.s * 100
	$SaturationValueLabel.text = str(int(new_color.s * 100)) + "%"
	
