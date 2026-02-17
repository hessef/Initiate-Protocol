extends RefCounted
class_name TestGeneralFunctions

var GeneralFunctions := General_Functions.new()

func run() -> void:
	_test_is_number()
	_test_is_valid_var_name()
	_test_xor_xnor()
	_test_tokenize_expression_quotes_and_brackets()
	_test_generate_jump_tables_basic()
	_test_generate_jump_tables_nested()

func _test_is_number() -> void:
	TestUtils.assert_true(GeneralFunctions.is_number("12"))
	TestUtils.assert_true(GeneralFunctions.is_number("-3"))
	TestUtils.assert_true(GeneralFunctions.is_number("4.2"))
	TestUtils.assert_true(GeneralFunctions.is_number("-0.25"))
	TestUtils.assert_false(GeneralFunctions.is_number(""))
	TestUtils.assert_false(GeneralFunctions.is_number("-"))
	TestUtils.assert_false(GeneralFunctions.is_number("3.2.1"))
	TestUtils.assert_false(GeneralFunctions.is_number("abc"))
	TestUtils.assert_false(GeneralFunctions.is_number("1e3")) # you don't support sci notation (fine)

func _test_is_valid_var_name() -> void:
	TestUtils.assert_true(GeneralFunctions.is_valid_var_name("ABC"))
	TestUtils.assert_true(GeneralFunctions.is_valid_var_name("A1_B2"))
	TestUtils.assert_true(GeneralFunctions.is_valid_var_name("4T"))
	TestUtils.assert_false(GeneralFunctions.is_valid_var_name("hello"))
	TestUtils.assert_false(GeneralFunctions.is_valid_var_name("A-B"))
	TestUtils.assert_false(GeneralFunctions.is_valid_var_name(""))
	TestUtils.assert_false(GeneralFunctions.is_valid_var_name("AND"))

func _test_xor_xnor() -> void:
	TestUtils.assert_true(GeneralFunctions.xor(true, false))
	TestUtils.assert_true(GeneralFunctions.xor(false, true))
	TestUtils.assert_false(GeneralFunctions.xor(true, true))
	TestUtils.assert_false(GeneralFunctions.xor(false, false))
	TestUtils.assert_true(GeneralFunctions.xnor(true, true))
	TestUtils.assert_true(GeneralFunctions.xnor(false, false))
	TestUtils.assert_false(GeneralFunctions.xnor(true, false))

func _test_tokenize_expression_quotes_and_brackets() -> void:
	var t := GeneralFunctions.tokenize_expression(1, '["a b" IN "ab"]')
	TestUtils.assert_eq(t[0], '["a b"')
	TestUtils.assert_eq(t[1], "IN")
	TestUtils.assert_eq(t[2], '"ab"]')

func _test_generate_jump_tables_basic() -> void:
	var lines := [
		"IF T",            #1
		"PRNT \"A\"",      #2
		"ELSE",            #3
		"PRNT \"B\"",      #4
		"END IF",          #5
		"PRNT \"C\"",      #6
	]
	var jt := GeneralFunctions.generate_jump_tables(lines)
	TestUtils.assert_eq(jt["jump_false"][1], 3)
	TestUtils.assert_eq(jt["jump_false"][3], 6)
	TestUtils.assert_eq(jt["jump_end"][2], 6)

func _test_generate_jump_tables_nested() -> void:
	var lines := [
		"IF T",            #1
		"IF F",            #2
		"PRNT \"X\"",      #3
		"ELSE",            #4
		"PRNT \"Y\"",      #5
		"END IF",          #6
		"PRNT \"Z\"",      #7
		"END IF",          #8
	]
	var jt := GeneralFunctions.generate_jump_tables(lines)
	TestUtils.assert_eq(jt["jump_false"][2], 4)
	TestUtils.assert_eq(jt["jump_end"][3], 7)
	TestUtils.assert_false(jt["jump_end"].has(7))
