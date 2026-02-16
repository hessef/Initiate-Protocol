#this is the object that stores the local variables, program counter, list of program lines, program length,
#and list of return addresses for a given stack item. Calling a protocol within a protocol spawns a new stack item.
extends Node

class_name StackItem

##program counter
@export var pc: int
##list of lines in the program
@export var lines: Array = []
##program length
@export var prot_len: int = 0
##return addresses for CALL/RET
@export var ret_addr: Array = []
##local variables for the stack item
@export var local_vars: Dictionary = {}
##local variable types for the stack item
@export var local_var_types: Dictionary = {}
##process ID
@export var PID: int
##expression evaluator
@export var Evaluator: ExpressionEvaluator
##table of jump targets when reaching the end of an IF/ELIF/ELSE block
@export var jump_end: Dictionary = {}
##table of jump targets when IF/ELIF/ELSE is false
@export var jump_false: Dictionary = {}

func _init(assigned_pid:int, global_vars: Dictionary, global_var_types: Dictionary, output: Callable) -> void:
	PID = assigned_pid
	pc = 0
	Evaluator = ExpressionEvaluator.new(local_vars, local_var_types, global_vars, global_var_types, output)

func _strip_comment(line: String) -> String:
	var idx := line.find("//")
	if idx == -1: #if no comment indicator is found, just return the whole line
		return line
	return line.substr(0, idx)

func _generate_jump_tables() -> void:
	var chain: Array = []
	var end_chain: Array = []
	
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
				chain.append(line_no)
				end_chain.append([])
			"ELIF":
				if chain.size() != 0:
					#add false jump location for current if
					jump_false[chain[-1]] = line_no
					#add starting jump point of 
					end_chain[-1].append(line_no)
					
					#remove last if from chain and add this elif
					chain.remove_at(-1)
					chain.append(line_no)
			"ELSE":
				if chain.size() != 0:
					#add false jump location for current if
					jump_false[chain[-1]] = line_no
					#add starting jump point of 
					end_chain[-1].append(line_no)
					
					#remove last if from chain and add this elif
					chain.remove_at(-1)
					chain.append(line_no)
			"END":
				if tokens[1].to_upper() == "IF":
					#set next line as the jump target for ending if blocks
					for item in end_chain[-1]:
						jump_end[item] = line_no + 1
					end_chain.remove_at(-1)
					jump_false[chain[-1]] = line_no + 1
					chain.remove_at(-1)
