#This code handles parsing and running scripts written in the ARGUS V 2.7.5 Instruction Set.
#Protocols (functions) can be run from .prot files and can be written freely by the player.

extends RefCounted
class_name ProtInterpreter

var vars: Dictionary = {} #holds global variables (set with GVAR, not VAR)
var var_types: Dictionary = {} #holds global variable types (set with GVAR, not VAR)
var output: Callable = func(msg): print(msg)
var input_source: TerminalUI
signal input_received

#var Evaluator = ExpressionEvaluator.new(vars, var_types, output)
var GeneralFunctions = General_Functions.new()

#parent ProtRunner
var prot_runner: ProtRunner

#import enums
const DataTypes = ArgusEnum.data_types
const InvalidVarNames = ArgusEnum.invalid_names
const BaseCycles = ArgusEnum.instruction_delays
const ExecState = ArgusEnum.execution_state

#worker variables for internal interpretation logic
var _state: ExecState = ExecState.STOPPED
var _wait_s: float = 0.0
var _scripts_path: String = "res://scripts/"
var _awaiting_input: bool = false

#stack
var _stack: Array[StackItem]
var next_pid: int = 0

#settings based on processor
@export var clock_speed = 10 #default 10 "cycles" per second

#region SETUP
func assign_input_source(source: TerminalUI) -> void:
	input_source = source
#endregion

#region RUN CODE
func init_prot(source_code: String) -> void:
	_stack.append(StackItem.new(next_pid, vars, var_types, output))
	next_pid += 1
	_stack[-1].lines = source_code.split("\n", true)
	_stack[-1].prot_len = _stack[-1].lines.size()
	_stack[-1].pc = 0
	_stack[-1].generate_jump_tables()
	_wait_s = 0.0
	_state = ExecState.RUNNING

##Schedule instruction execution with delay so that there are gaps
func tick(delta: float, max_steps: int = 32) -> bool:
	if  _state == ExecState.STOPPED:
		return false
	
	_wait_s -= delta

	var steps := 0
	while _state == ExecState.RUNNING and _wait_s <= 0.0 and steps < max_steps:
		# Execute one "meaningful" instruction (blank/comment lines don't count)
		var consumed_delay := _exec_one_line()
		
		#if INP, immediately stop this iteration of the loop
		if _state != ExecState.RUNNING:
			break

		# If we executed a real instruction, schedule the next delay
		if consumed_delay > 0.0:
			# Add (not set) so negative leftover time carries into next instruction(s)
			_wait_s += consumed_delay

		steps += 1

	return _state != ExecState.STOPPED
	
