

extends RefCounted
class_name TestProtInterpreter

func run() -> void:
	_test_4function_math()

func _run_file(rel_path: String) -> Dictionary:
	var src := TestUtils.load_text("res://scripts/%s" % rel_path)
	return TestUtils.run_interp(src, "res://scripts/")
	
func _run_src(src: String) -> ProtInterpreter:
	var r := TestUtils.run_interp(src, "res://scripts/")
	return r["interp"]

#region TEST MATH
func _test_4function_math() -> void:
	var r := _run_file("4functiontest.prot")
	var interp: ProtInterpreter = r["interp"]
	TestUtils.assert_eq(interp._stack[-1].local_vars["X"], 2)
	TestUtils.assert_eq(interp._stack[-1].local_vars["Y"], 3)
	TestUtils.assert_eq(interp._stack[-1].local_vars["Z"], 4)
	_test_add()
	_test_sub()
	_test_mul()
	_test_div()
	_test_cnt()

func _test_add() -> void:
	# 1-arg: ADD X  => X = X + 1
	var interp := _run_src("""
		VAR X INT 10
		ADD X
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["X"], 11, "ADD unary should increment by 1")

	# 2-arg: ADD X 5 => X = X + 5
	interp = _run_src("""
		VAR X INT 10
		ADD X 5
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["X"], 15, "ADD binary should add rhs")

	# 3+ args: ADD Z A 3 B => Z = A + 3 + B   (dest overwritten by reduction)
	interp = _run_src("""
		VAR A INT 2
		VAR B INT 4
		VAR Z INT 999
		ADD Z A 3 B
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["Z"], 9, "ADD n-ary should set dest = sum(args2..)")

func _test_sub() -> void:
	# 1-arg: SUB X => X = X - 1
	var interp := _run_src("""
		VAR X INT 10
		SUB X
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["X"], 9, "SUB unary should decrement by 1")

	# 2-arg: SUB X 3 => X = X - 3
	interp = _run_src("""
		VAR X INT 10
		SUB X 3
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["X"], 7, "SUB binary should subtract rhs")

	# 3+ args: SUB Z A 5 2 => Z = A - 5 - 2
	interp = _run_src("""
		VAR A INT 20
		VAR Z INT 0
		SUB Z A 5 2
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["Z"], 13, "SUB n-ary should set dest = a2 - a3 - ...")

func _test_mul() -> void:
	# 1-arg: MUL X => X = X * X
	var interp := _run_src("""
		VAR X INT 10
		MUL X
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["X"], 100, "MUL unary should square (X *= X)")

	# 2-arg: MUL X 3 => X = X * 3
	interp = _run_src("""
		VAR X INT 10
		MUL X 3
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["X"], 30, "MUL binary should multiply by rhs")

	# 3+ args: MUL Z A 3 4 => Z = A * 3 * 4
	interp = _run_src("""
		VAR A INT 2
		VAR Z INT 123
		MUL Z A 3 4
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["Z"], 24, "MUL n-ary should set dest = product(args2..)")

func _test_div() -> void:
	# 1-arg: DIV X => X = X / X = 1 (for nonzero X)
	var interp := _run_src("""
		VAR X INT 10
		DIV X
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["X"], 1, "DIV unary should become 1 (X /= X)")

	# 2-arg: DIV X 2 => X = X / 2
	interp = _run_src("""
		VAR X INT 10
		DIV X 2
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["X"], 5, "DIV binary should divide by rhs")

	# 3+ args: DIV Z A 5 2 => Z = A / 5 / 2
	interp = _run_src("""
		VAR A INT 20
		VAR Z INT 0
		DIV Z A 5 2
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["Z"], 2, "DIV n-ary should set dest = a2 / a3 / ...")

func _test_cnt() -> void:
	var interp := _run_src("""
		VAR X INT 10
		CNT X
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["X"], 11, "CNT should increment by 1")
	
	interp = _run_src("""
		VAR Y FLT 11.2
		CNT Y
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["Y"], 12.2, "CNT should increment by 1")
	
