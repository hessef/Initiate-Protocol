extends Node

class_name General_Functions

const InvalidVarNames = ArgusEnum.invalid_names

func runtime_error(line_no: int, msg: String) -> void:
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
