extends RefCounted
class_name TestUtils

static var FAILURES := 0

static func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		push_error("ASSERT_TRUE failed: %s" % msg)
		FAILURES += 1

static func assert_false(cond: bool, msg: String = "") -> void:
	assert_true(not cond, msg)

static func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		push_error("ASSERT_EQ failed: %s != %s. %s" % [str(a), str(b), msg])
		FAILURES += 1

static func assert_approx(a: float, b: float, eps: float = 1e-4, msg: String = "") -> void:
	if abs(a - b) > eps:
		push_error("ASSERT_APPROX failed: %s != %s (eps=%s). %s" % [str(a), str(b), str(eps), msg])
		FAILURES += 1

static func load_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text()

static func run_interp(source: String, scripts_path: String = "res://tests/prots/") -> Dictionary:
	var out_lines: Array[String] = []
	var interp := ProtInterpreter.new()

	# kill delays so tests run fast
	interp.clock_speed = 1000000000
	interp.output = func(msg):
		out_lines.append(str(msg))

	# so INIT PROT can find scripts
	interp._scripts_path = scripts_path

	interp.init_prot(source, "TEST")

	var guard := 0
	while interp.tick(999.0, 10000):
		guard += 1
		if guard > 1000:
			push_error("Interpreter did not finish (possible infinite loop)")
			break

	return {"interp": interp, "out": out_lines}
