#this is the object that stores the local variables, program counter, list of program lines, program length,
#and list of return addresses for a given stack item. Calling a protocol within a protocol spawns a new stack item.
extends Node

class_name StackItem

var GeneralFunctions = General_Functions.new()

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
##table of jump targets for IF/ELIF/ELSE
@export var jump_table: Dictionary = {}
##current IF statement depth
@export var if_depth: int = 0
##whether or not the interpreter is awaiting user input
@export var awaiting_input: bool = false
##holds user input
@export var input_buffer: String

func _init(assigned_pid:int, global_vars: Dictionary, global_var_types: Dictionary, output: Callable) -> void:
	PID = assigned_pid
	pc = 0
	Evaluator = ExpressionEvaluator.new(local_vars, local_var_types, global_vars, global_var_types, output)

func generate_jump_tables() -> void:
	jump_table = GeneralFunctions.generate_jump_tables(lines)
