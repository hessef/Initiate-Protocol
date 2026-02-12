extends Node3D

@onready var crt: Node = $CRT
@onready var terminal_viewport: SubViewport = crt.get_node("SubViewport")
@onready var terminal_ui: Node = terminal_viewport.get_node("TerminalUi")

func _ready() -> void:
	terminal_ui.line_submitted.connect(_on_terminal_line)

func _unhandled_input(event: InputEvent) -> void:
	if terminal_viewport:
		terminal_viewport.push_input(event)

func _on_terminal_line(line: String) -> void:
	print("Terminal command: ", line)
