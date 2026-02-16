extends Node

class_name ArgusEnum

enum status{
	GOOD,
	ERROR
}

enum data_types{
	INT,
	FLT,
	STR,
	BOOL
	
}

#region OPERATORS
const operators = [	"LESS", "GRTR", "LESE", "GRTE",						#comparison
					"EQL", "NEQL", "IN", "NIN",							#equality/presence
					"NOT", "AND", "OR", "NAND", "NOR", "XOR", "XNOR"	#boolean
]

const comparison_operators = [	"LESS",	#less than
								"GRTR",	#greater than
								"LESE",	#less than or equal to
								"GRTE"	#greater than or equal to
]

const equality_operators = [	"EQL",	#equal to
								"NEQL",	#not equal to
								"IN",	#is in (var or value in array)
								"NIN",	#is not in (var or value in array)
]

const and_operators = [	"AND", 			#and
						"NAND" 			#not and
]

const or_operators = [	"OR",			#or
						"NOR",			#not or
						"XOR",			#exclusive or
						"XNOR"]			#not exclusive or

#endregion

const invalid_names = [
	"NOT",
	"AND",
	"OR",
	"NAND",
	"NOR",
	"XOR",
	"XNOR",
	"EQL",
	"NEQL",
	"GRTR",
	"LESS",
	"GRTE",
	"LESE",
	"IN",
	"NIN",
	"INT",
	"FLT",
	"STR",
	"BOOL"
]
#delays are in terms of the base number of "cycles" per second
const instruction_delays = {
	"PRNT": 1.5,
	"GVAR": 1.0,
	"VAR": 1,
	"SET": 0.75,
	"GSET": 0.75,
	"ADD": 1,
	"CNT": 0.75,
	"SUB": 1,
	"MUL": 1,
	"DIV": 1,
	"JMP": 0.5,
	"CALL": 0.5,
	"RET": 0.5,
	"NOT": 0.25,
	"AND": 0.25,
	"OR": 0.25,
	"NAND": 0.25,
	"NOR": 0.25,
	"XOR": 0.25,
	"XNOR": 0.25,
	"EQL": 0.5,
	"NEQL": 0.5,
	"GRTR": 0.5,
	"LESS": 0.5,
	"GRTE": 0.5,
	"LESE": 0.5,
	"IN": 0.75,
	"NIN": 0.75,
	"INIT": 0.1
}