##Execute instructions and return the delay
func _exec_one_line() -> float:
	#stop if the program is finished
	if _stack[-1].pc >= _stack[-1].prot_len:
		#check if more in the stack
		if _stack.size() > 1:
			_stack.remove_at(-1)
		else:
			_state = ExecState.STOPPED
			return 0.0
	
	var line_no := _stack[-1].pc + 1 #save the current line number
	var raw: String = _stack[-1].lines[_stack[-1].pc]
	
	#strip comments (if present)
	var line := _strip_comment(raw).strip_edges()
	if line.is_empty():
		_stack[-1].pc += 1
		return 0.0
	
	#tokenize
	var tokens := _tokenize(line_no, line)
	if tokens.is_empty():
		_stack[-1].pc += 1
		return 0.0
		
	var opcode := String(tokens[0])
	match opcode:
		"PRNT":
			_exec_prnt(tokens, line_no)
			_stack[-1].pc += 1
		"VAR":
			_exec_var(tokens, line_no, false)
			_stack[-1].pc += 1
		"GVAR":
			_exec_var(tokens, line_no, true)
			_stack[-1].pc += 1
		"SET":
			_exec_set(tokens, line_no, false)
			_stack[-1].pc += 1
		"GSET":
			_exec_set(tokens, line_no, true)
			_stack[-1].pc += 1
		"ADD":
			_exec_add_sub(tokens, line_no, "ADD")
			_stack[-1].pc += 1
		"CNT": #just another way to do VAR++, like ADD VAR
			_exec_add_sub(tokens, line_no, "ADD")
			_stack[-1].pc += 1
		"SUB":
			_exec_add_sub(tokens, line_no, "SUB")
			_stack[-1].pc += 1
		"CNTD": #just another way to do VAR--, like SUB VAR
			_exec_add_sub(tokens, line_no, "SUB")
			_stack[-1].pc += 1
		"MUL":
			_exec_mul_div(tokens, line_no, "MUL")
			_stack[-1].pc += 1
		"DIV":
			_exec_mul_div(tokens, line_no, "DIV")
			_stack[-1].pc += 1
		"JMP":
			var new_pc = _exec_jmp(tokens, _stack[-1].pc, line_no)
			#if returned value is below 0, something went wrong
			if new_pc < 0:
				_runtime_error(line_no, "JMP command error")
				_state = ExecState.STOPPED
				return 0.0
			elif new_pc >= _stack[-1].prot_len:
				_runtime_error(line_no, "JMP command error, invalid line number")
				_state = ExecState.STOPPED
				return 0.0
			_stack[-1].pc = new_pc #only set pc if JMP command was successful
			line_no = _stack[-1].pc + 1
		"CALL":
			_stack[-1].ret_addr.append(_stack[-1].pc + 1) #append the return address
			var new_pc = _abs_jmp(tokens[1])
			#if returned value is below 0, something went wrong
			if new_pc < 0:
				_runtime_error(line_no, "CALL command error")
				_state = ExecState.STOPPED
				return 0.0
			elif new_pc >= _stack[-1].prot_len:
				_runtime_error(line_no, "CALL command error, invalid line number")
				_state = ExecState.STOPPED
				return 0.0
			_stack[-1].pc = new_pc #only set pc if CALL command was successful
			line_no = _stack[-1].pc + 1
		"RET":
			if tokens.size() != 1:
				_runtime_error(line_no, "RET command error, RET does not take arguments")
				_state = ExecState.STOPPED
				return 0.0
			
			if _stack[-1].ret_addr.is_empty():
				_runtime_error(line_no, "RET command error, CALL command has not been executed")
				_state = ExecState.STOPPED
				return 0.0
			
			#go to latest return address and remove it
			_stack[-1].pc = _stack[-1].ret_addr[-1]
			_stack[-1].ret_addr.remove_at(-1)
			line_no = _stack[-1].pc + 1
			
			#handles edge case where function call is the line directly before the start of another if block
			if _stack[-1].jump_table["jump_end"].has(line_no-1):
				_stack[-1].if_depth -= 1
				_stack[-1].pc = _stack[-1].jump_table["jump_end"][line_no-1] - 1
		"INIT":
			#TODO: implement starting a protocol on a specific unit
			_exec_init(tokens, line_no)
		"IF":
			var new_pc = _exec_if(tokens, line_no)
			#if returned value is below 0, something went wrong
			if new_pc < 0:
				_runtime_error(line_no, "IF command error")
				_state = ExecState.STOPPED
				return 0.0
			_stack[-1].pc = new_pc #only set pc if IF command was successful
		"ELIF":
			#check if 
			var new_pc = _exec_if(tokens, line_no)
			#if returned value is below 0, something went wrong
			if new_pc < 0:
				_runtime_error(line_no, "ELIF command error")
				_state = ExecState.STOPPED
				return 0.0
			_stack[-1].pc = new_pc #only set pc if IF command was successful
		"ELSE":
			#if it makes it here, just continue executing code
			_stack[-1].pc += 1
			_stack[-1].if_depth += 1
		"END":
			_exec_end(tokens, line_no)
			_stack[-1].pc += 1
		"INP":
			_exec_inp(tokens, line_no)
		_:
			_runtime_error(line_no, "Unknown command: %s" % opcode)
			_state = ExecState.STOPPED
			return 0.0
	
	#check if this was the final line and mark as done if so
	if _stack[-1].pc >= _stack[-1].prot_len:
		_state = ExecState.STOPPED
	
	#check if the end of an IF block has been reached and jump accordingly
	if _stack[-1].jump_table["jump_end"].has(line_no):
		_stack[-1].if_depth -= 1
		_stack[-1].pc = _stack[-1].jump_table["jump_end"][line_no] - 1
	
	#return the delay based on the instruction
	return _get_instruction_delay(line_no, opcode, tokens)
	
