extends RefCounted

## HMAC-SHA256 join-token verification.
## Token format produced by server/matchmaker:  hex(payload) + "." + hex(hmac)
## payload is JSON: {"sub":"player-id","region":"me","exp":<unix-seconds>}

static func verify(token: String, secret: String) -> Dictionary:
	if secret.is_empty() or token.is_empty():
		return {}
	var parts := token.split(".")
	if parts.size() != 2:
		return {}
	var payload := parts[0].hex_decode()
	var signature := parts[1].hex_decode()
	if payload.is_empty() or signature.is_empty():
		return {}

	var expected := _hmac_sha256(secret.to_utf8_buffer(), payload)
	if not _constant_time_equal(signature, expected):
		return {}

	var parsed = JSON.parse_string(payload.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	if int(data.get("exp", 0)) <= int(Time.get_unix_time_from_system()):
		return {}
	return data

static func _hmac_sha256(key: PackedByteArray, msg: PackedByteArray) -> PackedByteArray:
	var k := key
	if k.size() > 64:
		k = _sha256(k)
	k.resize(64)

	var ipad := PackedByteArray()
	var opad := PackedByteArray()
	ipad.resize(64)
	opad.resize(64)
	for i in 64:
		ipad[i] = k[i] ^ 0x36
		opad[i] = k[i] ^ 0x5c

	var inner_input := ipad.duplicate()
	inner_input.append_array(msg)
	var inner := _sha256(inner_input)
	var outer := opad.duplicate()
	outer.append_array(inner)
	return _sha256(outer)

static func _sha256(data: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish()

static func _constant_time_equal(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size():
		return false
	var diff := 0
	for i in a.size():
		diff |= a[i] ^ b[i]
	return diff == 0
