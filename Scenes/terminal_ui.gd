extends Control
class_name TerminalUI

signal line_submitted(line: String)

@onready var output_box: RichTextLabel = $"Background/VBoxContainer/CLI History"
@onready var input_line: LineEdit = $Background/VBoxContainer/HBoxContainer/LineEdit

func _ready():
	await get_tree().process_frame
	input_line.grab_focus()
	input_line.text_submitted.connect(_on_text_submitted)
	print("TerminalUI runtime children:", get_children())
	
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
