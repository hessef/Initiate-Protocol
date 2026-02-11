extends Node
class_name testbed

var ProtRunnerInst = ProtRunner.new()
var Interp = ProtInterpreter.new()

enum test_types{
	PROT_TEST,
	UNIT_TEST
}

func _ready() -> void:
	var DO_TEST = test_types.PROT_TEST
	
	match DO_TEST:
		test_types.PROT_TEST:
			ProtRunnerInst.run_file(ProtRunnerInst.prot_path)
		test_types.UNIT_TEST:
			var test_exp = ["hell", "IN", "hello"]
			Interp.Evaluator._eval_eql(test_exp)
			print(test_exp)
