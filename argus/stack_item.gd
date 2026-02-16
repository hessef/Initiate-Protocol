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

func _init(assigned_pid:int, global_vars: Dictionary, global_var_types: Dictionary, output: Callable) -> void:
	PID = assigned_pid
	pc = 0
	Evaluator = ExpressionEvaluator.new(local_vars, local_var_types, global_vars, global_var_types, output)
