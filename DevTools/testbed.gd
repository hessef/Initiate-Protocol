extends Node
class_name testbed

#var Interp = ProtInterpreter.new()
var GeneralFunctions = General_Functions.new()

enum test_types{
	PROT_TEST,
	UNIT_TEST
}

var test_lines = [
	'IF HELLO', #should jump to line 3 for false, line 5 for end
	'PRNT "HI"',
	'ELSE', #should jump to line 5 for false and end
	'PRNT "BYE"',
	'END IF'
]

func _ready() -> void:
	var DO_TEST = test_types.PROT_TEST
	var table = GeneralFunctions.generate_jump_tables(test_lines)
	print(table)
	print(test_lines[4])
