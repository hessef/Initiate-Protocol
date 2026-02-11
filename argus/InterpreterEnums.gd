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
					"EQL", "NEQL", "IN",								#equality/presence
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
	"ISIN",
	"NIN",
	"INT",
	"FLT",
	"STR",
	"BOOL"
]