func execute_line_from_terminal(line: String) -> void:
	var trimmed := line.strip_edges()
	if trimmed.is_empty():
		return
		
	var tokens := _tokenize(0, trimmed)
	if tokens.is_empty():
		return
	var opcode := String(tokens[0])
	#same as in a protocol, but without branching, jumping, looping, etc. capabilities
	match opcode:
		"PRNT":
			_exec_prnt(tokens, 0)
		"VAR":
			_exec_var(tokens, 0, true)
		"SET":
			_exec_set(tokens, 0, true)
		"ADD":
			_exec_add_sub(tokens, 0, "ADD")
		"CNT": #just another way to do VAR++, like ADD VAR
			_exec_add_sub(tokens, 0, "ADD")
		"SUB":
			_exec_add_sub(tokens, 0, "SUB")
		"CNTD": #just another way to do VAR--, like SUB VAR
			_exec_add_sub(tokens, 0, "SUB")
		"MUL":
			_exec_mul_div(tokens, 0, "MUL")
		"DIV":
			_exec_mul_div(tokens, 0, "DIV")
		_:
			output.call("%s cannot be run from the terminal." % opcode)
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
			if _stack[-1].local_vars.has(tokens[i]):
				out += str(_stack[-1].local_vars[tokens[i]])
			elif vars.has(tokens[i]):
				out += str(vars[tokens[i]])
			else:
				_runtime_error(line_no, "No variable with name '%s'" % tokens[i])
				return

	output.call(str(out))

func _exec_var(tokens: Array, line_no: int, global: bool) -> void:
	#default set to global variables
	var dest_vars = vars
	var dest_var_types = var_types
	#set to local variable if needed
	if global == false:
		dest_vars = _stack[-1].local_vars
		dest_var_types = _stack[-1].local_var_types
		
	if tokens.size() < 4:
		_runtime_error(line_no, "%s requires variable type and variable name" % tokens[0])
		return

	var name := String(tokens[1])
	if not _is_valid_var_name(name):
		_runtime_error(line_no, "Invalid variable name: %s" % _is_valid_var_name)
		return

	#TODO: implement other types
	var type := String(tokens[2])
	match type:
		"INT":
			#check local variables first, then global variables
			if _stack[-1].local_vars.has(tokens[3]) and (_stack[-1].local_var_types[tokens[3]] == DataTypes.INT or _stack[-1].local_var_types[tokens[3] == DataTypes.FLT]):
				dest_vars[name] = int(_stack[-1].local_vars[tokens[3]])
				dest_var_types[name] = DataTypes.INT
			elif vars.has(tokens[3]) and (var_types[tokens[3]] == DataTypes.INT or var_types[tokens[3] == DataTypes.FLT]):
				dest_vars[name] = int(vars[tokens[3]])
				dest_var_types[name] = DataTypes.INT
			else:
				if _is_number(tokens[3]):
					dest_vars[name] = int(tokens[3])
					dest_var_types[name] = DataTypes.INT
				else:
					_runtime_error(line_no, "Invalid value")
					return
		"FLT":
			#check local variables first, then global variables
			if _stack[-1].local_vars.has(tokens[3]) and (_stack[-1].local_var_types[tokens[3]] == DataTypes.INT or _stack[-1].local_var_types[tokens[3] == DataTypes.FLT]):
				dest_vars[name] = float(_stack[-1].local_vars[tokens[3]])
				dest_var_types[name] = DataTypes.FLT
			elif vars.has(tokens[3]) and (var_types[tokens[3]] == DataTypes.INT or var_types[tokens[3] == DataTypes.FLT]):
				dest_vars[name] = float(vars[tokens[3]])
				dest_var_types[name] = DataTypes.FLT
			else:
				if _is_number(tokens[3]):
					dest_vars[name] = float(tokens[3])
					dest_var_types[name] = DataTypes.FLT
				else:
					_runtime_error(line_no, "Invalid value")
					return
		"STR":
			#check local variables first, then global variables
			if tokens.size() == 4:
				if _stack[-1].local_vars.has(tokens[3]) and _stack[-1].local_var_types[tokens[3]] == DataTypes.STR:
					dest_vars[name] = _stack[-1].local_vars[tokens[3]]
					dest_var_types[name] = DataTypes.STR
				elif vars.has(tokens[3]) and var_types[tokens[3]] == DataTypes.STR:
					dest_vars[name] = vars[tokens[3]]
					dest_var_types[name] = DataTypes.STR
				else:
					dest_vars[name] = _unquote(tokens[3])
					dest_var_types[name] = DataTypes.STR
			else:
				#append arguments together
				var out := ""
				for i in range(3, tokens.size()):
					if _is_quoted(tokens[i]):
						out += _unquote(tokens[i])
					else:
						if _stack[-1].local_vars.has(tokens[i]):
							out += str(_stack[-1].local_vars[tokens[i]])
						elif vars.has(tokens[i]):
							out += str(vars[tokens[i]])
						else:
							_runtime_error(line_no, "No variable with name '%s'" % tokens[i])
							return
				dest_vars[name] = out
				dest_var_types[name] = DataTypes.STR
		"BOOL":
			#check local variables first, then global variables
			if tokens.size() == 4:
				if _stack[-1].local_vars.has(tokens[3]) and _stack[-1].local_var_types[tokens[3]] == DataTypes.BOOL:
					dest_vars[name] = _stack[-1].local_vars[tokens[3]]
					dest_var_types[name] = DataTypes.BOOL
				elif vars.has(tokens[3]) and var_types[tokens[3]] == DataTypes.BOOL:
					dest_vars[name] = vars[tokens[3]]
					dest_var_types[name] = DataTypes.BOOL
				else:
					if _is_bool(tokens[3]):
						dest_vars[name] = _boolify(tokens[3].to_upper())
						dest_var_types[name] = DataTypes.BOOL
					elif _is_bracketed(tokens[3]):
						dest_vars[name] = _stack[-1].Evaluator.evaluate_bool(line_no, tokens[3])
						dest_var_types[name] = DataTypes.BOOL
					else:
						_runtime_error(line_no, "Invalid value")
						return
				return

