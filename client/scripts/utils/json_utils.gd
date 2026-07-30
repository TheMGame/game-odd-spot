class_name JsonUtils
extends RefCounted


## Parses external or persisted JSON without emitting an engine error.
##
## JSON.parse_string() logs an error for empty or malformed input. Empty files
## can legitimately remain in user:// when a Mini Game write is interrupted,
## and HTTP/JavaScript bridges may temporarily return an empty value.
static func parse_string(text: String) -> Variant:
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return null
	var parser := JSON.new()
	if parser.parse(normalized) != OK:
		return null
	return parser.get_data()
