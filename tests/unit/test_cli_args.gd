extends GutTest


func test_flags_and_values() -> void:
	var a := CliArgs.parse(PackedStringArray(["--bench", "--preset=gfx_high", "--out=a=b", "loose", "--"]))
	assert_eq(a.get("bench"), true)
	assert_eq(a.get("preset"), "gfx_high")
	assert_eq(a.get("out"), "a=b", "only the first '=' splits")
	assert_false(a.has("loose"))
	assert_eq(a.size(), 3)


func test_empty() -> void:
	assert_eq(CliArgs.parse(PackedStringArray()), {})
