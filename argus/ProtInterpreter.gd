#This code handles parsing and running scripts written in the ARGUS V 2.7.5 Instruction Set.
#Protocols (functions) can be run from .prot files and can be written freely by the player.

extends RefCounted
class_name ProtInterpreter

var vars: Dictionary = {}
var var_types: Dictionary = {}
var output: Callable = func(msg): print(msg)

var Evaluator = ExpressionEvaluator.new(vars, var_types, output)
var GeneralFunctions = General_Functions.new()

#import enums
const DataTypes = ArgusEnum.data_types
const InvalidVarNames = ArgusEnum.invalid_names
const BaseCycles = ArgusEnum.instruction_delays

#worker variables for internal interpretation logic
var _lines: Array = []
var _prot_len: int = 0
var _pc: int = 0
var _running: bool = false
var _wait_s: float = 0.0

#settings based on processor
@export var clock_speed = 10 #default 10 "cycles" per second

#region RUN CODE
func init_prot(source_code: String) -> void:
	_lines = source_code.split("\n", true)
	_prot_len = _lines.size()
	_pc = 0
	_wait_s = 0.0
	_running = true

##Schedule instruction execution with delay so that there are gaps
func tick(delta: float, max_steps: int = 32) -> bool:
	if not _running:
		return false

	_wait_s -= delta

	var steps := 0
	while _running and _wait_s <= 0.0 and steps < max_steps:
		# Execute one "meaningful" instruction (blank/comment lines don't count)
		var consumed_delay := _exec_one_line()

		# If we executed a real instruction, schedule the next delay
		if consumed_delay > 0.0:
			# Add (not set) so negative leftover time carries into next instruction(s)
			_wait_s += consumed_delay

		steps += 1

	return _running
	
##Execute instructions and return the delay
func _exec_one_line() -> float:
	#stop if the program is finished
	if _pc >= _prot_len:
		_running = false
		return 0.0
	
	var line_no := _pc + 1 #save the current line number
	var raw: String = _lines[_pc]
	
	#strip comments (if present)
	var line := _strip_comment(raw).strip_edges()
	if line.is_empty():
		_pc += 1
		return 0.0
	
	#tokenize
	var tokens := _tokenize(line_no, line)
	if tokens.is_empty():
		_pc += 1
		return 0.0
		
	var opcode := String(tokens[0])
	match opcode:
		"PRNT":
			_exec_prnt(tokens, line_no)
			_pc += 1
		"VAR":
			_exec_var(tokens, line_no)
			_pc += 1
		"SET":
			_exec_set(tokens, line_no)
			_pc += 1
		"ADD":
			_exec_add(tokens, line_no)
			_pc += 1
		"CNT": #just another way to do VAR++, like ADD VAR
			_exec_add(tokens, line_no)
			_pc += 1
		"SUB":
			_exec_sub(tokens, line_no)
			_pc += 1
		"MUL":
			_exec_mul(tokens, line_no)
			_pc += 1
		"DIV":
			_exec_div(tokens, line_no)
			_pc += 1
		"JMP":
			var new_pc = _exec_jmp(tokens, _pc, line_no)
			#if returned value is below 0, something went wrong
			if new_pc < 0:
				_runtime_error(line_no, "JMP command error")
				_running = false
				return 0.0
			elif new_pc >= _prot_len:
				_runtime_error(line_no, "JMP command error, invalid line number")
				_running = false
				return 0.0
			_pc = new_pc #only set pc if JMP command was successful
		_:
			_runtime_error(line_no, "Unknown command: %s" % opcode)
			_running = false
			return 0.0
	
	#check if this was the final line and mark as done if so
	if _pc >= _prot_len:
		_running = false
		
	#return the delay based on the instruction
	return _get_instruction_delay(line_no, opcode, tokens)
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

	#TODO: implement other types
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
						vars[name] = _boolify(tokens[3].to_upper())
						var_types[name] = DataTypes.BOOL
					elif _is_bracketed(tokens[3]):
						vars[name] = Evaluator.evaluate_bool(line_no, tokens[3])
						var_types[name] = DataTypes.BOOL
					else:
						_runtime_error(line_no, "Invalid value")
						return
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
					var_types[dest] = var_types[tokens[2]]
				else:
					if _is_bool(tokens[2]):
						vars[dest] = _boolify(tokens[2].to_upper())
						var_types[dest] = DataTypes.BOOL
					elif _is_bracketed(tokens[2]):
						vars[dest] = Evaluator.evaluate_bool(line_no, tokens[2])
						var_types[dest] = DataTypes.BOOL
					else:
						_runtime_error(line_no, "Invalid value")
						return
			else:
				#TODO: implement parsing expressions
				return
#endregion

#region BRANCHING
##handles executing JMP command (JMP -> relative, JMP REL -> relative, JMP ABS -> absolute)
func _exec_jmp(tokens: Array, pc: int, line_no: int) -> int:
	#verify correct number of arguments and interperet accordingly
	if tokens.size() > 3:
		_runtime_error(line_no, "JMP command cannot have more than 2 arguments")
		return -1
	elif tokens.size() == 2:
		return _rel_jmp(pc, tokens[1])
	elif tokens.size() == 3:
		if tokens[1] == "REL":
			return _rel_jmp(pc, tokens[2])
		elif tokens[1] == "ABS":
			return _abs_jmp(tokens[2])
	#if all else fails, return -1
	return -1
	
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
			tokens.append(line.substr(start2, i - start2).to_upper())
	return tokens

func _runtime_error(line_no: int, msg: String) -> void:
	GeneralFunctions.runtime_error(line_no, msg)

func _is_quoted(s: String) -> bool:
	return GeneralFunctions.is_quoted(s)

func _is_bracketed(s: String) -> bool:
	return GeneralFunctions.is_bracketed(s)

func _unquote(s: String) -> String:
	return GeneralFunctions.unquote(s)

func _is_valid_var_name(name: String) -> bool:
	return GeneralFunctions.is_valid_var_name(name)

func _is_number(s: String) -> bool:
	return GeneralFunctions.is_number(s)
	
func _is_bool(s: String) -> bool:
	return GeneralFunctions.is_bool(s)
		
func _boolify(s: String) -> bool:
	if (s == "T" or s == "TRUE" or s == "1"):
		return true
	else:
		return false

func _rel_jmp(pc: int, arg: String) -> int:
	if _is_number(arg):
		if GeneralFunctions.is_int(arg):
			return pc + int(arg)
	else:
		if vars.has(arg) and var_types[arg] == DataTypes.INT:
			return pc + vars[arg]
	#if it gets to here, something went wrong
	return -1
	
func _abs_jmp(arg: String) -> int:
	if _is_number(arg):
		if GeneralFunctions.is_int(arg):
			return int(arg) - 1 #-1 accounts for the difference in line number and program counter
	else:
		if vars.has(arg) and var_types[arg] == DataTypes.INT:
			return vars[arg] - 1 #-1 accounts for the difference in line number and program counter
	#if it gets to here, something went wrong
	return -1

func _get_instruction_delay(line_no: int, opcode: String, tokens: Array) -> float:
	#get base delay, then add delays for each operator if there is an expression
	var base_delay = BaseCycles[opcode]
	var operator_delay := 0.0
	for tok in tokens:
		if GeneralFunctions.is_bracketed(tok):
			operator_delay = GeneralFunctions.get_expression_delay(line_no, tok)
			
	#add delays then divide by clock speed to get wait time in seconds
	var full_delay = (base_delay + operator_delay) / clock_speed
	return full_delay
#endregion
