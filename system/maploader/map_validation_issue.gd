class_name MapValidationIssue
extends RefCounted

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

func format_string() -> String:
	return "[%s] %s: %s" % [Severity.keys()[severity], code, message]
