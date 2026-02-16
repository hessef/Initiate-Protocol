extends Node3D

class_name TerminalRoom

@onready var crt: Node = $CRT
@onready var terminal_viewport: SubViewport = crt.get_node("SubViewport")
@onready var terminal_ui: TerminalUI = terminal_viewport.get_node("TerminalUi")
@onready var RunGuy: ProtRunner = ProtRunner.new(terminal_ui)
@onready var terminal_interp: ProtInterpreter = ProtInterpreter.new()

func _ready() -> void:
	terminal_ui.line_submitted.connect(_on_terminal_line)
	add_child(RunGuy) #so it can use _process
	
	#run terminal bootup sequence
	_terminal_startup()
	
	#set up persistent terminal
	terminal_interp.output = func(msg):
		terminal_ui._append_line(msg)
	terminal_interp.init_prot("") #initialize empty program

func _unhandled_input(event: InputEvent) -> void:
	if terminal_viewport:
		terminal_viewport.push_input(event)

func _on_terminal_line(line: String) -> void:
	#TODO: add basic parsing to send INIT PROT commands to the RunGuy
	terminal_interp.execute_line_from_terminal(line)

func _terminal_startup() -> void:
	terminal_ui.bootup(false)
