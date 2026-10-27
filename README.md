# unrelated vibe game

<!-- Short description to be filled in -->

## Tech Stack

- [Godot Engine 4.7](https://godotengine.org/) - Forward Plus
- [Jolt Physics](https://github.com/godot-jolt/godot-jolt)
- Multiplayer (planned)

## Getting Started

1. Install [Godot 4.7](https://godotengine.org/download) (matching the version in `project.godot`)
2. Clone this repository
3. Open the project by opening `project.godot` in the Godot editor
4. <!-- Run instructions to be added -->

## Project Structure

| Directory | Purpose |
|---|---|
| `assets/` | All asset files (3D objects, textures, icons, audio, etc.) |
| `system/` | Reusable, game-agnostic core systems (to be usable outside this project). Examples: item system, attribute system, entities, hit/hurtboxes, etc. |
| `game/` | Game-specific logic that builds on top of systems in `system/`. |
| `ui/` | UI layer (menus, HUD). UI should stay decoupled from game logic - visualize state from elsewhere and call clean endpoints/signals provided by game/systems. |
| `docs/` | Project documentation |

See [docs/architecture.md](docs/architecture.md) for more details.

## Development Workflow

This project uses an issue-driven workflow with feature branches and pull requests.

- [AGENTS.md](AGENTS.md) - Agent workflow rules and conventions
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- Issues are tracked on GitHub

## Notes

<!-- Additional notes to be filled in -->

## License

<!-- To be handled manually later -->
