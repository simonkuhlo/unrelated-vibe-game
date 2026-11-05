extends GdUnitTestSuite
## Throwaway suite: proves the CI gate turns red on a real test failure.
## This file is removed before the branch is deleted.


func test_ci_gate_detects_failure() -> void:
	assert_bool(true).is_false()
