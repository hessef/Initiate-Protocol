extends Node

class_name ExpressionEvaluator

var vars: Dictionary = {}
var var_types: Dictionary = {}
var output: Callable = func(msg): print(msg)

const DataTypes = ArgusEnum.data_types
const InvalidNames = ArgusEnum.invalid_names
const Operands = ["NOT", "AND", "OR", "NAND", "NOR", "XOR", "XNOR"]

func _init(inh_vars: Dictionary, inh_var_types: Dictionary, inh_output: Callable) -> void:
	vars = inh_vars
	var_types = inh_var_types
	output = inh_output

func evaluate_bool(line_no: int, exp: String) -> bool:
	var depth := 0 #keeps track of the evaluator depth
	var max_depth := 0 #keeps track of the maximum depth
	var tokens = _tokenize(line_no, exp)
	
	max_depth = _get_max_depth(tokens)
	
func _eval_bool(line_no: int, exp: Array) -> bool:
	var depth := 0 #keeps track of the evaluator depth
	var cnt := 0
	var start := 0
	var output : Array = []
	
	#remove brackets from first and last tokens
	exp[0] = exp[0].trim_prefix('[')
	exp[exp.size()-1] = exp[exp.size()-1].trim_suffix(']')
	
	#iterate through and call this function to evaluate bracketed parts
	while cnt < exp.size():
		if depth == 0: #if depth is 0, just append tokens
			#append if bool. If not bool, see if it is a variable and add it if it is a bool
			if _is_bool(exp[cnt]):
				output.append(_boolify(exp[cnt]))
			elif vars.has(exp[cnt]) and var_types[exp[cnt]] == DataTypes.BOOL:
				output.append(vars[exp[cnt]])
			elif Operands.has(exp[cnt]): #append if operand
				output.append(exp[cnt])
			else:
				_runtime_error(line_no, "Invalid argument (not a BOOL)")
		elif '[' in exp[cnt]:
			depth += 1
			if start == 0:
				start = cnt
		elif ']' in exp[cnt]:
			depth -= 1
			if depth == 0:
				output.append(_eval_bool(line_no, exp.slice(start,cnt+1)))
	
	#now, evaluate the resulting expression in the proper order (NOT, then AND, then OR)
	
#region HELPER FUNCTIONS
func _tokenize(line_no: int, line: String) -> Array: #like the interpreter tokenize function but does not condense quoted or bracketed parts
	#splits on whitespace but keeps quoted strings together
	var tokens: Array = []
	var i := 0
	while i < line.length():
		#skip whitespace (spaces or tabs)
		while i < line.length() and (line[i] == " " or line[i] == "\t"):
			i += 1
		if i >= line.length():
			break
	return tokens

func _get_max_depth(exp: Array) -> int:
	var depth = 0 #keeps track of the evaluator depth
	var max_depth = 0 #keeps track of the maximum depth
	for i in exp:
		if '[' in i:
			depth += 1
			if max_depth < depth:
				max_depth = depth
		elif ']' in i:
			depth-= 1
	return max_depth
	
func _is_bool(s: String) -> bool:
	if (s == "T" or s == "F" or s == "TRUE" or s == "FALSE" or s == "1" or s == "0"):
		return true
	else:
		return false
		
func _boolify(s: String) -> bool:
	if (s == "T" or s == "TRUE" or s == "1"):
		return true
	else:
		return false
		
func _runtime_error(line_no: int, msg: String) -> void:
	push_error("[PROT line %d] %s" % [line_no, msg])
#endregion
