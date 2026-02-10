extends Node

class_name ArgusEnum

enum data_types{
	INT,
	FLT,
	STR,
	BOOL
	
}

#region OPERANDS
const operands = [	"LESS", "GRTR", "LESE", "GRTE",						#comparison
					"EQL", "NEQL", "IN", "NIN",	"EXST",					#equality/presence
					"NOT", "AND", "OR", "NAND", "NOR", "XOR", "XNOR"	#boolean
]

const comparison_operands = [	"LESS",	#less than
								"GRTR",	#greater than
								"LESE",	#less than or equal to
								"GRTE"	#greater than or equal to
]

const equality_operands = [	"EQL",		#equal to
							"NEQL",		#not equal to
							"IN",		#is in (var or value in array)
							"NIN",		#is not in (var or value in array)
							"EXST",		#exists (var or array)
							"NXST"		#does not exist (var or array)
]

const and_operands = [	"AND", 			#and
						"NAND" 			#not and
]

const or_operands = [	"OR",			#or
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
