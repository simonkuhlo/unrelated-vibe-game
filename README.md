# unrelated vibe game

<!-- Short description to be filled in -->

## Tech Stack

- [Godot Engine 4.7.2](https://godotengine.org/) - Forward Plus
- [Jolt Physics](https://github.com/godot-jolt/godot-jolt)
- [gdUnit4 6.2.3](https://github.com/godot-gdunit-labs/gdUnit4) - testing
- Multiplayer (planned)

## Getting Started

1. Install [Godot 4.7.2](https://godotengine.org/download) (pinned in `.godot-version`)
2. Clone this repository
3. Open the project by opening `project.godot` in the Godot editor
4. Main scene is `res://game/main.tscn`
5. <!-- Run instructions to be added -->

## Project Structure

| Directory | Purpose |
|---|---|
| `assets/` | All asset files (3D objects, textures, icons, audio, etc.) |
| `system/` | Reusable, game-agnostic core systems (to be usable outside this project). Examples: item system, attribute system, entities, hit/hurtboxes, etc. |
| `game/` | Game-specific logic that builds on top of systems in `system/`. |
| `ui/` | UI layer (menus, HUD). UI should stay decoupled from game logic - visualize state from elsewhere and call clean endpoints/signals provided by game/systems. |
| `tests/` | Automated tests and fixtures (excluded from exports) |
| `addons/` | Vendored dependencies (currently gdUnit4; excluded from exports) |
| `docs/` | Project documentation |

See [docs/architecture.md](docs/architecture.md) for more details.

## Testing

```powershell
# Pre-PR gate: static checks + all tests
.\scripts\verify.ps1

# While iterating
.\scripts\test.ps1 -Tier unit
```

See [docs/testing.md](docs/testing.md) for tiers, policy, and determinism rules.

## Development Workflow

This project uses an issue-driven workflow with feature branches and pull requests.

- [AGENTS.md](AGENTS.md) - Agent workflow rules and conventions
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- Issues are tracked on GitHub

## Notes

<!-- Additional notes to be filled in -->

## License

<!-- To be handled manually later -->
