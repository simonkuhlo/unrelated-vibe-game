@tool
class_name PlayerSpawnFilter
extends MapMarkerFilter

## Matches `PlayerSpawnPoint` markers for one player index.

@export var player_index: int = 0


func matches(marker: MapMarker) -> bool:
	if not (marker is PlayerSpawnPoint):
		return false
	return (marker as PlayerSpawnPoint).player_index == player_index
