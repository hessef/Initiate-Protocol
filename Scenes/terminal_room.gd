extends Node3D

class_name TerminalRoom

@onready var crt: Node = $CRT
@onready var terminal_viewport: SubViewport = crt.get_node("SubViewport")
@onready var terminal_ui: Node = terminal_viewport.get_node("TerminalUi")
@onready var RunGuy: ProtRunner = ProtRunner.new()

func _ready() -> void:
	terminal_ui.line_submitted.connect(_on_terminal_line)
	add_child(RunGuy) #so it can use _process

func _unhandled_input(event: InputEvent) -> void:
	if terminal_viewport:
		terminal_viewport.push_input(event)

func _on_terminal_line(line: String) -> void:
	RunGuy.run_cmd(line, terminal_ui)
