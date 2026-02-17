extends RefCounted
class_name TestExpressionEvaluator

func run() -> void:
	_test_basic_ops()
	_test_nested_ops()
	_test_comparisons_and_equality()
	_test_vars_local_and_global()

func _make_eval() -> ExpressionEvaluator:
	var lvars := {}
	var ltypes := {}
	var gvars := {}
	var gtypes := {}
	return ExpressionEvaluator.new(lvars, ltypes, gvars, gtypes, func(_m): pass)

func _test_basic_ops() -> void:
	var ev := _make_eval()
	TestUtils.assert_true(ev.evaluate_bool(1, "[T AND TRUE]"))
	TestUtils.assert_false(ev.evaluate_bool(1, "[T AND F]"))
	TestUtils.assert_true(ev.evaluate_bool(1, "[NOT F]"))
	TestUtils.assert_false(ev.evaluate_bool(1, "[NOT T]"))
	TestUtils.assert_true(ev.evaluate_bool(1, "[T XOR F]"))
	TestUtils.assert_true(ev.evaluate_bool(1, "[T XNOR T]"))
	TestUtils.assert_false(ev.evaluate_bool(1, "[T XNOR F]"))

func _test_nested_ops() -> void:
	var ev := _make_eval()
	TestUtils.assert_false(ev.evaluate_bool(1, "[NOT t]"))
	TestUtils.assert_false(ev.evaluate_bool(1, "[NOT [NOT [NOT NOT f]]]"))
	TestUtils.assert_true(ev.evaluate_bool(1, "[NOT [t AND NOT f] NAND TRUE]"))
	TestUtils.assert_false(ev.evaluate_bool(1, "[F OR [F NOR T] AND [[F XOR NOT T] XNOR F]]"))

func _test_comparisons_and_equality() -> void:
	var ev := _make_eval()
	TestUtils.assert_true(ev.evaluate_bool(1, "[3 LESS 5.4]"))
	TestUtils.assert_true(ev.evaluate_bool(1, "[4.1111 GRTR 3.77]"))
	TestUtils.assert_true(ev.evaluate_bool(1, "[5.4 LESE 5.4]"))
	TestUtils.assert_true(ev.evaluate_bool(1, "[3.77 GRTE 3.77]"))
	TestUtils.assert_true(ev.evaluate_bool(1, "[\"hell\" IN \"hello\"]"))
	TestUtils.assert_false(ev.evaluate_bool(1, '["hell" NIN "hello"]'))
	TestUtils.assert_true(ev.evaluate_bool(1, "[2 EQL 2]"))
	TestUtils.assert_true(ev.evaluate_bool(1, "[2 NEQL 3]"))

func _test_vars_local_and_global() -> void:
	var lvars := {"A": 2}
	var ltypes := {"A": ArgusEnum.data_types.INT}
	var gvars := {"B": 4.66, "S": "bro"}
	var gtypes := {"B": ArgusEnum.data_types.FLT, "S": ArgusEnum.data_types.STR}
	var ev := ExpressionEvaluator.new(lvars, ltypes, gvars, gtypes, func(_m): pass)

	TestUtils.assert_true(ev.evaluate_bool(1, "[A EQL 2]"))
	TestUtils.assert_true(ev.evaluate_bool(1, "[B EQL 4.66]"))
	TestUtils.assert_true(ev.evaluate_bool(1, "[\"bro\" EQL S]"))
