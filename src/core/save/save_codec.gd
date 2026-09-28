class_name SaveCodec
extends RefCounted
## Versioned, integrity-checked, atomic save files (DESIGN §6.12, DECISIONS D009).
##
## File = ZSTD-compressed store_var({magic, format, schema, sha256, payload}) where payload is
## var_to_bytes(<plain Dictionary>). Objects are never encoded or decoded.
## Writes go to <path>.tmp, are read back and verified, the previous file is rotated to <path>.bak,
## then the tmp file is renamed into place.

enum Status {
	OK, OPEN_FAILED, NOT_A_SAVE, UNSUPPORTED_FORMAT, HASH_MISMATCH, DECODE_FAILED, VERIFY_FAILED, RENAME_FAILED
}

const MAGIC := "WLSV"
## Bump only when the envelope layout changes (not for game-data schema changes).
const FORMAT := 1
const COMPRESSION := FileAccess.COMPRESSION_ZSTD


class Result:
	extends RefCounted
	var status: Status = Status.OK
	var schema: int = 0
	var data: Dictionary = {}
	var from_backup: bool = false

	func ok() -> bool:
		return status == Status.OK


static func write(path: String, schema: int, data: Dictionary) -> Status:
	var payload := var_to_bytes(data)
	var envelope := {
		"magic": MAGIC,
		"format": FORMAT,
		"schema": schema,
		"sha256": sha256_hex(payload),
		"payload": payload,
	}
	var tmp := path + ".tmp"
	var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, COMPRESSION)
	if f == null:
		Log.error("SaveCodec", "cannot open %s for writing (%s)" % [tmp, FileAccess.get_open_error()])
		return Status.OPEN_FAILED
	f.store_var(envelope)
	f.close()

	var check := read(tmp)
	if not check.ok():
		DirAccess.remove_absolute(tmp)
		Log.error("SaveCodec", "read-back verification failed for %s: %s" % [tmp, status_name(check.status)])
		return Status.VERIFY_FAILED

	var bak := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(path, bak)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		Log.error("SaveCodec", "rename %s -> %s failed (%s)" % [tmp, path, error_string(err)])
		return Status.RENAME_FAILED
	return Status.OK


## Reads and verifies one file. Never pushes engine errors for a merely missing/corrupt file.
static func read(path: String) -> Result:
	var r := Result.new()
	if not FileAccess.file_exists(path):
		r.status = Status.OPEN_FAILED
		return r
	if not _has_compressed_header(path):
		r.status = Status.NOT_A_SAVE
		return r
	var f := FileAccess.open_compressed(path, FileAccess.READ, COMPRESSION)
	if f == null:
		r.status = Status.OPEN_FAILED
		return r
	var envelope: Variant = f.get_var(false)
	f.close()
	if typeof(envelope) != TYPE_DICTIONARY or (envelope as Dictionary).get("magic") != MAGIC:
		r.status = Status.NOT_A_SAVE
		return r
	var env := envelope as Dictionary
	if env.get("format") != FORMAT:
		r.status = Status.UNSUPPORTED_FORMAT
		return r
	var payload: Variant = env.get("payload")
	if typeof(payload) != TYPE_PACKED_BYTE_ARRAY:
		r.status = Status.DECODE_FAILED
		return r
	if sha256_hex(payload as PackedByteArray) != env.get("sha256"):
		r.status = Status.HASH_MISMATCH
		return r
	var decoded: Variant = bytes_to_var(payload as PackedByteArray)
	if typeof(decoded) != TYPE_DICTIONARY:
		r.status = Status.DECODE_FAILED
		return r
	var schema: Variant = env.get("schema")
	if typeof(schema) != TYPE_INT:
		r.status = Status.DECODE_FAILED
		return r
	r.schema = schema as int
	r.data = decoded as Dictionary
	return r


## Reads <path>, falling back to <path>.bak if the primary is missing or damaged.
static func read_with_fallback(path: String) -> Result:
	var r := read(path)
	if r.ok():
		return r
	var b := read(path + ".bak")
	if b.ok():
		b.from_backup = true
		Log.warn("SaveCodec", "%s unreadable (%s); restored from backup" % [path, status_name(r.status)])
		return b
	return r


static func sha256_hex(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


static func status_name(s: Status) -> String:
	return Status.keys()[s]


## Godot's compressed files start with the ASCII magic "GCPF". Checking it first avoids engine
## errors when a random/corrupt file is handed to open_compressed.
static func _has_compressed_header(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 4:
		return false
	return f.get_buffer(4).get_string_from_ascii() == "GCPF"