func _exec_set(tokens: Array, line_no: int, global: bool) -> void:
	var dest_vars = vars
	var dest_var_types = var_types
	if global == false:
		dest_vars = _stack[-1].local_vars
		dest_var_types = _stack[-1].local_var_types
	if tokens.size() < 3:
		_runtime_error(line_no, "%s requires a destination variable and a new value" % tokens[0])
		return
	
	#worker variable
	var dest = tokens[1]
	
	#verify that the destination variable exists
	if not dest_vars.has(dest):
		_runtime_error(line_no, "Variable %s does not exist" % dest)
		return
	
	#verify type and assign
	var type = dest_var_types[dest]
	match type:
		DataTypes.INT:
			#check local variables first, then global variables
			if _stack[-1].local_vars.has(tokens[2]) and (_stack[-1].local_var_types[tokens[2]] == DataTypes.INT or _stack[-1].local_var_types[tokens[2]] == DataTypes.FLT):
				dest_vars[dest] = int(_stack[-1].local_vars[tokens[2]])
			elif vars.has(tokens[2]) and (var_types[tokens[2]] == DataTypes.INT or var_types[tokens[2]] == DataTypes.FLT):
				dest_vars[dest] = int(vars[tokens[2]])
			else:
				if _is_number(tokens[2]):
					dest_vars[dest] = int(tokens[2])
				else:
					_runtime_error(line_no, "Invalid value")
					return
		DataTypes.FLT:
			#check local variables first, then global variables
			if _stack[-1].local_vars.has(tokens[2]) and (_stack[-1].local_var_types[tokens[2]] == DataTypes.INT or _stack[-1].local_var_types[tokens[2]] == DataTypes.FLT):
				dest_vars[dest] = float(_stack[-1].local_vars[tokens[2]])
			elif vars.has(tokens[2]) and (var_types[tokens[2]] == DataTypes.INT or var_types[tokens[2]] == DataTypes.FLT):
				dest_vars[dest] = float(vars[tokens[2]])
			else:
				if _is_number(tokens[2]):
					dest_vars[dest] = float(tokens[2])
				else:
					_runtime_error(line_no, "Invalid value")
					return
		DataTypes.STR:
			#check local variables first, then global variables
			if tokens.size() == 3:
				if _stack[-1].local_vars.has(tokens[2]) and _stack[-1].local_var_types[tokens[2]] == DataTypes.STR:
					dest_vars[dest] = _stack[-1].local_vars[tokens[2]]
				elif vars.has(tokens[2]) and var_types[tokens[2]] == DataTypes.STR:
					dest_vars[dest] = vars[tokens[2]]
				else:
					dest_vars[dest] = _unquote(tokens[2])
			else:
				#append arguments together
				var out := ""
				for i in range(2, tokens.size()):
					if _is_quoted(tokens[i]):
						out += _unquote(tokens[i])
					else:
						if _stack[-1].local_vars.has(tokens[i]):
							out += str(_stack[-1].local_vars[tokens[i]])
						elif vars.has(tokens[i]):
							out += str(vars[tokens[i]])
						else:
							_runtime_error(line_no, "No variable with name '%s'" % tokens[i])
							return
				dest_vars[dest] = out
		DataTypes.BOOL:
			#check local variables first, then global variables
			if tokens.size() == 3:
				if _stack[-1].local_vars.has(tokens[2]) and _stack[-1].local_var_types[tokens[2]] == DataTypes.BOOL:
					dest_vars[dest] = _stack[-1].local_vars[tokens[2]]
				elif vars.has(tokens[2]) and var_types[tokens[2]] == DataTypes.BOOL:
					dest_vars[dest] = vars[tokens[2]]
				else:
					if _is_bool(tokens[2]):
						dest_vars[dest] = _boolify(tokens[2].to_upper())
					elif _is_bracketed(tokens[2]):
						dest_vars[dest] = _stack[-1].Evaluator.evaluate_bool(line_no, tokens[2])
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
	#first get the value of the expression
	var exp = tokens[1]
	var exp_val
	if tokens.size() == 2:
		if _stack[-1].local_vars.has(exp) and _stack[-1].local_var_types[exp] == DataTypes.BOOL:
			exp_val = _stack[-1].local_vars[exp]
		elif vars.has(exp) and var_types[exp] == DataTypes.BOOL:
			exp_val = vars[exp]
		else:
			if _is_bool(exp):
				exp_val = _boolify(exp.to_upper())
			elif _is_bracketed(exp):
				exp_val = _stack[-1].Evaluator.evaluate_bool(line_no, exp)
			else:
				_runtime_error(line_no, "Invalid value")
				return -1
		#once the value is found, set the in_if variable on the stack accordingly and skip lines as needed
		if exp_val == true:
			_stack[-1].if_depth += 1
			return _stack[-1].pc + 1
		else:
			return _stack[-1].jump_table["jump_false"][line_no]
						
	else:
		_runtime_error(line_no, "%s command takes a single argument" % tokens[0])
		return -1

