# Architecture

## Folder Responsibilities

### `assets/`
Holds all asset files: 3D objects, textures, icons, audio, etc. Keep raw assets organized here.

### `system/`
Holds code for base systems. The goal is to create reusable systems independent from this game that can be used elsewhere as well.

Examples of systems that may live here:
- Item system
- Attribute system
- Entities
- Hit/hurtboxes
- Other generic, reusable mechanics

These should be designed to be decoupled from game-specific rules where possible.

### `game/`
Holds game logic. Most of it will build on top of the systems created in `system/`. This is where game-specific rules, content integration, and gameplay flow live.

### `ui/`
Holds everything UI related. 

**Principles:**
- UI should not be entangled in game code - act as a clean layer on top
- UI visualizes logic defined elsewhere and provides control
- Game code should provide good signals to keep the UI dynamic and updated
- Game code should provide clean "endpoints" for changing things
- Keep UI decoupled so it can read state and call endpoints without reaching deep into game internals

More detailed UI patterns will be documented as they evolve.

## Design Goals

- **Reusability**: Systems in `system/` should be portable
- **Separation of concerns**: Clear boundaries between systems, game logic, and UI
- **Signal-driven UI**: UI updates reactively via signals from game/systems
- **Multiplayer-ready**: Architecture should leave room for multiplayer (see [multiplayer.md](multiplayer.md))
