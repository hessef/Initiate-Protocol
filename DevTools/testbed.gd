extends Node
class_name testbed

var ProtRunnerInst = ProtRunner.new()
var Interp = ProtInterpreter.new()
var GeneralFunctions = General_Functions.new()

enum test_types{
	PROT_TEST,
	UNIT_TEST
}

func _ready() -> void:
	var DO_TEST = test_types.PROT_TEST
	
	match DO_TEST:
		test_types.PROT_TEST:
			add_child(ProtRunnerInst) #adds it to the scene so it can use _process
			ProtRunnerInst.run_file(ProtRunnerInst.prot_path)
		test_types.UNIT_TEST:
			print("=====CHECKING CALCULATED DELAY=====")
			var test_exp = ["VAR", "BOOL", "TEST","[NOT F OR [F NOR T] AND [[F XOR NOT T] XNOR [4 GRTR 3]]]"]
			print(Interp._get_instruction_delay(1, "VAR", test_exp))
			print("=====SHOULD BE=====")
			print((1+0.25+0.25+0.25+0.25+0.25+0.25+0.25+0.5)/10)
