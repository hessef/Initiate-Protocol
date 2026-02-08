#This code handles parsing and running scripts written in the ARGUS V 2.7.5 Instruction Set.
#Protocols (functions) can be run from .prot files and can be written freely by the player.

extends RefCounted
class_name ProtInterpreter

var vars: Dictionary = {}
var var_types: Dictionary = {}
var output: Callable = func(msg): print(msg)
var Evaluator = ExpressionEvaluator.new(vars, var_types, output)

const DataTypes = ArgusEnum.data_types

#region OPEN AND RUN FILE
func init_prot(source_code: String) -> void:
	#split into lines and process
	var lines := source_code.split("\n", true)
	var prot_len = lines.size()
	var pc := 0
	while pc < prot_len:
		var line_no := pc + 1 #save the current line number
		var raw := lines[pc]
		
		#strip comments (if present)
		var line := _strip_comment(raw).strip_edges()
		if line.is_empty():
			pc += 1
			continue

		#tokenize and process
		var tokens := _tokenize(line_no, line)
		if tokens.is_empty():
			pc += 1
			continue

		#extract opcode and run command
		var opcode := String(tokens[0])
		match opcode:
			"PRNT":
				_exec_prnt(tokens, line_no)
			"VAR":
				_exec_var(tokens, line_no)
			"SET":
				_exec_set(tokens, line_no)
			"ADD":
				_exec_add(tokens, line_no)
			"CNT": #just another way to do VAR++, like ADD VAR
				_exec_add(tokens, line_no)
			"SUB":
				_exec_sub(tokens, line_no)
			"MUL":
				_exec_mul(tokens, line_no)
			"DIV":
				_exec_div(tokens, line_no)
			"JMP":
				pc = _exec_jmp(tokens, line_no)
				continue
			_:
				_runtime_error(line_no, "Unknown command: %s" % opcode)
		pc += 1

		
#endregion

#region COMMANDS

#region BASICS
func _exec_prnt(tokens: Array, line_no: int) -> void:
	#verify that there is something to print
	if tokens.size() < 2:
		_runtime_error(line_no, "PRNT requires an argument")
		return
	
	#append arguments together
	var out := ""
	for i in range(1, tokens.size()):
		if _is_quoted(tokens[i]):
			out += _unquote(tokens[i])
		else:
			if vars.has(tokens[i]):
				out += str(vars[tokens[i]])
			else:
				_runtime_error(line_no, "No variable with name '%s'" % tokens[i])
				return

	output.call(str(out))

func _exec_var(tokens: Array, line_no: int) -> void:
	if tokens.size() < 4:
		_runtime_error(line_no, "VAR requires variable type and variable name")
		return

	var name := String(tokens[1])
	if not _is_valid_var_name(name):
		_runtime_error(line_no, "Invalid variable name: %s" % _is_valid_var_name)
		return

	#TODO: implement other types and evaluating expressions
	var type := String(tokens[2])
	match type:
		"INT":
			if vars.has(tokens[3]) and (var_types[tokens[3]] == DataTypes.INT or var_types[tokens[3] == DataTypes.FLT]):
				vars[name] = vars[tokens[3]]
				var_types[name] = var_types[tokens[3]]
			else:
				if _is_number(tokens[3]):
					vars[name] = int(tokens[3])
					var_types[name] = DataTypes.INT
				else:
					_runtime_error(line_no, "Invalid value")
					return
		"FLT":
			if vars.has(tokens[3]) and (var_types[tokens[3]] == DataTypes.INT or var_types[tokens[3] == DataTypes.FLT]):
				vars[name] = vars[tokens[3]]
				var_types[name] = var_types[tokens[3]]
			else:
				if _is_number(tokens[3]):
					vars[name] = float(tokens[3])
					var_types[name] = DataTypes.FLT
				else:
					_runtime_error(line_no, "Invalid value")
					return
		"STR":
			if tokens.size() == 4:
				if vars.has(tokens[3]) and var_types[tokens[3]] == DataTypes.STR:
					vars[name] = vars[tokens[3]]
					var_types[name] = var_types[tokens[3]]
				else:
					vars[name] = _unquote(tokens[3])
					var_types[name] = DataTypes.STR
			else:
				#append arguments together
				var out := ""
				for i in range(3, tokens.size()):
					if _is_quoted(tokens[i]):
						out += _unquote(tokens[i])
					else:
						if vars.has(tokens[i]):
							out += str(vars[tokens[i]])
						else:
							_runtime_error(line_no, "No variable with name '%s'" % tokens[i])
							return
				vars[name] = out
				var_types[name] = DataTypes.STR
		"BOOL":
			if tokens.size() == 4:
				if vars.has(tokens[3]) and var_types[tokens[3]] == DataTypes.BOOL:
					vars[name] = vars[tokens[3]]
					var_types[name] = var_types[tokens[3]]
				else:
					if _is_bool(tokens[3]):
						vars[name] = _boolify(tokens[3])
						var_types[name] = DataTypes.BOOL
					elif _is_bracketed(tokens[3]):
						vars[name] = Evaluator.evaluate_bool(line_no, tokens[3])
						var_types[name] = DataTypes.BOOL
					else:
						_runtime_error(line_no, "Invalid value")
						return
			else:
				#TODO: implement parsing expressions
				return