func _exec_end(tokens: Array, line_no: int) -> void:
	#check if end of program or if length is 2
	if tokens.size() == 1:
		#if just END, set pc to end of the program
		_stack[-1].pc = _stack[-1].prot_len
		return
	elif tokens.size() > 2:
		_runtime_error(line_no, "END can only take a maximum of one argument")
		return
	
	var arg = tokens[1]
	match arg:
		"IF":
			_stack[-1].if_depth -= 1
			return
		_:
			_runtime_error(line_no, "Invalid argument for END command")
			return
#endregion

#region GAMEPLAY
func _exec_init(tokens: Array, line_no: int) -> void:
	#TODO: implement other INIT arguments
	var arg = tokens[1]
	match arg.to_upper():
		"PROT":
			#get the path name based on the name called
			var file_name: String
			if _is_quoted(tokens[2]):
				file_name = _unquote(tokens[2]) + ".prot"
			else:
				var get_val = GeneralFunctions.get_variable_value(tokens[2], DataTypes.STR, vars, var_types, _stack[-1].local_vars, _stack[-1].local_var_types)
				if get_val[1] == 0:
					file_name = get_val[0] + ".prot"
				else:
					_runtime_error(line_no, "Variable %s not found" % tokens[2])
					_stack[-1].pc += 1
					return
			var path = _scripts_path + file_name
			if not FileAccess.file_exists(path):
				_runtime_error(line_no, "Protocol file not found: %s" % path)
				_stack[-1].pc += 1
				return

			var f := FileAccess.open(path, FileAccess.READ)
			var source := f.get_as_text()
			_stack[-1].pc += 1
			init_prot(source)
			
