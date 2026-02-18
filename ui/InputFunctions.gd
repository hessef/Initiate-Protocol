extends Node

class_name Input_Functions

#import enums
const TerminalMode = UIEnum.terminal_mode
const FuncRes = GeneralEnum.function_result

##link the user input from the CLI to the target
func link_to_cli(terminal_ui: TerminalUI, target: Node, target_function: String) -> void:
	terminal_ui.line_submitted.connect(target.call(target_function))
