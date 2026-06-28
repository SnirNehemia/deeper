# ELEMENTAL_SYSTEM.md — Elemental Mechanics & Station Overrides

## 1. Core Philosophy & Flow
The Elemental System introduces interactive minerals harvested directly from authored map layers. It serves as a tool for mid-run tactical adaptation, offering a high payoff for strategic inventory management and physical co-op communication.

### Mechanical Rules
* **Physical Logistics:** Extracted ores enter the submarine as physical objects through the keel hatch. They can slide during sub tilting and can be grabbed, carried over headers, or stacked in storage cells.
* **Infinite Overrides:** Dropping an ore prop onto a station mutates its state variable indefinitely. The transformation remains permanent until a different element is dropped onto that station to overwrite it.
* **Dynamic Variation:** The properties of standard elements are fixed, but the ultra-rare **Purple Gem** shifts its behavior every run, introducing unexpected tactical modifiers.

---

## 2. The Elemental Matrix (Weapon Systems)

| Element | Direct Impact Behavior | Typal Synergies & Counters | Visual Identifier |
| :--- | :--- | :--- | :--- |
| **Yellow Shock** | **Stun:** Temporarily paralyzes enemy movement and resets aggression timers. | **Heals electrical-type fauna.** Do not shoot blindly. | Yellow spark trail / Projectile color |
| **Light Grey** | **Kinetic Crush:** High raw damage with massive physics knockback. | **Shatters hardened objects** (e.g., Lava Glass) and breaks enemy energy shields instantly. | Stone jagged casing / Grey trail |
| **Cryo Light Blue** | **Frost Nova:** Freezes enemies in an area-of-effect radius around the point of impact. | **Strong against Pyro.** Frozen targets take massive extra damage from Light Grey rounds. Ineffective against Cryo. | Soft blue glowing ice mist |
| **Red Lava** | **Magma Spitters:** Projectiles stick to targets, applying a damage-over-time (burn) effect. | **Super effective against Cryo fauna.** Ineffective against Pyro fauna (will not ignite). | Bright crimson drip / Fire particles |
| **Purple Gem** | **Unstable Singularity:** Behavior is randomized per run session (see Section 4). | **Rarest Tier.** Breaks normal weapon properties to completely reshape co-op roles. | Shifting magenta/dark purple plasma |

---

## 3. Future Station Hooks (Cross-Room Extensibility)

When elements are loaded into rooms other than Turrets, their effects scale to support the team’s overall operation:

### Engine Room
* **Yellow Shock:** *Lightning Spark:* Increases acceleration and maximum sub velocity, but increases fuel drain.
* **Light Grey:** *Heavy Mass Dampener:* Drastically reduces the severity of sub tilting during high-speed movement or rams.
* **Cryo Light Blue:** *Overclock Cooling:* Fully eliminates engine overheat rates or extinguishes internal fire hazards instantly.
* **Red Lava:** *Thermal Thrust:* Leaves a fiery trail behind the keel that damages pursuing chaser enemies.
* **Purple Gem:** *Void Warp:* (Varies by selected run type, e.g., Gravitational pulse shielding or passive blink/dash frames).

### Shield / Hull Station
* **Yellow Shock:** *Tesla Shell:* Shockwaves discharge outwards across the exterior hull whenever a predator bites the sub, stunning them.
* **Light Grey:** *Plated Bulwark:* Reinforces hull thresholds, cutting water intake speed from terrain impacts by 50%.
* **Cryo Light Blue:** *Glacial Coating:* Creates a freezing shield that turns incoming projectile attacks or small parasites to ice.
* **Red Lava:** *Reactive Thermals:* Evaporates water directly at the breach source, slowing down flooding rates in that room.

---

## 4. Unstable Purple Wavelengths (The Roguelite Modifier)

At the launch of every run session, the game engine rolls a random integer `(1 to 3)` to decide the active properties of all Purple Gems encountered in that specific dive.

```
gdscript
# Run Initialization Code (Core Loop)
enum PurpleWavelength { DEVASTATOR, ECHO_RING, PRISMATIC }
var active_purple_variant: PurpleWavelength

func _ready_run():
    # Randomly assign one of the 3 variants for this session
    active_purple_variant = [PurpleWavelength.DEVASTATOR, PurpleWavelength.ECHO_RING, PurpleWavelength.PRISMATIC].pick_random()
    Logger.log_system("Active Purple Wavelength for this run: " + str(active_purple_variant))
```
### Variant 1: The Gravitational Devastator
Weapon Effect: Projectiles create a miniature imploding singularity at the point of impact. It dynamically pulls all nearby enemies, breakable chunks, and debris into a tight cluster for 3 seconds before detonating in a massive 360-degree kinetic shrapnel burst.

Co-op Action: The Gunner functions as a crowd controller, clustering a whole pack of fast-chasing parasites together so a secondary gunner can finish them all off with a single heavy torpedo blast.

### Variant 2: The Echo Ring (Sub-Harmonic Resonator)
Weapon Effect: Projectiles deal minimal direct damage but mark targets with a vibrating purple resonant aura. Every time a player sits at the Sonar Station and fires an active sonar ping, the pulse triggers an explosion on every marked enemy, tearing through heavy armor and ignoring shields.

Co-op Action: Creates a direct tandem relationship between Gunner and Radar Operator: "I've tagged the alpha shark and his entourage, fire the sonar sweep now!"

### Variant 3: The Prismatic Refractor (Chaining Catalyst)
Weapon Effect: Projectiles blanket targets in a crystalline field. If any secondary weapon room fires an elementally infused round (Red Lava, Yellow Shock, Blue Cryo) into this prismatic field, the crystal prisms absorb, amplify, and chain that element across all adjacent targets.

Co-op Action: True sub-build execution. The team synchronizes distinct elements across different turrets to cause cross-room cascade reactions (e.g., matching a Purple gun with a Red Lava gun to ignite entire cave systems).

## 5. Technical Implementation Blueprint
To ensure clean state preservation without adding complex inventories to individual rooms, each station manages an element property string that alters the instantiation properties of the _fire() method:

GDScript
# Inside weapon_room.gd / bullet_station.gd
var loaded_element: String = "NONE"

func load_element_modifier(element_type: String) -> void:
    loaded_element = element_type.to_upper()
    _apply_station_visual_override()

func _fire() -> void:
    var projectile = projectile_scene.instantiate()
    
    # Check permanent state variable
    match loaded_element:
        "YELLOW":
            projectile.setup_modifier("shock", Color.YELLOW)
        "GREY":
            projectile.setup_modifier("kinetic", Color.DARK_GRAY)
        "BLUE":
            projectile.setup_modifier("freeze", Color.CYAN)
        "RED":
            projectile.setup_modifier("burn", Color.RED)
        "PURPLE":
            # Direct check to the core loop runtime variable
            var current_run_variant = RunManager.get_active_purple_variant()
            projectile.setup_modifier("purple_" + current_run_variant, Color.MEDIUM_PURPLE)
            
    get_tree().current_scene.add_child(projectile)