func _exec_inp(tokens: Array, line_no: int) -> void:
	#if there is one argument, save resulting input to it
	#if there are two or more arguments, the first is the variable and the following are to be printed
	if tokens.size() < 2:
		_runtime_error(line_no, "INP requires at least one argument")
		_state = ExecState.STOPPED
		return
	
	var get_val: Array = []
	var dest = tokens[1]
	if vars.has(dest) or _stack[-1].local_vars.has(dest):
		#set whether it is a local or global variable
		if _stack[-1].local_vars.has(dest):
			_stack[-1].input_type = _stack[-1].local_var_types[dest]
			_stack[-1].input_global = false
		else:
			_stack[-1].input_type = var_types[dest]
			_stack[-1].input_global = true
		
		#set destination variable
		_stack[-1].input_dest = String(dest)
		
		if tokens.size() == 2:
			input_source.awaiting_input = true
			_awaiting_input = true
			_state = ExecState.AWAITING_INPUT
	
#endregion

#region MATH COMMANDS
func _exec_add_sub(tokens: Array, line_no: int, add_sub: String) -> void:
	if tokens.size() < 2:
		_runtime_error(line_no, "%s requires a destination variable" % add_sub)
		return
	
	var dest_global = false
	var dest_vars = vars
	
	#verify that destination variable exists and is the correct type
	if not (_stack[-1].local_vars.has(tokens[1]) and (_stack[-1].local_var_types[tokens[1]] == DataTypes.INT or _stack[-1].local_var_types[tokens[1]] == DataTypes.FLT)):
		dest_global = true
		if not (vars.has(tokens[1]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT)):
				_runtime_error(line_no, "Invalid destination variable name: %s" % tokens[1])
				return

	#worker variables
	var dest := String(tokens[1])
	var a
	var b
	var type: DataTypes
	if dest_global == true:
		type = var_types[tokens[1]]
	else:
		type = _stack[-1].local_var_types[tokens[1]]
		dest_vars = _stack[-1].local_vars
		
	#set values based on number of tokens
	if tokens.size() == 2: #basically VAR++
		if type == DataTypes.INT:
			a = int(dest_vars[dest])
			b = 1
		else:
			a = float(dest_vars[dest])
			b = 1.0
	elif tokens.size() == 3:
		if type == DataTypes.INT:
			a = int(dest_vars[dest])
			if _is_number(tokens[2]):
				b = int(tokens[2])
			else:
				#check local variables first, then global
				if _stack[-1].local_vars.has(tokens[2]) and (_stack[-1].local_var_types[tokens[2]] == DataTypes.INT or _stack[-1].local_var_types[tokens[2]] == DataTypes.FLT):
					b = int(_stack[-1].local_vars[tokens[2]])
				elif vars.has(tokens[2]) and (var_types[tokens[2]] == DataTypes.INT or var_types[tokens[2]] == DataTypes.FLT):
					b = int(vars[tokens[2]])
		else:
			a = float(dest_vars[dest])
			if _is_number(tokens[2]):
				b = float(tokens[2])
			else:
				#check local variables first, then global
				if _stack[-1].local_vars.has(tokens[2]) and (_stack[-1].local_var_types[tokens[2]] == DataTypes.INT or _stack[-1].local_var_types[tokens[2]] == DataTypes.FLT):
					b = float(_stack[-1].local_vars[tokens[2]])
				elif vars.has(tokens[2]) and (var_types[tokens[2]] == DataTypes.INT or var_types[tokens[2]] == DataTypes.FLT):
					b = float(vars[tokens[2]])
	else:
		if type == DataTypes.INT:
			b = 0
			if _is_number(tokens[2]):
				a = int(tokens[2])
			#check local variables first, then global
			elif _stack[-1].local_vars.has(tokens[2]) and (_stack[-1].local_var_types[tokens[2]] == DataTypes.INT or _stack[-1].local_var_types[tokens[2]] == DataTypes.FLT):
				a = int(_stack[-1].local_vars[tokens[2]])
			elif vars.has(tokens[2]) and (var_types[tokens[2]] == DataTypes.INT or var_types[tokens[2]] == DataTypes.FLT):
				a = int(vars[tokens[2]])
			else:
				_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
				return
			for i in range(3, tokens.size()):
				if _is_number(tokens[i]):
					b += int(tokens[i])
				else:
					#check local variables first, then global
					if _stack[-1].local_vars.has(tokens[i]) and (_stack[-1].local_var_types[tokens[i]] == DataTypes.INT or _stack[-1].local_var_types[tokens[i]] == DataTypes.FLT):
						b += int(_stack[-1].local_vars[tokens[i]])
					elif vars.has(tokens[i]) and (var_types[tokens[i]] == DataTypes.INT or var_types[tokens[i]] == DataTypes.FLT):
						b += int(vars[tokens[i]])
					else:
						_runtime_error(line_no, "Invalid variable name: %s" % tokens[i])
						return
		else:
			b = 0.0
			if _is_number(tokens[2]):
				a = float(tokens[2])
			#check local variables first, then global
			elif _stack[-1].local_vars.has(tokens[2]) and (_stack[-1].local_var_types[tokens[2]] == DataTypes.INT or _stack[-1].local_var_types[tokens[2]] == DataTypes.FLT):
				a = float(_stack[-1].local_vars[tokens[2]])
			elif vars.has(tokens[2]) and (var_types[tokens[2]] == DataTypes.INT or var_types[tokens[2]] == DataTypes.FLT):
				a = float(vars[tokens[2]])
			else:
				_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
				return
			for i in range(3, tokens.size()):
				if _is_number(tokens[i]):
					b += float(tokens[i])
				else:
					#check local variables first, then global
					if _stack[-1].local_vars.has(tokens[i]) and (_stack[-1].local_var_types[tokens[i]] == DataTypes.INT or _stack[-1].local_var_types[tokens[i]] == DataTypes.FLT):
						b += float(_stack[-1].local_vars[tokens[i]])
					elif vars.has(tokens[i]) and (var_types[tokens[i]] == DataTypes.INT or var_types[tokens[i]] == DataTypes.FLT):
						b += float(vars[tokens[i]])
					else:
						_runtime_error(line_no, "Invalid variable name: %s" % tokens[i])
						return
	#actually do the math
	if add_sub == "ADD":
		dest_vars[dest] = a + b
	elif add_sub == "SUB":
		dest_vars[dest] = a - b

