# Multiplayer

**Status:** Active. MVP session loop design accepted in
[#63](https://github.com/simonkuhlo/unrelated-vibe-game/issues/63) on
2026-11-20. This replaces the former placeholder;
[`docs/future/ideas/multiplayer-session-system.md`](future/ideas/multiplayer-session-system.md)
is decision input only, not a specification.

## Scope

The MVP delivers one multiplayer session loop:

- Host and join an ENet session from the running game.
- A `Preparation` lobby where the host selects a map and a gamemode independently.
- Peer prep-state synchronization while the lobby is open.
- An atomic `Loading in` step that locks the selection, loads the map and gamemode together, and rolls back on failure.
- One authority-owned pawn per peer, which its owner can move around the loaded map while other peers see replicated movement.
- A minimal lobby and HUD driven only by session signals and endpoints.
- Game end or host force returns the session through `Loading out` to `Preparation`.

Out of scope: client-side prediction, reconciliation, lag compensation, dedicated
servers, persistent accounts, lobby chat, character selection, full UI polish,
map config/setup (#10), async loading (#36), content hashing (#16), map packs
(#17), and any change to the v1 `MapManifest` / `MapDB` data model.

The host is the authoritative server. There are no autoloads and no scene
transitions; `game/main.gd` remains the explicit composition root and owns the
session node at runtime (A32 from [maploader.md](maploader.md)). Generic contracts
live in `system/`, game-specific composition in `game/`, presentation in `ui/`.

## Session states and transitions (M1, M5, M14)

There are exactly four states: `Preparation`, `Loading in`, `Ingame`, and
`Loading out`.

| From | To | Trigger | Actor | Guards and effects |
|---|---|---|---|---|
| — | `Preparation` | session created | host | Initial state. Map/gamemode unselected or set to defaults; no map or gamemode loaded; no pawns. |
| `Preparation` | `Loading in` | `start()` | host only | Selection IDs valid. Selection is locked and cannot change again until back in `Preparation`. |
| `Loading in` | `Ingame` | atomic load succeeded **and** readiness resolved | host | Gamemode started, pawns spawned, late joiners notified. |
| `Loading in` | `Preparation` | atomic load failed or host cancels | host | Partial load rolled back; error surfaced; selection unlocked. |
| `Ingame` | `Loading out` | gamemode emits `game_over`, or host calls `force_return_to_prep()` | gamemode or host | Gamemode stopped, pawns despawned, selected map/gamemode still locked. |
| `Loading out` | `Preparation` | unload complete | host | Map and gamemode unloaded; selection retained and editable again. |

Any other transition is rejected and logged. State invariants:

| State | Selection | Map / gamemode | Pawns | Client prep updates |
|---|---|---|---|---|
| `Preparation` | Mutable by host | Not loaded | None | Allowed |
| `Loading in` | Locked | Loading | None | Only `ready` flag |
| `Ingame` | Locked | Loaded and started | One per active peer | Ignored |
| `Loading out` | Locked | Unloading | None | Ignored |

## Host-only actions (M2)

Only the host may:

- select or change the map and gamemode;
- call `start()` to lock the selection and enter `Loading in`;
- force the readiness wait to end early;
- call `force_return_to_prep()` from `Ingame`;
- accept or reject a join according to the late-join rules below.

Clients may update only their own prep-state record and report readiness. The
host validates that the sender's peer ID matches the record being updated.

## Prep-phase peer state and acknowledgement (M3)

The host publishes a snapshot whenever the phase, selection, or peer state
changes, and once when a client joins:

```text
prep_snapshot {
    revision: int,          # increments on every host snapshot
    phase: StringName,      # one of the four states
    map_id: StringName,     # empty until selected
    gamemode_id: StringName,# empty until selected
    peers: [
        { peer_id: int, display_name: String, ready: bool, ack_revision: int }
    ]
}
```

A client applies a snapshot, then acknowledges it:

```text
prep_ack { peer_id: int, revision: int }
```

The host records `ack_revision` per peer and includes it in the next snapshot.
A client updates its own record with:

```text
prep_update {
    peer_id: int,
    display_name: String,   # trimmed, max 24 characters
    ready: bool,
    request_id: int
}
```

The host ignores updates where `peer_id` is not the sender, applies valid
updates, increments `revision`, and broadcasts a new snapshot. During
`Loading in`, only the `ready` field is accepted; during `Ingame` and
`Loading out`, prep updates are ignored.

## Network implementation (M4)

Use Godot's high-level multiplayer API:

- `ENetMultiplayerPeer` for host/join.
- `MultiplayerAPI` and `@rpc` for prep snapshots, acknowledgements, readiness,
  and session commands.
- `MultiplayerSpawner` for pawn spawn/despawn replication.
- `MultiplayerSynchronizer` for authority-owned pawn transforms.

No custom transport or hand-rolled spawn/sync protocol in the MVP.

## Atomic load sequence (M6, M7)

1. The host validates `map_id` against `MapDB` and `gamemode_id` against the
   gamemode registry.
2. The host sets `phase = Loading in`, clears the readiness set, and broadcasts a
   snapshot with the locked selection.
3. The host loads the map through the existing `MapLoader.load_map(map_id)` into
   `World/MapHost`. The loader and `MapManifest` data model are unchanged.
4. The host instantiates the gamemode scene from the registry under a runtime
   gamemode host and calls `configure()` with the active peer IDs and the spawn
   points collected from the loaded map.
5. If either step 3 or 4 fails, the host frees the gamemode, calls
   `MapLoader.unload()`, clears derived state, broadcasts the error, and returns
   to `Preparation`. Clients never observe a half-loaded game.
6. If both succeed, the host broadcasts `load_ready`. Clients load their local
   copy of the locked map and report `ready = true`.
7. The host enters `Ingame` when every active connected peer has reported ready
   or the bounded wait has elapsed. The default timeout is **10 seconds**; the
   host may force the transition early. Then the host calls gamemode `start()`,
   spawns the pawns, and broadcasts the full `Ingame` snapshot.

Clients never change scenes. Their local map is loaded into their own
`World/MapHost`, owned by their own `Main` instance.

## Gamemode module contract (M8)

Gamemodes are scene-based modules from the start:

- `system/gamemode/` holds the abstract `Gamemode` node script and a generic
  `GamemodeContext` value object.
- Each concrete module lives in `game/gamemodes/<id>/` and is a `PackedScene`
  whose root is a `Node` with a script extending `Gamemode`.
- A game-level registry maps `gamemode_id` to `PackedScene`. IDs use the same
  `snake_case` rule as map IDs: `^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$`.

Contract:

```gdscript
class_name Gamemode
extends Node

signal game_over(reason: StringName)

func configure(context: GamemodeContext) -> void: pass
func start() -> void: pass
func stop() -> void: pass
func on_peer_joined(peer_id: int) -> void: pass
```

`GamemodeContext` carries active peer IDs, spawn points as `Array[Node3D]`, and
callables for host endpoints such as requesting a return to `Preparation`. It
does not reference `game/` or `ui/` types, keeping `system/gamemode/` portable.

`game_over` is emitted by the module; the host reacts by entering `Loading out`.
The host may also force that transition without waiting for the module.

## Entity ownership and spawn rules (M9, M10)

- `system/entity/` holds generic ownership/identity contracts. The playable pawn
  is a game-level scene in `game/`.
- The host spawns exactly one pawn per active peer with `MultiplayerSpawner`
  under a runtime entity host in `World`.
- Spawn points are the existing `PlayerSpawnPoint` markers, queried through
  `PlayerSpawnFilter` and passed to the gamemode as an ordered `Array[Node3D]`.
  Peer index is assigned modulo the number of markers. If a loaded map has no
  `PlayerSpawnPoint` markers, atomic load fails with a spawn-configuration error
  and the session returns to `Preparation`.
- Spawn authority is the peer ID. The host is a peer and controls its own pawn
  through the same path.
- Only the owning peer applies local input, via an injectable input source so
  authority gating can be tested headlessly. Transform replication flows from
  the authority through `MultiplayerSynchronizer`.
- The local camera follows the owning peer's pawn only.
- No client-side prediction, reconciliation, or lag compensation.

## Late-join parity (M11)

The host accepts joins in every state and sends the appropriate snapshot:

| Phase on join | Behavior |
|---|---|
| `Preparation` | Send the full lobby snapshot; the peer can edit its own prep state and participates in the normal readiness wait. |
| `Loading in` | Send the locked selection snapshot. The peer loads its local map and reports ready. It joins the current readiness set; if the deadline already elapsed and `Ingame` started, its pawn is spawned when its local load completes. |
| `Ingame` | Send the full snapshot (phase, locked selection, peers, active pawns and transforms). The peer loads locally; the host then spawns its pawn via `MultiplayerSpawner` and calls gamemode `on_peer_joined(peer_id)`. The peer is non-authoritative until that spawn completes. |
| `Loading out` | Send a snapshot and hold the peer until `Preparation`. No map/gamemode load and no pawn. |

The host remains the authority throughout. A late join never changes the locked
selection or loads a different map/gamemode from the active session.

## UI boundary (M12)

`ui/` contains the lobby prep screen and minimal HUD. It reads state from
session signals/properties and calls session endpoints only. It must not call
`MapLoader`, the gamemode registry, or entity spawn endpoints directly. No UI
autoloads and no scene transitions; `Main` wires the UI to the session.

## Testing and verification (M13)

- Unit: `tests/unit/session/` for transitions, host-only guards, prep snapshot
  validation, and readiness rules; `tests/unit/gamemode/` for lifecycle and
  registry contracts; `tests/unit/entity/` for authority assignment and local
  input gating.
- Integration: `tests/integration/multiplayer/` with two in-process host/client
  peers covering lobby sync, locked selection, atomic load, spawn, and
  replicated movement.
- Content: `tests/content/gamemodes/` validates registry entries and scene roots.
- Manual: `pwsh ./scripts/run-multiplayer.ps1 -Instances 2`; host selects a map
  and gamemode, client joins, both reach `Ingame`, each moves its own pawn, and
  game end returns both to `Preparation`. Record exact steps, expected results,
  and observed results on the final integration PR.
- Gate: `pwsh ./scripts/verify.ps1` before every PR.

Headless gdUnit4 cannot deliver `InputEvent`s, so movement tests use the
injectable input source rather than simulated input.

## Decision record

All decisions below are accepted in
[#63](https://github.com/simonkuhlo/unrelated-vibe-game/issues/63).

| # | Decision |
|---|---|
| M1 | The session has exactly four states — `Preparation`, `Loading in`, `Ingame`, `Loading out` — and the transition table above is normative. |
| M2 | The host is the authoritative server; map/gamemode selection, start, readiness force, and force-return are host-only actions. |
| M3 | Prep sync uses a revisioned host snapshot, per-peer `prep_ack`, and validated `prep_update` messages carrying peer ID, display name, ready flag, and request ID. |
| M4 | Networking uses the high-level Godot API: `ENetMultiplayerPeer`, `@rpc`, `MultiplayerSpawner`, and `MultiplayerSynchronizer`. |
| M5 | Map and gamemode are selected independently, locked when entering `Loading in`, and the selection persists when returning to `Preparation`. |
| M6 | Loading is atomic: commit only when map and gamemode both load; otherwise unload partial state and return to `Preparation`. |
| M7 | Readiness resolves when all active peers report ready or a 10-second deadline elapses; the host may force it early. |
| M8 | Gamemodes are `Node`-rooted scenes with a lifecycle script extending `system/gamemode/Gamemode`, selected by a game-level id → `PackedScene` registry using map-style `snake_case` IDs. |
| M9 | Spawn points come from `PlayerSpawnPoint` markers via `PlayerSpawnFilter`; peer index wraps modulo marker count, and a map with no spawn markers fails the atomic load. |
| M10 | The host spawns one authority-owned pawn per peer; only the owner applies input, transforms are replicated, no prediction/reconciliation, and camera follows the local pawn. |
| M11 | Late joins are accepted in all four states with snapshot, hold, and spawn rules per phase as tabulated above. |
| M12 | UI is signal/endpoint driven; no autoloads or scene transitions, and `game/main.gd` remains the composition root (A32). |
| M13 | Tests cover session transitions/guards, gamemode lifecycle, authority gating, and two-peer integration; manual two-instance verification is recorded on the integration PR. |
| M14 | Game end is a gamemode `game_over` signal or host force, followed by `Loading out`, full unload, and return to `Preparation`. |