func _exec_set(tokens: Array, line_no: int) -> void:
	if tokens.size() < 3:
		_runtime_error(line_no, "SET requires a destination variable and a new value")
		return
	
	#worker variable
	var dest = tokens[1]
	
	#verify that the destination variable exists
	if not vars.has(dest):
		_runtime_error(line_no, "Variable %s does not exist" % dest)
		return
	
	#verify type and assign
	var type = var_types[dest]
	match type:
		DataTypes.INT:
			if vars.has(tokens[2]) and (var_types[tokens[2]] == DataTypes.INT or var_types[tokens[2]] == DataTypes.FLT):
				vars[dest] = int(vars[tokens[2]])
			else:
				if _is_number(tokens[2]):
					vars[dest] = int(tokens[2])
				else:
					_runtime_error(line_no, "Invalid value")
					return
		DataTypes.FLT:
			if vars.has(tokens[2]) and (var_types[tokens[2]] == DataTypes.INT or var_types[tokens[2]] == DataTypes.FLT):
				vars[dest] = float(vars[tokens[2]])
			else:
				if _is_number(tokens[2]):
					vars[dest] = float(tokens[2])
				else:
					_runtime_error(line_no, "Invalid value")
					return
		DataTypes.STR:
			if tokens.size() == 3:
				if vars.has(tokens[2]) and var_types[tokens[2]] == DataTypes.STR:
					vars[dest] = vars[tokens[2]]
				else:
					vars[dest] = _unquote(tokens[2])
			else:
				#append arguments together
				var out := ""
				for i in range(2, tokens.size()):
					if _is_quoted(tokens[i]):
						out += _unquote(tokens[i])
					else:
						if vars.has(tokens[i]):
							out += str(vars[tokens[i]])
						else:
							_runtime_error(line_no, "No variable with name '%s'" % tokens[i])
							return
				vars[dest] = out
		DataTypes.BOOL:
			if tokens.size() == 3:
				if vars.has(tokens[2]) and var_types[tokens[2]] == DataTypes.BOOL:
					vars[dest] = vars[tokens[2]]
				else:
					if _is_bool(tokens[2]):
						vars[dest] = _boolify(tokens[2])
					else:
						_runtime_error(line_no, "Invalid value")
						return
			else:
				#TODO: implement parsing expressions
				return
#endregion

#region BRANCHING
func _exec_jmp(tokens: Array, line_no: int) -> int:
	#TODO: actually implement JMP function (REL (default) and ABS)
	return line_no
	
func _exec_if(tokens: Array, line_no: int) -> int:
	#TODO: actually implement if statements
	return line_no
#endregion