func _exec_mul_div(tokens: Array, line_no: int, mul_div: String) -> void:
	if tokens.size() < 2:
		_runtime_error(line_no, "%s requires a destination variable" % mul_div)
		return

	var dest_global = false
	var dest_vars = vars
	
	#verify that destination variable exists and is the correct type
	if not (_stack[-1].local_vars.has(tokens[1]) and (_stack[-1].local_var_types[tokens[1]] == DataTypes.INT or _stack[-1].local_var_types[tokens[1]] == DataTypes.FLT)):
		dest_global = true
		if not (vars.has(tokens[1]) and (var_types[tokens[1]] == DataTypes.INT or var_types[tokens[1]] == DataTypes.FLT)):
				_runtime_error(line_no, "Invalid destination variable name: %s" % tokens[1])
				return

	#worker variables
	var dest := String(tokens[1])
	var a
	var b
	var type: DataTypes
	if dest_global == true:
		type = var_types[tokens[1]]
	else:
		type = _stack[-1].local_var_types[tokens[1]]
		dest_vars = _stack[-1].local_vars

	#set values based on number of tokens
	if tokens.size() == 2: #basically VAR * VAR
		if type == DataTypes.INT:
			a = int(dest_vars[dest])
			b = a
		else:
			a = float(dest_vars[dest])
			b = a
	elif tokens.size() == 3:
		if type == DataTypes.INT:
			a = int(dest_vars[dest])
			if _is_number(tokens[2]):
				b = int(tokens[2])
			else:
				var get_val = GeneralFunctions.get_variable_value(tokens[2], DataTypes.INT, vars, var_types, _stack[-1].local_vars, _stack[-1].local_var_types)
				if get_val[1] == 0:
					b = int(get_val[0])
				else:
					_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
					return
		else:
			a = float(vars[dest])
			if _is_number(tokens[2]):
				b = float(tokens[2])
			else:
				var get_val = GeneralFunctions.get_variable_value(tokens[2], DataTypes.INT, vars, var_types, _stack[-1].local_vars, _stack[-1].local_var_types)
				if get_val[1] == 0:
					b = float(get_val[0])
				else:
					_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
					return
	else:
		if type == DataTypes.INT:
			b = 1
			if _is_number(tokens[2]):
				a = int(tokens[2])
			else:
				var get_val = GeneralFunctions.get_variable_value(tokens[2], DataTypes.INT, vars, var_types, _stack[-1].local_vars, _stack[-1].local_var_types)
				if get_val[1] == 0:
					a = int(get_val[0])
				else:
					_runtime_error(line_no, "Invalid variable name: %s" % tokens[2])
					return
					
			for i in range(3, tokens.size()):
				if _is_number(tokens[i]):
					b *= int(tokens[i])
				else:
					var get_val = GeneralFunctions.get_variable_value(tokens[i], DataTypes.INT, vars, var_types, _stack[-1].local_vars, _stack[-1].local_var_types)
					if get_val[1] == 0:
						b *= int(get_val[0])
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
					var get_val = GeneralFunctions.get_variable_value(tokens[i], DataTypes.INT, vars, var_types, _stack[-1].local_vars, _stack[-1].local_var_types)
					if get_val[1] == 0:
						b *= float(get_val[0])
					else:
						_runtime_error(line_no, "Invalid variable name: %s" % tokens[i])
						return

	#actually do the math
	if mul_div == "MUL":
		dest_vars[dest] = a * b
	elif mul_div == "DIV":
		#don't divide by 0
		if b == 0:
			_runtime_error(line_no, "Cannot divide by zero")
		else:
			dest_vars[dest] = a / b

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
		var val = _get_variable_value(arg, DataTypes.INT)
		if val[1] == 0:
			return pc + val[0]
	#if it gets to here, something went wrong
	return -1
	
