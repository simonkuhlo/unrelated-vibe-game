# Getting Started

## Requirements
- Godot Engine 4.7 (see `project.godot` for exact version). Steam version found at `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`

## Setup
1. Clone the repository
2. Open `project.godot` with Godot 4.7 (built-in editor recommended)
3. <!-- Project-specific setup to be added -->

## Running

### Using Godot Editor
Open the project in the Godot editor and run the main scene.

### Using helper scripts (Windows/PowerShell)
From repo root:
```powershell
# Open in editor
.\scripts\run-godot.ps1 -Editor

# Run project
.\scripts\run-godot.ps1

# Launch multiple instances for local multiplayer testing
.\scripts\run-multiplayer.ps1 -Instances 2
```

Scripts look for the Steam Godot executable in the common location. If yours is in a different place, update the scripts or add Godot to PATH.

## Development
- Built-in Godot editor is fine for day-to-day work
- VSCode/Cursor with `geequlim.godot-tools` is recommended if using an external editor (see `.vscode/extensions.json`)
- See [../AGENTS.md](../AGENTS.md) for the issue-driven workflow and agent conventions
- See [../CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines
