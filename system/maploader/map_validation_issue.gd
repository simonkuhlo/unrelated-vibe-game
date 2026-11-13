@tool
class_name MapValidationIssue
extends RefCounted

## One structured problem reported by a maploader component.
##
## Components return arrays of these from `validate()`. The static helpers keep
## editor-facing formatting and logging consistent across components: tool
## buttons and editor warnings call them so validation feedback never diverges.

enum Severity { ERROR, WARNING }

var severity: Severity
var code: StringName
var message: String
var context: Object


func _init(p_severity: Severity, p_code: StringName, p_message: String, p_context: Object = null) -> void:
	severity = p_severity
	code = p_code
	message = p_message
	context = p_context


func is_error() -> bool:
	return severity == Severity.ERROR


func format_string() -> String:
	return "[%s] %s: %s" % [Severity.keys()[severity], code, message]


static func has_errors(issues: Array[MapValidationIssue]) -> bool:
	for issue in issues:
		if issue.is_error():
			return true
	return false


static func format_all(issues: Array[MapValidationIssue]) -> PackedStringArray:
	var lines := PackedStringArray()
	for issue in issues:
		lines.append(issue.format_string())
	return lines


## Reports validation results to the editor Output/Errors panel. Tool buttons
## ignore a callable's return value, so components call this from their
## `@export_tool_button` handler instead of returning issues into the void.
static func log_all(context: Object, issues: Array[MapValidationIssue]) -> void:
	var source := _describe_context(context)
	if issues.is_empty():
		print("[maploader] %s: validation passed." % source)
		return

	for issue in issues:
		var line := "[maploader] %s: %s" % [source, issue.format_string()]
		if issue.is_error():
			push_error(line)
		else:
			push_warning(line)


static func _describe_context(context: Object) -> String:
	if context == null:
		return "<unknown>"
	if context is Node and not (context as Node).name.is_empty():
		return str((context as Node).name)
	if context is Resource and not (context as Resource).resource_path.is_empty():
		return (context as Resource).resource_path
	return context.get_class()
