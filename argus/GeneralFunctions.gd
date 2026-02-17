extends Node

class_name General_Functions

const InvalidVarNames = ArgusEnum.invalid_names
const BaseCycles = ArgusEnum.instruction_delays
const Operators = ArgusEnum.operators
const DataTypes = ArgusEnum.data_types

func runtime_error(line_no: int, msg: String) -> void:
	if line_no == -1:
		push_error("[PROT] %s" % msg)
	else:
		push_error("[PROT line %d] %s" % [line_no, msg])

func is_quoted(s: String) -> bool:
	return s.length() >= 2 and s.begins_with('"') and s.ends_with('"')

func is_bracketed(s: String) -> bool:
	return s.length() >= 2 and s.begins_with('[') and s.ends_with(']')

func unquote(s: String) -> String:
	return s.substr(1, s.length() - 2)

func is_valid_var_name(name: String) -> bool:
	#variable names must be in all caps and may only contain letters, numbers, and underscores
	if name.is_empty():
		return false
	for ch in name:
		var c := String(ch)
		if not ((c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_"):
			return false
	#make sure variable name is not in the banned list
	if InvalidVarNames.has(name):
		return false
	return true

func is_number(s: String) -> bool:
	# Accept ints/floats like 12, -3, 4.2
	# (Unary minus handled only when attached to the literal token, e.g. "-3")
	var f := s.to_float()
	# Godot returns 0.0 for invalid too, so we need a stricter check:
	# Try parsing by regex-like manual scan.
	var i := 0
	if s.begins_with("-"):
		i = 1
		if s.length() == 1:
			return false
	var saw_digit := false
	var saw_dot := false
	while i < s.length():
		var c := s[i]
		if c >= "0" and c <= "9":
			saw_digit = true
		elif c == "." and not saw_dot:
			saw_dot = true
		else:
			return false
		i += 1
	return saw_digit
	
func is_bool(s: String) -> bool:
	s = s.to_upper()
	if (s == "T" or s == "F" or s == "TRUE" or s == "FALSE"):
		return true
	else:
		return false
		
##returns true if two arrays have at least 1 element in common, 0 otherwise
func check_share_element(A: Array, B: Array) -> bool:
	for item in A:
		if B.has(item):
			return true
	return false
	
func xor(A: bool, B: bool) -> bool:
	if (A or B) and not (A and B):
		return true
	else:
		return false

func xnor(A: bool, B: bool) -> bool:
	var Q = xor(A, B)
	Q = !Q
	return Q
	
func is_int(s: String) -> bool:
	var num = float(s)
	return is_equal_approx(num, int(num))

func get_expression_delay(line_no: int, exp: String) -> float:
	var tokens = tokenize_expression(line_no, exp)
	var exp_delay := 0.0
	for element in tokens:
		if element is String:
			#remove brackets and set to upper case
			element = element.to_upper()
			element = element.replace('[', '')
			element = element.replace(']', '')
			#check if operator
			if Operators.has(element):
				#print_debug("ELEMENT: %s\nDELAY: %f" % [element, BaseCycles[element]])
				exp_delay += BaseCycles[element]
				#print_debug("CURRENT TOTAL DELAY: %f" % exp_delay)
	return exp_delay

func tokenize_expression(line_no: int, line: String) -> Array: #like the interpreter tokenize function but does not condense bracketed parts
	#splits on whitespace but keeps quoted strings together
	var tokens: Array = []
	var i := 0
	while i < line.length():
		#skip whitespace (spaces or tabs)
		#print("%d: %s" % [i, line[i]])
		while i < line.length() and (line[i] == " " or line[i] == "\t"):
			i += 1
		if i >= line.length():
			break
		
		#if a quotation mark is found
		if line[i] == '"' or (line[i] == '[' and line[i+1] == '"'): #edge case where bracket is directly followed by quote
			var start := i
			if line[i+1] == '"':
				i += 1
			i += 1
			while i < line.length() and line[i] != '"': 
				#simple string, no escaping support in this minimal version
				i += 1
			if i < line.length() and line[i] == '"':
				if line[i+1] == ']': #edge case where the final two characters are "]
					i += 1
					while i < line.length() and line[i] == ']':
						i += 1
				i += 1
				tokens.append(line.substr(start, i - start))
			else:
				runtime_error(line_no, "Invalid expression")
		else:
			var start2 := i
			while i < line.length() and line[i] != " " and line[i] != "\t":
				i += 1
			tokens.append(line.substr(start2, i - start2))
	return tokens

##returns the actual value as [0] and status bool as [1] (-1 means variable not found or not right type)
func get_variable_value(name: String, type: DataTypes, global_vars: Dictionary, global_var_types: Dictionary, local_vars: Dictionary, local_var_types: Dictionary) -> Array:
	#if it's a number, could be either INT or FLT
	if type == DataTypes.INT or type == DataTypes.FLT:
		#check local variables, then global
		if local_vars.has(name) and (local_var_types[name] == DataTypes.INT or local_var_types[name] == DataTypes.FLT):
			return [local_vars[name], 0]
		elif global_vars.has(name) and (global_var_types[name] == DataTypes.INT or global_var_types[name] == DataTypes.FLT):
			return [global_vars[name], 0]
	else:
		#check local variables, then global
		if local_vars.has(name) and local_var_types[name] == type:
			return [local_vars[name], 0]
		elif global_vars.has(name) and global_var_types[name] == type:
			return [global_vars[name], 0]
	
	return [0, -1] #default return if fails

func _strip_comment(line: String) -> String:
	var idx := line.find("//")
	if idx == -1: #if no comment indicator is found, just return the whole line
		return line
	return line.substr(0, idx)

func generate_jump_tables(lines: Array) -> Dictionary:
	var cond_stack: Array[int] = [] #current IF/ELIF line numbers per nesting
	var endlist_stack: Array = [] #per level: lines that should jump after END IF
	var else_seen_stack: Array[bool] = [] #per level: whether ELSE has been seen
	
	var jump_end: Dictionary = {}
	var jump_false: Dictionary = {}
	var endif_for: Dictionary = {}
	
	for i in range(lines.size()):
		var line_no := i + 1 #save the current line number
		var raw: String = lines[i]
		
		#strip comments (if present)
		var line := _strip_comment(raw).strip_edges()
		if line.is_empty():
			continue
		
		#simple tokenize since we are just looking for first 2 arguments
		var tokens = line.split(" ")
		if tokens.is_empty():
			continue
		
		var opcode := String(tokens[0].to_upper())
		
		match opcode:
			"IF":
				cond_stack.append(line_no)
				endlist_stack.append([]) #include the IF itself
				else_seen_stack.append(false)
			"ELIF":
				if cond_stack.is_empty():
					runtime_error(line_no, "ELIF without IF")
					continue
				
				if else_seen_stack[-1]:
					runtime_error(line_no, "ELIF after ELSE")
					continue
				
				#add false jump location for current if
				jump_false[cond_stack[-1]] = line_no
				#replace current cond_stack final value with current line_no
				cond_stack[-1] = line_no
				#add starting jump point of 
				endlist_stack[-1].append(line_no-1)
					
			"ELSE":
				if cond_stack.is_empty():
					runtime_error(line_no, "ELSE without IF")
					continue
					
				if else_seen_stack[-1]:
					runtime_error(line_no, "Multiple ELSE")
					continue
				else_seen_stack[-1] = true
				
				#add false jump location for current if
				jump_false[cond_stack[-1]] = line_no
				#replace current cond_stack final value with current line_no
				cond_stack[-1] = line_no
				#add starting jump point of 
				endlist_stack[-1].append(line_no-1)
				
			"END":
				#verify it's not another kind of END statement
				if tokens.size() < 2 or tokens[1].to_upper() != "IF":
					continue
				if cond_stack.is_empty():
					runtime_error(line_no, "END IF without IF")
					continue
					
				#any final condition false goes after END IF
				jump_false[cond_stack[-1]] = line_no + 1
				
				#set next line as the jump target for ending if blocks 
				for item in endlist_stack[-1]:
					jump_end[item] = line_no + 1
					endif_for[item] = line_no #so when it reaches the final line in an IF block, it will jump
				
				#pop nesting
				cond_stack.pop_back()
				endlist_stack.pop_back()
				else_seen_stack.pop_back()
	#check for unclosed if statements
	if not cond_stack.is_empty():
		runtime_error(-1, "Unclosed IF block(s)")
	return {
		"jump_false": jump_false,
		"jump_end": jump_end,
		"endif_for": endif_for
	}
