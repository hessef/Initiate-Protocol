#This code handles parsing and running scripts written in the ARGUS V 2.7.5 Instruction Set.
#Protocols (functions) can be run from .prot files and can be written freely by the player.

#extends RefCounted
#class_name ProtInterpreter

var vars: Dictionary = {}
var var_types: Dictionary = {}
var output: Callable = func(msg): print(msg)

const DataTypes = ArgusEnum.data_types

#region OPEN AND RUN FILE
func init_prot(source_code: String) -> void:
	#split into lines and process
	var lines := source_code.split("\n", false)
	for i in range(lines.size()):
		var line_no := i + 1 #save the current line number
		var raw := lines[i]
		
		#strip comments (if present)
		var line := _strip_comment(raw).strip_edges()
		if line.is_empty():
			continue

		#tokenize and process
		var tokens := _tokenize(line)
		if tokens.is_empty():
			continue

		#extract opcode and run command
		var opcode := String(tokens[0])
		match opcode:
			"PRNT":
				_exec_prnt(tokens, line_no)
			"VAR":
				_exec_var(tokens, line_no)
			"ADD":
				_exec_add(tokens, line_no)
			"SUB":
				_exec_sub(tokens, line_no)
			"MUL":
				_exec_mul(tokens, line_no)
			"DIV":
				_exec_div(tokens, line_no)
			_:
				_runtime_error(line_no, "Unknown command: %s" % opcode)


		
#endregion

#region COMMANDS
func _exec_prnt(tokens: Array, line_no: int) -> void:
	#verify that there is something to print
	if tokens.size() < 2:
		_runtime_error(line_no, "PRNT requires an argument")
		return
	
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

	output.call(str(out))

func _exec_var(tokens: Array, line_no: int) -> void:
	if tokens.size() < 3:
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
			if vars.has(tokens[3]) and var_types[tokens[3]] == DataTypes.INT:
				vars[name] = vars[tokens[3]]
				var_types[name] = var_types[tokens[3]]
			else:
				if _is_number(tokens[3]):
					vars[name] = int(tokens[3])
					var_types[name] = DataTypes.INT
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

#TODO: add SET command

func _exec_add(tokens: Array, line_no: int) -> void:
	if tokens.size() < 2:
		_runtime_error(line_no, "ADD requires a destination variable")
		return

	#verify that destination variable exists and is the correct type
	if not (vars.has(tokens[1]) and var_types[tokens[1]] == DataTypes.INT):
		_runtime_error(line_no, "Invalid destination variable name: %s" % tokens[1])
		return

	var dest := String(tokens[1])

	var a
	var b

	#TODO: add functionality for floats
	#set values based on number of tokens
	if tokens.size() == 2: #basically VAR++
		a = int(vars[dest])
		b = 1
	elif tokens.size() == 3:
		a = int(vars[dest])
		if _is_number(tokens[2]):
			b = int(tokens[2])
		else:
			if vars.has(tokens[2]) and var_types[tokens[2]] == DataTypes.INT:
				b = int(vars[tokens[2]])
	else:
		b = 0
		if _is_number(tokens[2]):
			a = int(tokens[2])
		elif vars.has(tokens[2]) and var_types[tokens[2]] == DataTypes.INT:
			a = int(vars[tokens[2]])
		else:
			_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
			return
		for i in range(3, tokens.size()):
			if _is_number(tokens[i]):
				b += int(tokens[i])
			else:
				if vars.has(tokens[i]) and var_types[tokens[i]] == DataTypes.INT:
					b += int(vars[tokens[i]])
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
	if not (vars.has(tokens[1]) and var_types[tokens[1]] == DataTypes.INT):
		_runtime_error(line_no, "Invalid destination variable name: %s" % tokens[1])
		return

	var dest := String(tokens[1])

	var a
	var b

	#TODO: add functionality for floats
	#set values based on number of tokens
	if tokens.size() == 2: #basically VAR--
		a = int(vars[dest])
		b = 1
	elif tokens.size() == 3:
		a = int(vars[dest])
		if _is_number(tokens[2]):
			b = int(tokens[2])
		else:
			if vars.has(tokens[2]) and var_types[tokens[2]] == DataTypes.INT:
				b = int(vars[tokens[2]])
	else:
		b = 0
		if _is_number(tokens[2]):
			a = int(tokens[2])
		elif vars.has(tokens[2]) and var_types[tokens[2]] == DataTypes.INT:
			a = int(vars[tokens[2]])
		else:
			_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
			return
		for i in range(3, tokens.size()):
			if _is_number(tokens[i]):
				b += int(tokens[i])
			else:
				if vars.has(tokens[i]) and var_types[tokens[i]] == DataTypes.INT:
					b += int(vars[tokens[i]])
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
	if not (vars.has(tokens[1]) and var_types[tokens[1]] == DataTypes.INT):
		_runtime_error(line_no, "Invalid destination variable name: %s" % tokens[1])
		return

	var dest := String(tokens[1])

	var a
	var b

	#TODO: add functionality for floats
	#set values based on number of tokens
	if tokens.size() == 2: #basically VAR * VAR
		a = int(vars[dest])
		b = a
	elif tokens.size() == 3:
		a = int(vars[dest])
		if _is_number(tokens[2]):
			b = int(tokens[2])
		else:
			if vars.has(tokens[2]) and var_types[tokens[2]] == DataTypes.INT:
				b = int(vars[tokens[2]])
	else:
		b = 1
		if _is_number(tokens[2]):
			a = int(tokens[2])
		elif vars.has(tokens[2]) and var_types[tokens[2]] == DataTypes.INT:
			a = int(vars[tokens[2]])
		else:
			_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
			return
		for i in range(3, tokens.size()):
			if _is_number(tokens[i]):
				b *= int(tokens[i])
			else:
				if vars.has(tokens[i]) and var_types[tokens[i]] == DataTypes.INT:
					b *= int(vars[tokens[i]])
				else:
					_runtime_error(line_no, "Invalid variable name: %s" % tokens[i])
					return

	#actually do the math
	vars[dest] = a * b

#endregion

#region TOKENIZING AND HELPERS
func _strip_comment(line: String) -> String:
	var idx := line.find("//")
	if idx == -1: #if no comment indicator is found, just return the whole line
		return line
	return line.substr(0, idx)

func _tokenize(line: String) -> Array:
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
			var start2 := i
			while i < line.length() and line[i] != " " and line[i] != "\t":
				i += 1
			tokens.append(line.substr(start2, i - start2))

	#TODO: implement parsing expressions as a single token

	return tokens

func _runtime_error(line_no: int, msg: String) -> void:
	push_error("[PROT line %d] %s" % [line_no, msg])

func _is_quoted(s: String) -> bool:
	return s.length() >= 2 and s.begins_with('"') and s.ends_with('"')

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
#endregion
