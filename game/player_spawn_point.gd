@tool
class_name PlayerSpawnPoint
extends MapMarker

## Game-level spawn marker. Spawn selection policy is out of scope; query these
## through the existing marker API, e.g.
## `map_scene.markers.get_markers(PlayerSpawnFilter.new())`.

@export var player_index: int = 0