func _test_cntd() -> void:
	var interp := _run_src("""
		VAR X INT 10
		CNTD X
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["X"], 9, "CNTD should decrement by 1")
	
	interp = _run_src("""
		VAR Y FLT 11.2
		CNTD Y
	""")
	TestUtils.assert_eq(interp._stack[-1].local_vars["Y"], 10.2, "CNTD should decrement by 1")
#endregion

func _test_float_math_and_casting() -> void:
	var r := _run_file("floatstest.prot")
	var interp: ProtInterpreter = r["interp"]

	TestUtils.assert_eq(interp.var_types["INT_TEST"], ArgusEnum.data_types.INT)
	TestUtils.assert_eq(interp.vars["INT_TEST"], 10)
	TestUtils.assert_eq(interp.var_types["FLT_TEST"], ArgusEnum.data_types.FLT)
	TestUtils.assert_approx(float(interp.vars["FLT_TEST"]), 6.0)

	TestUtils.assert_approx(float(interp.vars["RESULT1"]), 1.0)
	TestUtils.assert_approx(float(interp.vars["RESULT2"]), 2.0)
	TestUtils.assert_approx(float(interp.vars["RESULT3"]), 0.37037, 1e-3)

func _test_variables_and_set_validation() -> void:
	var r := _run_file("variablestest.prot")
	var interp: ProtInterpreter = r["interp"]

	TestUtils.assert_eq(interp.vars["TEST"], 44) # SET TEST "hi" should have failed
	TestUtils.assert_eq(interp.vars["4T"], "Goodbye")
	TestUtils.assert_eq(interp.vars["TEST2"], "shimmy shimmy ye hee")

func _test_jump_script_output() -> void:
	var r := _run_file("jmptest.prot")
	var out: Array = r["out"]

	var expected := [
		"=====NOW STARTING SINGLE ARGUMENT JMP COMMAND TEST=====",
		"no function called",
		"function 1 was called",
		"function 2 was called",
		"misc tasks...",
		"more tasks...",
		"even more tasks...",
		"function 3 was called",
		"=====END PROTOCOL====="
	]

	# subsequence match (allows debug noise)
	var idx := 0
	for line in out:
		if idx < expected.size() and line == expected[idx]:
			idx += 1
	TestUtils.assert_eq(idx, expected.size(), "JMP output did not match expected sequence")

func _test_call_ret_output() -> void:
	var r := _run_file("callrettest.prot")
	var out: Array = r["out"]

	var expected := [
		"=====NOW STARTING CALL AND RET COMMANDS TEST=====",
		"no function called",
		"function 1 was called",
		"function 2 was called",
		"misc tasks...",
		"function 2 was called",
		"more tasks...",
		"function 3 was called",
		"=====END PROTOCOL====="
	]

	var idx := 0
	for line in out:
		if idx < expected.size() and line == expected[idx]:
			idx += 1
	TestUtils.assert_eq(idx, expected.size(), "CALL/RET output did not match expected sequence")

func _test_if_branching() -> void:
	var r := _run_file("iftest.prot")
	var out: Array = r["out"]

	var expected := [
		"=====STARTING IF STATEMENT TEST=====",
		"TEST was false! (LINE 38)",
		"DONE!"
	]

	var idx := 0
	for line in out:
		if idx < expected.size() and line == expected[idx]:
			idx += 1
	TestUtils.assert_eq(idx, expected.size(), "IF/ELIF/ELSE sequence not as expected")

func _test_init_prot_chain() -> void:
	var r := _run_file("prottest.prot")
	var out: Array = r["out"]

	# Key lines proving the chain executed
	var must_contain := [
		"The global variable is: 9",
		"The local variable is: 12",
		"=====TESTING CREATING BOOLEAN VARIABLES====="
	]

	for m in must_contain:
		var ok := false
		for line in out:
			if line == m:
				ok = true
				break
		TestUtils.assert_true(ok, "Missing expected output line: %s" % m)