#region MATH COMMANDS
func _exec_add(tokens: Array, line_no: int) -> void:
	if tokens.size() < 2:
		_runtime_error(line_no, "ADD requires a destination variable")
		return

	#verify that destination variable exists and is the correct type
	if not (vars.has(tokens[1]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT)):
		_runtime_error(line_no, "Invalid destination variable name: %s" % tokens[1])
		return

	#worker variables
	var dest := String(tokens[1])
	var a
	var b
	var type = var_types[tokens[1]]

	#set values based on number of tokens
	if tokens.size() == 2: #basically VAR++
		if type == DataTypes.INT:
			a = int(vars[dest])
			b = 1
		else:
			a = float(vars[dest])
			b = 1.0
	elif tokens.size() == 3:
		if type == DataTypes.INT:
			a = int(vars[dest])
			if _is_number(tokens[2]):
				b = int(tokens[2])
			else:
				if vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
					b = int(vars[tokens[2]])
		else:
			a = float(vars[dest])
			if _is_number(tokens[2]):
				b = float(tokens[2])
			else:
				if vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
					b = float(vars[tokens[2]])
	else:
		if type == DataTypes.INT:
			b = 0
			if _is_number(tokens[2]):
				a = int(tokens[2])
			elif vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
				a = int(vars[tokens[2]])
			else:
				_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
				return
			for i in range(3, tokens.size()):
				if _is_number(tokens[i]):
					b += int(tokens[i])
				else:
					if vars.has(tokens[i]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
						b += int(vars[tokens[i]])
					else:
						_runtime_error(line_no, "Invalid variable name: %s" % tokens[i])
						return
		else:
			b = 0.0
			if _is_number(tokens[2]):
				a = float(tokens[2])
			elif vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
				a = float(vars[tokens[2]])
			else:
				_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
				return
			for i in range(3, tokens.size()):
				if _is_number(tokens[i]):
					b += float(tokens[i])
				else:
					if vars.has(tokens[i]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
						b += float(vars[tokens[i]])
					else:
						_runtime_error(line_no, "Invalid variable name: %s" % tokens[i])
						return
	#actually do the math
	vars[dest] = a + b

func _exec_sub(tokens: Array, line_no: int) -> void:
	if tokens.size() < 2:
		_runtime_error(line_no, "SUB requires a destination variable")
		return

	#verify that destination variable exists and is the correct type
	if not (vars.has(tokens[1]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT)):
		_runtime_error(line_no, "Invalid destination variable name: %s" % tokens[1])
		return

	#worker variables
	var dest := String(tokens[1])
	var a
	var b
	var type = var_types[tokens[1]]

	#set values based on number of tokens
	if tokens.size() == 2: #basically VAR--
		if type == DataTypes.INT:
			a = int(vars[dest])
			b = 1
		else:
			a = float(vars[dest])
			b = 1.0
	elif tokens.size() == 3:
		if type == DataTypes.INT:
			a = int(vars[dest])
			if _is_number(tokens[2]):
				b = int(tokens[2])
			else:
				if vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
					b = int(vars[tokens[2]])
		else:
			a = float(vars[dest])
			if _is_number(tokens[2]):
				b = float(tokens[2])
			else:
				if vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
					b = float(vars[tokens[2]])
	else:
		if type == DataTypes.INT:
			b = 0
			if _is_number(tokens[2]):
				a = int(tokens[2])
			elif vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
				a = int(vars[tokens[2]])
			else:
				_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
				return
			for i in range(3, tokens.size()):
				if _is_number(tokens[i]):
					b += int(tokens[i])
				else:
					if vars.has(tokens[i]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
						b += int(vars[tokens[i]])
					else:
						_runtime_error(line_no, "Invalid variable name: %s" % tokens[i])
						return
		else:
			b = 0.0
			if _is_number(tokens[2]):
				a = float(tokens[2])
			elif vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
				a = float(vars[tokens[2]])
			else:
				_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
				return
			for i in range(3, tokens.size()):
				if _is_number(tokens[i]):
					b += float(tokens[i])
				else:
					if vars.has(tokens[i]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
						b += float(vars[tokens[i]])
					else:
						_runtime_error(line_no, "Invalid variable name: %s" % tokens[i])
						return

	#actually do the math
	vars[dest] = a - b

func _exec_mul(tokens: Array, line_no: int) -> void:
	if tokens.size() < 2:
		_runtime_error(line_no, "SUB requires a destination variable")
		return

	#verify that destination variable exists and is the correct type
	if not (vars.has(tokens[1]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT)):
		_runtime_error(line_no, "Invalid destination variable name: %s" % tokens[1])
		return

	#worker variables
	var dest := String(tokens[1])
	var a
	var b
	var type = var_types[tokens[1]]

	#set values based on number of tokens
	if tokens.size() == 2: #basically VAR * VAR
		if type == DataTypes.INT:
			a = int(vars[dest])
			b = a
		else:
			a = float(vars[dest])
			b = a
	elif tokens.size() == 3:
		if type == DataTypes.INT:
			a = int(vars[dest])
			if _is_number(tokens[2]):
				b = int(tokens[2])
			else:
				if vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
					b = int(vars[tokens[2]])
		else:
			a = float(vars[dest])
			if _is_number(tokens[2]):
				b = float(tokens[2])
			else:
				if vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
					b = float(vars[tokens[2]])
	else:
		if type == DataTypes.INT:
			b = 1
			if _is_number(tokens[2]):
				a = int(tokens[2])
			elif vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
				a = int(vars[tokens[2]])
			else:
				_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
				return
			for i in range(3, tokens.size()):
				if _is_number(tokens[i]):
					b *= int(tokens[i])
				else:
					if vars.has(tokens[i]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
						b *= int(vars[tokens[i]])
					else:
						_runtime_error(line_no, "Invalid variable name: %s" % tokens[i])
						return
		else:
			b = 1.0
			if _is_number(tokens[2]):
				a = float(tokens[2])
			elif vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
				a = float(vars[tokens[2]])
			else:
				_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
				return
			for i in range(3, tokens.size()):
				if _is_number(tokens[i]):
					b *= float(tokens[i])
				else:
					if vars.has(tokens[i]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
						b *= float(vars[tokens[i]])
					else:
						_runtime_error(line_no, "Invalid variable name: %s" % tokens[i])
						return

	#actually do the math
	vars[dest] = a * b

func _exec_div(tokens: Array, line_no: int) -> void:
	if tokens.size() < 2:
		_runtime_error(line_no, "SUB requires a destination variable")
		return

#verify that destination variable exists and is the correct type
	if not (vars.has(tokens[1]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT)):
		_runtime_error(line_no, "Invalid destination variable name: %s" % tokens[1])
		return

	#worker variables
	var dest := String(tokens[1])
	var a
	var b
	var type = var_types[tokens[1]]

	#set values based on number of tokens
	if tokens.size() == 2: #basically VAR / VAR, or just 1
		if type == DataTypes.INT:
			a = int(vars[dest])
			b = a
		else:
			a = float(vars[dest])
			b = a
	elif tokens.size() == 3:
		if type == DataTypes.INT:
			a = int(vars[dest])
			if _is_number(tokens[2]):
				b = int(tokens[2])
			else:
				if vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
					b = int(vars[tokens[2]])
		else:
			a = float(vars[dest])
			if _is_number(tokens[2]):
				b = float(tokens[2])
			else:
				if vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
					b = float(vars[tokens[2]])
	else:
		if type == DataTypes.INT:
			b = 1
			if _is_number(tokens[2]):
				a = int(tokens[2])
			elif vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
				a = int(vars[tokens[2]])
			else:
				_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
				return
			for i in range(3, tokens.size()):
				if _is_number(tokens[i]):
					b *= int(tokens[i])
				else:
					if vars.has(tokens[i]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
						b *= int(vars[tokens[i]])
					else:
						_runtime_error(line_no, "Invalid variable name: %s" % tokens[i])
						return
		else:
			b = 1.0
			if _is_number(tokens[2]):
				a = float(tokens[2])
			elif vars.has(tokens[2]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
				a = float(vars[tokens[2]])
			else:
				_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
				return
			for i in range(3, tokens.size()):
				if _is_number(tokens[i]):
					b *= float(tokens[i])
				else:
					if vars.has(tokens[i]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT):
						b *= float(vars[tokens[i]])
					else:
						_runtime_error(line_no, "Invalid variable name: %s" % tokens[i])
						return

	#don't divide by 0
	if b == 0:
		_runtime_error(line_no, "Cannot divide by zero")

	#actually do the math
	vars[dest] = a / b
#endregion

#endregion

#region TOKENIZING AND HELPERS
func _strip_comment(line: String) -> String:
	var idx := line.find("//")
	if idx == -1: #if no comment indicator is found, just return the whole line
		return line
	return line.substr(0, idx)

func _tokenize(line_no: int, line: String) -> Array:
	#splits on whitespace but keeps quoted strings together
	var tokens: Array = []
	var i := 0
	while i < line.length():
		#skip whitespace (spaces or tabs)
		while i < line.length() and (line[i] == " " or line[i] == "\t"):
			i += 1
		if i >= line.length():
			break

		#if a quotation mark is found
		if line[i] == '"':
			var start := i
			i += 1
			while i < line.length() and line[i] != '"': 
				#simple string, no escaping support in this minimal version
				i += 1
			if i < line.length() and line[i] == '"':
				i += 1
				tokens.append(line.substr(start, i - start))
			else:
				_runtime_error(line_no, "Invalid expression")
		elif line[i] == '[':
			var start := i
			var depth := 1
			i += 1
			while i < line.length() and depth != 0: 
				if line[i] == '[':
					depth += 1
				elif line[i] == ']':
					depth -= 1
				if depth == 0:
					tokens.append(line.substr(start, i - start + 1))
					i += 1
					break
				i += 1
			if depth != 0:
				_runtime_error(line_no, "Invalid expression")
		else:
			var start2 := i
			while i < line.length() and line[i] != " " and line[i] != "\t":
				i += 1
			tokens.append(line.substr(start2, i - start2))
	return tokens

func _runtime_error(line_no: int, msg: String) -> void:
	push_error("[PROT line %d] %s" % [line_no, msg])

func _is_quoted(s: String) -> bool:
	return s.length() >= 2 and s.begins_with('"') and s.ends_with('"')

func _is_bracketed(s: String) -> bool:
	return s.length() >= 2 and s.begins_with('[') and s.ends_with(']')

func _unquote(s: String) -> String:
	return s.substr(1, s.length() - 2)

func _is_valid_var_name(name: String) -> bool:
	#variable names must be in all caps and may only contain letters, numbers, and underscores
	if name.is_empty():
		return false
	for ch in name:
		var c := String(ch)
		if not ((c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_"):
			return false
	return true

func _is_number(s: String) -> bool:
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
#endregion
