# Getting Started

## Requirements

- **Linux** is the primary development environment. CI runs on `ubuntu-latest`.
- Godot Engine 4.7.2, pinned in `.godot-version`.
- PowerShell 7+ (`pwsh`) for the helper scripts.
- Git.

Windows is supported as a fallback. Windows PowerShell 5.1 works, but `pwsh` is
recommended so local commands match CI and the docs.

## Godot binary

The scripts resolve Godot from `-GodotBin`, `GODOT_BIN`, `GODOT`, common Linux
install locations, the Steam install location, or `godot` on `PATH`, in that
order.

Linux example:

```bash
export GODOT_BIN=/usr/local/bin/godot
```

Windows example:

```powershell
$env:GODOT_BIN = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
```

You can also pass `-GodotBin` to any script that launches Godot.

## Setup

1. Clone the repository.
2. Open `project.godot` with Godot 4.7.2.
3. Run the static check to confirm the project imports and boots:

   ```bash
   pwsh ./scripts/check.ps1
   ```

## Running

From the repo root:

```bash
# Open in the editor
pwsh ./scripts/run-godot.ps1 -Editor

# Run the project
pwsh ./scripts/run-godot.ps1

# Launch multiple instances for local multiplayer testing
pwsh ./scripts/run-multiplayer.ps1 -Instances 2
```

On Windows PowerShell, substitute `.\scripts\...`.

## Testing

The pre-PR gate imports the project, parses every first-party script, boots the
main scene, and runs the gdUnit4 suites:

```bash
pwsh ./scripts/verify.ps1
```

Faster loops:

```bash
pwsh ./scripts/check.ps1                     # static checks only
pwsh ./scripts/test.ps1 -Tier unit           # unit tests
pwsh ./scripts/test.ps1 -Tier integration    # scene/lifecycle tests
pwsh ./scripts/test.ps1 -Path tests/unit/smoke/test_framework_smoke.gd
```

Reports land in `reports/` and are gitignored. See
[testing.md](testing.md) for policy, tiers, and troubleshooting.

## Development

- Built-in Godot editor is fine for day-to-day work.
- VSCode/Cursor with `geequlim.godot-tools` is recommended if using an external
  editor (see `.vscode/extensions.json`).
- See [../AGENTS.md](../AGENTS.md) for the issue-driven workflow and agent
  conventions.
- Less-capable agents start at [agents/README.md](agents/README.md).
- Humans directing agents should read [agents/human-guide.md](agents/human-guide.md).
- See [../CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines.
- See [testing.md](testing.md) for the testing policy and commands.
