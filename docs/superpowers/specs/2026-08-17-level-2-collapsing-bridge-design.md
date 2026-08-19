# Level 2 Collapsing Bridge Design

## Goal

Turn Level 2 into a dry underground chasm encounter with two routes:

- A short main bridge containing three independently collapsing sections.
- A longer side bridge that is always safe.

There is no water. Missing bridge sections expose a bottomless gap.

## Player Experience

Each unstable bridge section follows this sequence:

1. A player or enemy steps onto the section.
2. The section shakes and flashes for 3 seconds.
3. The section disappears and its solid collision is disabled.
4. Its gap detector becomes active.
5. The gap remains open for 5 seconds.
6. The bridge section reappears, its collision returns, and it can be triggered again.

The three unstable sections operate independently. Triggering one section does not start or collapse the others.

## Falling Behavior

### Player

When a player enters an active gap:

- Call `take_damage(1)` on the player.
- Move the player to the closest safe respawn marker.
- Prevent the same fall from applying damage repeatedly during that respawn.
- If the damage reduces health to zero, the Player script's existing death behavior remains responsible for game over.

The bridge system does not replace or rewrite the Player health system.

### Enemy

When an enemy enters an active gap:

- Call `queue_free()` on the enemy.
- Do not respawn that enemy.
- Removing a `level1_enemy` through a gap must still count as defeating it because completion is based on whether the group is empty.

## Scene Structure

```text
Level2BridgeSystem (Node2D)
├── SafeBridge (TileMapLayer)
├── UnstableSection1 (Area2D, collapsing_bridge_section.gd)
│   ├── BridgeTile (TileMapLayer)
│   ├── TriggerShape (CollisionPolygon2D)
│   └── GapArea (Area2D)
│       └── GapShape (CollisionPolygon2D)
├── UnstableSection2 (Area2D, collapsing_bridge_section.gd)
├── UnstableSection3 (Area2D, collapsing_bridge_section.gd)
├── SafeRespawnLeft (Marker2D)
└── SafeRespawnRight (Marker2D)
```

Each unstable section is a reusable scene so its timing and behavior stay isolated from the other sections.

## Section States

Each section has four states:

- `READY`: visible, solid, and waiting for a body.
- `WARNING`: visible, solid, shaking/flashing, and counting down for 3 seconds.
- `COLLAPSED`: hidden, not solid, and the gap detector is active for 5 seconds.
- `REBUILDING`: restores visuals and collision, disables the gap detector, then returns to `READY`.

Repeated body-entry signals are ignored unless the section is in `READY`.

## Collision Rules

- Bridge tile collision blocks movement while the section is `READY` or `WARNING`.
- Bridge tile collision is disabled while `COLLAPSED`.
- The gap detector monitors bodies only while `COLLAPSED`.
- The Player is identified through the `player` group.
- Enemies are identified through the `enemy` or `level1_enemy` group.
- The safe bridge never changes its collision.

## Respawn Selection

The bridge section receives references to `SafeRespawnLeft` and `SafeRespawnRight`. On a player fall, it compares the player's position with both markers and uses the closest one. This prevents the player from respawning on a missing bridge section.

## Visual Design

- The main bridge is the shortest route across the dry chasm.
- Three unstable sections are visually cracked or damaged.
- The safe side bridge is longer and visually intact.
- Warning feedback combines a small shake with a warm red flash.
- The collapsed state shows empty space only, with no water.
- Rebuilding restores the section immediately after the 5-second gap period; it does not damage bodies.

## Files

Planned additions:

- `collapsing_bridge_section.gd`
- `CollapsingBridgeSection.tscn`
- Automated tests for timing, independent sections, player damage/respawn, enemy removal, and rebuilding.

Planned scene changes:

- Add `Level2BridgeSystem` and its children to `Dungeon.tscn`.
- Rework the Level 2 floor into solid islands, a dry gap, a dangerous main bridge, and a safe side bridge.

Existing Player and Enemy health/death scripts remain unchanged unless testing reveals an integration defect.

## Verification

Automated checks will cover:

- A section starts in `READY`.
- Entering starts one warning only.
- The section remains solid during the 3-second warning.
- It collapses after 3 seconds.
- Player fall calls `take_damage(1)` once and uses a safe marker.
- Enemy fall calls `queue_free()`.
- A collapsed section rebuilds after 5 seconds.
- One section does not change another section's state.
- The safe bridge never collapses.

Manual Godot verification will confirm bridge placement, warning visibility, open combat routes, collision alignment, and respawn-marker positions.
