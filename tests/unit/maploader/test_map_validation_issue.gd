extends GdUnitTestSuite


func test_error_issue_format_and_severity() -> void:
	var issue := MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"id_missing", "Map ID is missing.")

	assert_bool(issue.is_error()).is_true()
	assert_str(issue.format_string()).is_equal("[ERROR] id_missing: Map ID is missing.")


func test_warning_issue_is_not_an_error() -> void:
	var issue := MapValidationIssue.new(MapValidationIssue.Severity.WARNING, &"thumbnail_missing", "Map thumbnail is missing.")

	assert_bool(issue.is_error()).is_false()
	assert_str(issue.format_string()).is_equal("[WARNING] thumbnail_missing: Map thumbnail is missing.")


func test_has_errors_ignores_warnings() -> void:
	var issues: Array[MapValidationIssue] = []
	assert_bool(MapValidationIssue.has_errors(issues)).is_false()

	issues.append(MapValidationIssue.new(MapValidationIssue.Severity.WARNING, &"warn", "Warning."))
	assert_bool(MapValidationIssue.has_errors(issues)).is_false()

	issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"err", "Error."))
	assert_bool(MapValidationIssue.has_errors(issues)).is_true()


func test_format_all_preserves_order() -> void:
	var issues: Array[MapValidationIssue] = [
		MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"first", "First."),
		MapValidationIssue.new(MapValidationIssue.Severity.WARNING, &"second", "Second."),
	]

	assert_array(MapValidationIssue.format_all(issues)).is_equal([
		"[ERROR] first: First.",
		"[WARNING] second: Second.",
	])
	assert_array(MapValidationIssue.format_all([] as Array[MapValidationIssue])).is_empty()
