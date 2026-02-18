@tool
extends EditorScript

const _TestUtils = preload("res://DevTools/Tests/TestUtils.gd")
const _TestGeneralFunctions = preload("res://DevTools/Tests/test_general_functions.gd")
const _TestExpressionEvaluator = preload("res://DevTools/Tests/test_expression_evaluator.gd")
const _TestProtInterpreter = preload("res://DevTools/Tests/test_prot_interpreter.gd")

func _run():
	# Ensure there IS an active scene tree by creating/using the edited scene root
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		# Create a temporary scene root if none open
		root = Node.new()
		root.name = "TempTestRoot"
		get_editor_interface().get_editor_main_screen().add_child(root) # sometimes not allowed
		# If this fails, you need the plugin approach.

	# Add a runner node under the scene root
	var runner := Node.new()
	runner.name = "TestRunnerNode"
	root.add_child(runner)

	# Now call your test logic here, but avoid get_node("/root/...") anywhere.
	_run_tests()

	runner.queue_free()


func _run_tests() -> void:
	print("[TEST] Starting...")
	var total_fail = 0

	var tests: Array = [
		_TestGeneralFunctions.new(),
		_TestExpressionEvaluator.new(),
		_TestProtInterpreter.new(),
	]

	for t in tests:
		TestUtils.FAILURES = 0 #reset failures
		var script = t.get_script()
		var name = script.resource_path.get_file() if script else t.get_class()
		print("[TEST] Running ", name)
		t.run()
		if TestUtils.FAILURES == 0:
			print("[TEST] All %s tests passed" % name)
		else:
			print("[TEST] %s tests had %d fails" % [name, TestUtils.FAILURES])
	
	if total_fail == 0:
		print("[TEST] All tests passed")
	else:
		print("[TEST] %d TEST(S) FAILED" % total_fail)
