extends Node

class_name ExpressionEvaluator

var vars: Dictionary = {}
var var_types: Dictionary = {}
var output: Callable = func(msg): print(msg)

#import functions
var GeneralFunctions = General_Functions.new()

#import enums
const DataTypes = ArgusEnum.data_types
const InvalidNames = ArgusEnum.invalid_names
const Operands = ArgusEnum.operands
const CompOps = ArgusEnum.comparison_operands
const EqlOps = ArgusEnum.equality_operands
const AndOps = ArgusEnum.and_operands
const OrOps = ArgusEnum.or_operands

func _init(inh_vars: Dictionary, inh_var_types: Dictionary, inh_output: Callable):
	vars = inh_vars
	var_types = inh_var_types
	output = inh_output

func evaluate_bool(line_no: int, exp: String) -> bool:
	var tokens = _tokenize(line_no, exp)
	return _eval_bool(line_no, tokens)
	
func _eval_bool(line_no: int, exp: Array) -> bool:
	var depth := 0 #keeps track of the evaluator depth
	var cnt := 0
	var start := -1
	var output : Array = []
	
	#remove brackets from first and last tokens
	exp[0] = exp[0].trim_prefix('[')
	exp[exp.size()-1] = exp[exp.size()-1].trim_suffix(']')
	
	#iterate through and call this function to evaluate bracketed parts
	while cnt < exp.size():
		if depth == 0: #if depth is 0, just append tokens
			#append values as correct data types and replace variable names with their values
			if _is_bool(exp[cnt]):	#do bool before numbers because 1 and 0 can be BOOL
				output.append(_boolify(exp[cnt]))
			elif GeneralFunctions.is_number(exp[cnt]):
				output.append(float(exp[cnt]))
			elif vars.has(exp[cnt]):
				output.append(vars[exp[cnt]])
			elif Operands.has(exp[cnt]): #append if operand
				output.append(exp[cnt])
			elif exp[cnt].count('[') > 0:
				pass
			else:
				_runtime_error(line_no, "Invalid expression")
				return false
		
		#count brackets to update depth
		var opens = exp[cnt].count('[')
		var closes = exp[cnt].count(']')
		depth += opens
		depth -= closes
		
		if opens > 0 and start == -1:
			start = cnt
		
		if depth == 0 and start != -1:
			var inner_exp := exp.slice(start, cnt + 1)
			output.append(_eval_bool(line_no, inner_exp))
			start = -1 #reset for next bracket group
		
		cnt += 1
	
	#check which operations will be performed
	var ops = _check_op_types(output)
	
	#now, evaluate the resulting expression in the proper order (comparison, then equality, then NOT, then AND, then OR)
	if _check_share_element(ops, CompOps):
		_eval_comp(output)
	if ops.has("NOT"):
		_eval_not(output)
	if _check_share_element(ops, AndOps):
		_eval_and(output)
	if _check_share_element(ops, OrOps):
		_eval_or(output)
	return output[0]
	
#region OPERAND PROCESSING
##evaluates LESS, GRTR, LESE, GRTE operations
func _eval_comp(exp: Array) -> void:
	var cnt := 0
	while cnt < exp.size():
		if exp[cnt] is not bool and CompOps.has(exp[cnt]):
			#make sure both values are numbers
			
			var A = float(exp[cnt-1])	#input A
			var B = float(exp[cnt+1])	#input B
			var Q = false		#result
			
			#find which operation it is, then evaluate
			match exp[cnt]:
				"LESS":
					Q = A < B
				"GRTR":
					Q = A > B
				"LESE":
					Q = A <= B
				"GRTE":
					Q = A >= B
			
			#replace operand with result and remove
			exp[cnt] = Q
			exp.remove_at(cnt+1)
			exp.remove_at(cnt-1)
			
			#since a value before the current one was removed, do not increment cnt
			continue
		cnt += 1

##evaluates NOT operations
func _eval_not(exp: Array) -> void:
	var cnt := 0
	while cnt < exp.size():
		if exp[cnt] is not bool and exp[cnt] == "NOT":
			var A = exp[cnt+1]
			#replace ["NOT", v] with [!v], or if v is another NOT, just remove both
			if A is not bool and A == "NOT":
				exp.remove_at(cnt)
				exp.remove_at(cnt)
			else:
				exp.remove_at(cnt)
				exp[cnt] = !A
			#do not increment since there may be multiple NOTs in a row
			continue
		cnt += 1

##evaluates AND, NAND operations
func _eval_and(exp: Array) -> void:
	var cnt := 0
	while cnt < exp.size():
		if exp[cnt] is not bool and AndOps.has(exp[cnt]):
			var A = exp[cnt-1]	#input A
			var B = exp[cnt+1]	#input B
			var Q = false		#result
			
			#evaluate, then invert if NAND
			Q = A and B
			if exp[cnt] == "NAND":
				Q = !Q
			
			#replace operand with result and remove
			exp[cnt] = Q
			exp.remove_at(cnt+1)
			exp.remove_at(cnt-1)
			
			#since a value before the current one was removed, do not increment cnt
			continue
		cnt += 1
		
##evaluates OR, NOR, XOR, XNOR operations
func _eval_or(exp: Array) -> void:
	var cnt := 0
	while cnt < exp.size():
		if exp[cnt] is not bool and OrOps.has(exp[cnt]):
			var A = exp[cnt-1]	#input A
			var B = exp[cnt+1]	#input B
			var Q = false		#result
			
			#find which operation it is, then evaluate
			match exp[cnt]:
				"OR":
					Q = A or B
				"NOR":
					Q = !(A or B)
				"XOR":
					Q = _xor(A, B)
				"XNOR":
					Q = _xnor(A, B)
			
			#replace operand with result and remove
			exp[cnt] = Q
			exp.remove_at(cnt+1)
			exp.remove_at(cnt-1)
			
			#since a value before the current one was removed, do not increment cnt
			continue
		cnt += 1
#endregion

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
		
		var start2 := i
		while i < line.length() and line[i] != " " and line[i] != "\t":
			i += 1
		tokens.append(line.substr(start2, i - start2))
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
	return GeneralFunctions.is_bool(s)
		
func _boolify(s: String) -> bool:
	if (s == "T" or s == "TRUE" or s == "1"):
		return true
	else:
		return false
		
func _runtime_error(line_no: int, msg: String) -> void:
	GeneralFunctions.runtime_error(line_no, msg)
	
func _check_op_types(exp: Array) -> Array:
	var ops: Array = [] #output array that holds the types of operations that will need to be performed
	for element in exp:
		if Operands.has(element) and not ops.has(element):
			ops.append(element)
	return ops

##returns true if two arrays have at least 1 element in common, 0 otherwise
func _check_share_element(A: Array, B: Array) -> bool:
	return GeneralFunctions.check_share_element(A, B)
	
func _xor(A: bool, B: bool) -> bool:
	return GeneralFunctions.xor(A, B)

func _xnor(A: bool, B: bool) -> bool:
	return GeneralFunctions.xnor(A, B)
	
#endregion
