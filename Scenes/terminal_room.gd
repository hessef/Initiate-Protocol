extends Node3D

class_name TerminalRoom

@onready var crt: Node = $CRT
@onready var terminal_viewport: SubViewport = crt.get_node("SubViewport")
@onready var terminal_ui: TerminalUI = terminal_viewport.get_node("TerminalUi")
@onready var RunGuy: ProtRunner
@onready var terminal_interp: ProtInterpreter = ProtInterpreter.new()

var _scripts_path: String = "res://scripts/"

func _ready() -> void:
	terminal_ui.line_submitted.connect(_on_terminal_line)
	terminal_ui.input_submitted.connect(_on_input)
	
	#run terminal bootup sequence
	_terminal_startup()
	
	#set up persistent terminal
	terminal_interp.output = func(msg, host):
		terminal_ui._append_line("%s:/> %s" % [host, msg])
	terminal_interp.init_prot("", "TERM") #initialize empty program

func _unhandled_input(event: InputEvent) -> void:
	if terminal_viewport:
		terminal_viewport.push_input(event)

func _on_terminal_line(line: String) -> void:
	#TODO: add basic parsing to send INIT PROT commands to the RunGuy
	#parse to tokens to just get the individual words
	var tokens = line.split(" ")
	var path: String
	if tokens[0].to_upper() == "INIT" and tokens[1].to_upper() == "PROT":
		path = _scripts_path + tokens[2] + ".prot"
		RunGuy.run_file(path, terminal_ui)
	else:
		terminal_interp.execute_line_from_terminal(line)

func _on_input(line: String) -> void:
	for interp in RunGuy._running_interpreters:
		if interp._awaiting_input == true:
			interp.accept_input(line)

func _terminal_startup() -> void:
	await terminal_ui.bootup(true)
	RunGuy = ProtRunner.new(terminal_ui)
	add_child(RunGuy) #so it can use _process
