extends GutTest

const DIR := "user://test_save_codec"

var _path: String


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_path = DIR.path_join("slot.sav")
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))


func _sample() -> Dictionary:
	return {
		"flags": {"met_trader": true, "karma": -3, "note": "hello"},
		"pos": Vector3(1.5, 0, -2),
		"list": [1, 2.5, "x", PackedInt32Array([4, 5])],
	}


func test_round_trip() -> void:
	assert_eq(SaveCodec.write(_path, 7, _sample()), SaveCodec.Status.OK)
	var r := SaveCodec.read(_path)
	assert_true(r.ok(), SaveCodec.status_name(r.status))
	assert_eq(r.schema, 7)
	assert_eq(r.data, _sample())
	assert_false(FileAccess.file_exists(_path + ".tmp"), "tmp file cleaned up")


func test_file_is_compressed_envelope() -> void:
	SaveCodec.write(_path, 1, _sample())
	var f := FileAccess.open(_path, FileAccess.READ)
	assert_eq(f.get_buffer(4).get_string_from_ascii(), "GCPF", "ZSTD container header")


func test_second_write_rotates_backup() -> void:
	SaveCodec.write(_path, 1, {"v": 1})
	SaveCodec.write(_path, 1, {"v": 2})
	assert_eq(SaveCodec.read(_path).data, {"v": 2})
	assert_eq(SaveCodec.read(_path + ".bak").data, {"v": 1})


func test_missing_file() -> void:
	assert_eq(SaveCodec.read(DIR.path_join("nope.sav")).status, SaveCodec.Status.OPEN_FAILED)


func test_garbage_file_is_not_a_save() -> void:
	var f := FileAccess.open(_path, FileAccess.WRITE)
	f.store_string("definitely not a save file")
	f.close()
	assert_eq(SaveCodec.read(_path).status, SaveCodec.Status.NOT_A_SAVE)


func test_foreign_compressed_file_is_not_a_save() -> void:
	var f := FileAccess.open_compressed(_path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	f.store_var({"magic": "NOPE"})
	f.close()
	assert_eq(SaveCodec.read(_path).status, SaveCodec.Status.NOT_A_SAVE)


func test_tampered_payload_detected() -> void:
	var payload := var_to_bytes({"gold": 10})
	var f := FileAccess.open_compressed(_path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	(
		f
		. store_var(
			{
				"magic": SaveCodec.MAGIC,
				"format": SaveCodec.FORMAT,
				"schema": 1,
				"sha256": SaveCodec.sha256_hex(var_to_bytes({"gold": 99999})),
				"payload": payload,
			}
		)
	)
	f.close()
	assert_eq(SaveCodec.read(_path).status, SaveCodec.Status.HASH_MISMATCH)


func test_unknown_envelope_format_rejected() -> void:
	var payload := var_to_bytes({})
	var f := FileAccess.open_compressed(_path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	(
		f
		. store_var(
			{
				"magic": SaveCodec.MAGIC,
				"format": SaveCodec.FORMAT + 1,
				"schema": 1,
				"sha256": SaveCodec.sha256_hex(payload),
				"payload": payload,
			}
		)
	)
	f.close()
	assert_eq(SaveCodec.read(_path).status, SaveCodec.Status.UNSUPPORTED_FORMAT)


func test_objects_in_payload_are_not_instantiated() -> void:
	# A crafted save embedding an encoded Object must not decode into a live object.
	var node := Node.new()
	var payload := var_to_bytes_with_objects({"evil": node})
	node.free()
	var f := FileAccess.open_compressed(_path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	(
		f
		. store_var(
			{
				"magic": SaveCodec.MAGIC,
				"format": SaveCodec.FORMAT,
				"schema": 1,
				"sha256": SaveCodec.sha256_hex(payload),
				"payload": payload,
			}
		)
	)
	f.close()
	var r := SaveCodec.read(_path)
	assert_eq(r.status, SaveCodec.Status.DECODE_FAILED, "object payload refused")
	# The engine itself refuses to decode objects without allow_objects and logs why.
	assert_engine_error("p_allow_objects")
	assert_engine_error("err != OK")


func test_fallback_to_backup_when_primary_corrupt() -> void:
	SaveCodec.write(_path, 1, {"v": 1})
	SaveCodec.write(_path, 1, {"v": 2})
	var f := FileAccess.open(_path, FileAccess.WRITE)
	f.store_string("truncated")
	f.close()
	var r := SaveCodec.read_with_fallback(_path)
	assert_true(r.ok())
	assert_true(r.from_backup)
	assert_eq(r.data, {"v": 1})
	assert_push_warning("restored from backup")
