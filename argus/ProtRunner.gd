extends Node
class_name ProtRunner

#default path for testing
@export var prot_path: String = "res://scripts/jmptest.prot"

#CLI interpreter
var cli_interp: ProtInterpreter = ProtInterpreter.new()

#CLI output
var cli_output: TerminalUI

#array of currently running interpreters
var _running_interpreters: Array[ProtInterpreter] = []

func _init(output: TerminalUI) -> void:
	cli_output = output

func _ready() -> void:
	set_process(true) #ensures code runs every frame
	
func run_file(path: String, output: TerminalUI) -> void:
	if not FileAccess.file_exists(path):
		push_error("Protocol file not found: %s" % path)
		return

	var f := FileAccess.open(path, FileAccess.READ)
	var source := f.get_as_text()

	var interp := ProtInterpreter.new()
	interp.output = func(msg):
		#TODO: swap this to output to the in-game terminal
		print("[PROT] ", msg)
		output._append_line(msg)

	interp.init_prot(source)
	_running_interpreters.append(interp)
	
func _process(delta: float) -> void:
	#iterates backwards so that removing an element does not change indices
	for i in range(_running_interpreters.size() -1, -1, -1):
		var interp := _running_interpreters[i]
		var still_running := interp.tick(delta, 32) #maximum of 32 instructions per frame as a safety
		if not still_running:
			_running_interpreters.remove_at(i)

func run_cmd(line: String, output: TerminalUI) -> void:
	cli_interp.output = func(msg):
		print("[PROT] ", msg)
		output._append_line(msg)
	
	cli_interp.init_prot(line)
	_running_interpreters.append(cli_interp)
