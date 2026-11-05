# Getting Started

## Requirements
- Godot Engine 4.7.2 (pinned in `.godot-version`). Steam version found at `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- PowerShell 5.1+ (Windows) or PowerShell 7+ (`pwsh`) for the scripts

## Setup
1. Clone the repository
2. Open `project.godot` with Godot 4.7.2 (built-in editor recommended)
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

Scripts look for the Steam Godot executable in the common location. If yours is in a different place, set `GODOT_BIN` or pass `-GodotBin` to the test scripts.

## Testing

The pre-PR gate imports the project, parses every first-party script, boots the
main scene, and runs the gdUnit4 suites:

```powershell
.\scripts\verify.ps1
```

Faster loops:

```powershell
.\scripts\check.ps1                     # static checks only
.\scripts\test.ps1 -Tier unit           # unit tests
.\scripts\test.ps1 -Tier integration    # scene/lifecycle tests
.\scripts\test.ps1 -Path tests/unit/smoke/test_framework_smoke.gd
```

Reports land in `reports/` and are gitignored. See
[testing.md](testing.md) for policy, tiers, and troubleshooting.

## Development
- Built-in Godot editor is fine for day-to-day work
- VSCode/Cursor with `geequlim.godot-tools` is recommended if using an external editor (see `.vscode/extensions.json`)
- See [../AGENTS.md](../AGENTS.md) for the issue-driven workflow and agent conventions
- See [../CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines
- See [testing.md](testing.md) for the testing policy and commands
