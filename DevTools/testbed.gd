extends Node
class_name testbed

var Interp = ProtInterpreter.new()
var GeneralFunctions = General_Functions.new()

enum test_types{
	PROT_TEST,
	UNIT_TEST
}

var test_lines = [
	'IF HELLO', #should jump to line 3 for false, line 5 for end
	'PRNT "HI"',
	'ELSE', #should jump to line 5 for false and end
	'PRNT "BYE"',
	'END IF'
]

func _ready() -> void:
	var DO_TEST = test_types.PROT_TEST
	_generate_jump_tables(test_lines)

func _strip_comment(line: String) -> String:
	var idx := line.find("//")
	if idx == -1: #if no comment indicator is found, just return the whole line
		return line
	return line.substr(0, idx)

func _generate_jump_tables(lines: Array) -> void:
	var chain: Array = []
	var end_chain: Array = []
	var jump_end: Dictionary = {}
	var jump_false: Dictionary = {}
	
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
	print("Jump if False:")
	print(jump_false)
	print("Jump at End: ")
	print(jump_end)
