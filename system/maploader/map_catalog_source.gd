class_name MapCatalogSource
extends RefCounted
## Describes one catalog the repository should load.
##
## Source kind, not catalog order, defines precedence.

enum Kind { BUILTIN, INSTALLED }

var path: String
var kind: Kind


func _init(p_path: String, p_kind: Kind) -> void:
	path = p_path
	kind = p_kind
