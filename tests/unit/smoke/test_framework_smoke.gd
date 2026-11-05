extends GdUnitTestSuite
## Spike-only smoke suite used to verify gdUnit4 6.2.3 on Godot 4.7.2.
## Kept as the seed example for the foundation branch.


func test_assertion_api_works() -> void:
	assert_that(1 + 1).is_equal(2)
	assert_str("godot").is_equal("godot")


func test_parameters(value: int, expected: int, _test_parameters := [
	[0, 0],
	[1, 1],
]) -> void:
	assert_int(value).is_equal(expected)


func test_async_signal_wait() -> void:
	var timer := auto_free(Timer.new()) as Timer
	timer.one_shot = true
	timer.wait_time = 0.02
	add_child(timer)
	timer.start()
	await await_signal_on(timer, "timeout", [], 1000)
	assert_that(timer.is_stopped()).is_true()
