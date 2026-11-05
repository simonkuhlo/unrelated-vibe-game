class_name MapCatalog
extends Resource
## A persisted list of map manifests.
##
## The catalog is an index/cache, not the authority. The repository validates
## every entry against the filesystem when it loads the catalog.

const CURRENT_FORMAT_VERSION := 1

@export var format_version: int = CURRENT_FORMAT_VERSION
@export var entries: Array[MapManifest] = []
