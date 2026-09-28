class_name CliArgs
extends RefCounted
## Parses user command-line args (everything after `--`) into a Dictionary.
## `--flag` -> {"flag": true}; `--key=value` -> {"key": "value"}. Non-`--` tokens are ignored.


static func parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for raw in args:
		if not raw.begins_with("--") or raw.length() <= 2:
			continue
		var body := raw.substr(2)
		var eq := body.find("=")
		if eq == -1:
			out[body] = true
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out
