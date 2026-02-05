extends Node
class_name ProtRunner

#default path for testing
@export var prot_path: String = "res://scripts/floatstest.prot"

func _ready() -> void:
	run_file(prot_path)

func run_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("Protocol file not found: %s" % path)
		return

	var f := FileAccess.open(path, FileAccess.READ)
	var source := f.get_as_text()

	var interp := ProtInterpreter.new()
	interp.output = func(msg):
		#TODO: swap this to output to the in-game terminal
		print("[PROT] ", msg)

	interp.init_prot(source)
