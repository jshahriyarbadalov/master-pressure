extends "res://tests/test_case.gd"


func test_runner_works() -> bool:
	check_eq(1 + 1, 2, "арифметика")
	return ok()
