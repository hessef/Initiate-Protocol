extends Control
class_name TerminalUI

signal line_submitted(line: String)

@onready var output_box: RichTextLabel = $"Background/VBoxContainer/CLI History"
@onready var input_line: LineEdit = $Background/VBoxContainer/HBoxContainer/LineEdit
@onready var caret: Label = $Background/VBoxContainer/HBoxContainer/Label
@onready var scanlines: ColorRect = $ColorRect
@onready var ui: VBoxContainer = $Background/VBoxContainer

func _ready():
	await get_tree().process_frame
	
	#make screen blank
	scanlines.visible = false
	caret.visible = false
	ui.visible = false
	
func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return

	#echo the command to the output (like a real terminal)
	_append_line("> " + text)

	#clear input for next command
	input_line.clear()
	input_line.grab_focus()
	
	#send to interpreter
	emit_signal("line_submitted", text)
	
func _append_line(line: String) -> void:
	# Add text + newline
	output_box.append_text(line + "\n")

	# Auto-scroll to bottom
	output_box.scroll_to_line(output_box.get_line_count() - 1)

#region BOOTUP SEQUENCE
func bootup(fast: bool) -> void:
	var wait_time = 0.3
	if fast: #so I can skip the sequence in dev mode
		#allow user input
		scanlines.visible = true
		await get_tree().create_timer(wait_time).timeout
		ui.visible = true
		await get_tree().create_timer(wait_time).timeout
		caret.visible = true
		await get_tree().create_timer(wait_time).timeout
		input_line.grab_focus()
		input_line.text_submitted.connect(_on_text_submitted)
		return
	
	scanlines.visible = true
	await get_tree().create_timer(wait_time).timeout
	ui.visible = true
	await get_tree().create_timer(wait_time).timeout
	_append_line("===============ETHER INDUSTRIES CCX-76B SYSTEM===============")
	await _check_system("MAIN PROCESSOR", "true")
	await _check_system("CACHE", "true")
	await _check_system("NORTH BRIDGE", "true")
	await _check_system("RAM", "true")
	await _check_system("PCIE BUS", "true")
	await _check_system("SOUTH BRIDGE", "true")
	await _check_system("AUXILIARY SYSTEMS", "true")
	await _check_system("WIRELESS COMMUNICATIONS", "true")
	_append_line("Launching CALI v2.8.99.67")
	await _check_system("INITIALIZING NETWORK", "true")
	await get_tree().create_timer(wait_time).timeout
	_append_line("ARGUS v2.7.5 LOADED")
	await get_tree().create_timer(wait_time).timeout
	await _check_system("ATTEMPTING CONNECTION TO COMMAND SERVER", "false")
	await _check_system("LAUNCHING IN LOCAL NODE CONTROL MODE", "true")
	await _check_system("SCANNING FOR CONNECTED UNITS", "\n4 UNITS FOUND")
	await get_tree().create_timer(0.1).timeout
	_append_line('UNIT0: MA-14/A "AHATI"')
	await get_tree().create_timer(0.1).timeout
	_append_line('UNIT1: MA-14/A "AHATI"')
	await get_tree().create_timer(0.1).timeout
	_append_line('UNIT2: MA-14/B "AHATI"')
	await get_tree().create_timer(0.1).timeout
	_append_line('UNIT3: MQ-3/E "SARAMA"')
	await _check_system("INITIALIZING UNITS", "true")
	await get_tree().create_timer(wait_time).timeout
	_append_line("SYSTEM READY")
	
	#allow user input
	caret.visible = true
	input_line.grab_focus()
	input_line.text_submitted.connect(_on_text_submitted)
	
func _check_system(system: String, result: String) -> void:
	await get_tree().create_timer(0.3).timeout
	var last_check_time = 0.25
	if result == "false":
		last_check_time = 1.0
	output_box.append_text(system)
	await get_tree().create_timer(0.1).timeout
	output_box.append_text(".")
	await get_tree().create_timer(0.1).timeout
	output_box.append_text(".")
	await get_tree().create_timer(last_check_time/2).timeout
	output_box.append_text(".")
	await get_tree().create_timer(last_check_time).timeout
	if result == "true":
		output_box.append_text("OK\n")
	elif result == "false":
		output_box.append_text("ERROR\n")
	else:
		output_box.append_text("%s\n" % result)
#endregion
