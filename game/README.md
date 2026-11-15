# game/

Holds game logic. Most of it will build on top of the systems created in `system/`. This is where game-specific rules, content integration, and gameplay flow live.

Current content: `main.gd`/`main.tscn` are the v1 bootstrap that owns the built-in map DB and loader, and `player_spawn_point.gd`/`player_spawn_filter.gd` are the game-level spawn marker types.