func _abs_jmp(arg: String) -> int:
	if _is_number(arg):
		if GeneralFunctions.is_int(arg):
			return int(arg) - 1 #-1 accounts for the difference in line number and program counter
	else:
		var val = _get_variable_value(arg, DataTypes.INT)
		if val[1] == 0:
			return val[0] - 1
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
	
func set_prot_runner(runner: ProtRunner) -> void:
	prot_runner = runner

func _get_variable_value(name: String, type: DataTypes) -> Array:
	return GeneralFunctions.get_variable_value(name, type, vars, var_types, _stack[-1].local_vars, _stack[-1].local_var_types)

func accept_input(line: String) -> void:
	#store variable
	_stack[-1].input_buffer = line
	if _stack[-1].input_global == true:
		match _stack[-1].input_type:
			DataTypes.INT:
				if line.is_valid_int():
					vars[_stack[-1].input_dest] = int(line)
				else:
					output.call("Input not INT")
					return
			DataTypes.FLT:
				if line.is_valid_float():
					vars[_stack[-1].input_dest] = float(line)
				else:
					output.call("Input not FLT")
					return
			DataTypes.STR:
				#no need to check since the line is already a string
				vars[_stack[-1].input_dest] = String(line)
			DataTypes.BOOL:
				if _is_bool(line.to_upper()):
					vars[_stack[-1].input_dest] = _boolify(line)
				else:
					output.call("Input not BOOL")
					return
	else:
		match _stack[-1].input_type:
			DataTypes.INT:
				if line.is_valid_int():
					_stack[-1].local_vars[_stack[-1].input_dest] = int(line)
				else:
					output.call("Input not INT")
					return
			DataTypes.FLT:
				if line.is_valid_float():
					_stack[-1].local_vars[_stack[-1].input_dest] = float(line)
				else:
					output.call("Input not FLT")
					return
			DataTypes.STR:
				#no need to check since the line is already a string
				_stack[-1].local_vars[_stack[-1].input_dest] = String(line)
			DataTypes.BOOL:
				if _is_bool(line.to_upper()):
					_stack[-1].local_vars[_stack[-1].input_dest] = _boolify(line.to_upper())
				else:
					output.call("Input not BOOL")
					return
	
	#clear input info
	_stack[-1].input_dest = ""
	_awaiting_input = false
	input_source.awaiting_input = false
	
	#advance past INP instruction
	_stack[-1].pc += 1
	
	#resume execution of code
	_state = ExecState.RUNNING
	

#endregion
