# DEEPER — Game Design Document (v0.3)

*Title locked: DEEPER.*

---

## 1. High Concept

A couch co-op submarine roguelite for 1–4 players. The crew shares one modular submarine viewed in side cutaway. Players run between stations — helm, weapons, claw, engine, repairs — to survive increasingly hostile depths. Between runs, salvage is spent to bolt new sections onto the sub and dive deeper than before.

**Pitch in one line:** *Lovers in a Dangerous Spacetime's frantic station-hopping, inside Barotrauma's cutaway submarine, wrapped in a cute cartoon-meets-pixel-art style.*

---

## 2. Design Pillars

1. **Cooperation is the mechanic.** No station can be ignored. The sub demands more hands than the crew has — prioritization under pressure *is* the gameplay.
2. **The sub is the character.** Players don't level up; the submarine does. Every run visibly changes its silhouette.
3. **Depth = tension.** Deeper water means darker visuals, scarier fauna, higher pressure, better loot. The depth meter is the score, the difficulty dial, and the narrative.
4. **Readable chaos.** Cute, chunky, high-contrast art keeps 4-player chaos legible. If a playtester can't tell what's leaking, the art has failed.

---

## 3. Core Loop

**Moment-to-moment (seconds):** Spot a threat → call it out → run to the right station → operate it → react to the next problem.

**Run loop (20–40 min):** Launch from surface station → descend through depth zones → fight/avoid fauna, salvage wrecks, manage hull and air → push deeper or retreat → surface with salvage (or implode and keep a fraction).

**Meta loop (hours):** Spend salvage at the dry dock → unlock and attach new sub modules → new modules enable deeper zones → new zones drop better salvage.

---

## 4. Players & Controls

- **Players:** 1–4 local co-op. Solo mode works because stations have "set and leave" states (e.g., lock the helm to hold course while you run to repair).
- **Input sources (abstracted):** keyboard split, USB gamepads, and **phones as controllers** via WebSocket over LAN (virtual stick + 2 buttons + context button). All inputs map to the same `PlayerInput` interface.
- **Character controls:** move left/right, climb ladders, interact (enter/leave station), use (context action: repair, pick up, throw).
- **At a station:** the stick/keys control the station instead of the character (aim turret, steer sub, operate claw).

---

## 5. The Submarine

### 5.1 Structure
- Side-view cutaway. The sub is a **grid of room modules** (one uniform cell each, 5m wide × 3m tall) connected by hatches and ladders.
- Starting sub ("The Minnow"): 3 rooms — Helm, Engine, and one flex slot (default: a small turret).
- Modules attach at predefined hardpoints (top, bottom, bow, stern). The silhouette grows asymmetric and personal — your sub looks like *your* run history.

### 5.2 Module catalog (initial set)
| Module | Function | Crew interaction |
|---|---|---|
| Helm | Steering, ballast, sonar ping | 1 player steers; sonar reveals fog |
| Engine | Speed/power | Shovel fuel or balance a power minigame; overheats |
| Turret | Projectile weapon, limited arc | Aim + shoot; ammo crafted or scavenged |
| Claw arm | Grab salvage, pry wrecks, punch fauna | Aim, extend, grip — physics-driven |
| O2 scrubber | Air supply | Filter swaps; failure = slow suffocation timer |
| Repair bay | Crafts patch kits, ammo | Hold-to-craft; consumes scrap |
| Floodlight pod | Vision in deep zones | Aimable; some fauna attracted/repelled by light |
| Ballast tank | Faster vertical movement | Passive + manual purge for emergency ascent |
| Airlock/dive suit (later) | EVA salvage | One player exits — huge risk/reward |

### 5.3 Damage model (keep it simple, v1)
- Hull breaches spawn at impact points → water level rises in that room → flooded stations go offline → too much water = sinking weight + eventual implosion.
- **Terrain collisions damage the hull, scaling with impact speed** — gentle bumps are free, ramming rock at full speed breaches. Piloting carefully matters.
- Repairs: hold "use" with a patch kit at the breach. **MVP: repairs are free (no kits); patch kits become a resource when the repair bay module exists.** A patched room **auto-drains** in MVP; a dedicated pump station arrives later as a module. No Barotrauma-style wiring/pressure sim in v1 — water level per room is enough drama.
- **Crew vulnerability:** crew members can drown in flooded rooms (air timer while submerged) and respawn after a delay at the helm room. No revive mechanic in v1.
- **Interior movement:** run, jump, and ladders (jump + ladders; no jetpack float).
- Fires later, if ever. Water first.

---

## 6. Run Structure & Depth Zones

The ocean is an **open 2D space**, not a corridor. Runs begin at a **shore station** on the surface; the first act is horizontal — crossing the sunlit shallows above the **continental shelf**. The run's signature moment is reaching the **shelf edge**: the seafloor falls away beneath you, and descent begins. Deeper zones contain **explorable side caves** holding the best salvage. Zones (procedural-lite: handcrafted chunks, shuffled):

1. **The Shallows (shore → shelf, 0–50m):** tutorial-grade horizontal leg. Kelp, curious fish, easy wrecks, the harbor behind you.
2. **The Shelf Edge & Twilight Drop (50–600m):** the plunge. Ambushing fauna, currents, first minibosses, first cave mouths.
3. **Midnight Trench (600–1500m):** dark — floodlights matter. Pressure events, cave networks, anglerfish-style horrors (cute horrors).
4. **The Hadal Garden (1500m+):** weird, bioluminescent, run-capstone boss creatures.

- Each zone gates on a **hull pressure rating** — you physically cannot survive zone 3 without upgraded plating, which paces meta-progression naturally.
- **Death = implosion:** keep ~50% of salvage banked at the last checkpoint buoy. Generous, because couch co-op punishment should sting, not end the evening.
- **Retreat is a choice:** surfacing early keeps 100%. Push-your-luck is the emotional core of every run's final minutes.

---

## 7. Threats & Events

- **Fauna:** swarms (chip the hull), grapplers (latch on, must be clawed/shot off), chargers (telegraphed ram), boss-class leviathans per zone. **Aggression model: small fauna is territorial (attacks only if you enter its space — avoidable by careful piloting); large fauna hunts the sub on detection.** Stealth/avoidance is a valid answer to small threats; big ones force engagement or flight.
- **Environment:** currents, collapsing caverns, thermal vents, mines from old wrecks.
- **Internal events:** engine overheats, scrubber filter clogs, electrical flicker (station temporarily dark). These exist to pull players away from windows and create the "who's on it?!" scramble.
- **Design rule:** every threat must be solvable by at least two different stations, so the crew argues about *how*, not whether they *can*.

---

## 8. Meta-Progression (Dry Dock)

- **Currency:** Scrap (common, from anything) + Relics (rare, zone-gated, unlock module *blueprints*).
- Between runs the crew visits the dry dock: buy modules, choose hardpoint placement, upgrade hull rating.
- Module placement is a real decision: a bottom-mounted claw can't grab things above you; a stern turret covers your retreat.
- Cosmetics (paint, flags, googly eyes on the bow) as cheap, joyful rewards.

---

## 9. Art Direction

**"Cartoon shapes, pixel skin."**

**Tonal arc:** the game starts charming and gets *genuinely tense* with depth. The Shallows are pure cute; by the Midnight Trench, darkness, hull groans, and creature design create real dread — the contrast with the cozy interior is the point. The cute crew and warm sub interior are the emotional anchor that makes the deep feel dangerous rather than grim.

- **Resolution strategy:** chunky pixel art rendered at a consistent texel density (e.g., 32px per meter), but with the rounded, friendly silhouettes, squash-and-stretch animation, and saturated palette of Lovers in a Dangerous Spacetime.
- Smooth rotation/scale on pixel sprites is allowed (Lovers-style motion, pixel texture) — this is the practical hybrid: pixel *texture*, cartoon *motion*. Games like Eastward and Wargroove prove pixel art carries cuteness well.
- **Palette:** warm, toy-like sub interior (cream, brass, coral) vs. increasingly cold/dark exterior per zone. Interior always readable; danger color-coded (water = clear blue, breach sparks = white-orange, enemy attacks = magenta — never reuse these hues elsewhere).
- **Characters:** small, big-headed crew (2-frame run cycles read great at small sizes), heavy use of emotes/exclamation bubbles for silent communication.
- **Fauna:** cute-but-unsettling — big eyes, soft shapes, alarming teeth.

---

## 10. Audio Direction (brief)

- Interior: muffled, cozy machinery hums; each station has a signature sound so players can hear problems ("the engine sounds wrong").
- Exterior threats announce via sonar pings and creature calls. Hull groans scale with depth — the depth meter you *feel*.
- Music ducks during crisis stingers; goes ambient/awed in calm deep water.

---

## 11. Technical Design (Godot 4.x)

### 11.1 Architecture
- **Engine:** Godot 4.x, 2D. GDScript first; only drop to C# if profiling demands it.
- **Sub as scene composition:** the submarine is a `Sub` node owning a grid of `Module` scenes. Each module exposes hardpoints (`Marker2D`s), a station interface, and a water-level component. Adding a module at the dry dock = instancing a scene and snapping it to a hardpoint.
- **Two physics contexts:** the sub moves as one `RigidBody2D` (or `CharacterBody2D` with custom buoyancy) in the ocean world; crew members are bodies *inside* the sub's local space, parented to it. (Lovers does this; Barotrauma does the hard version. Do the easy version.)
- **Stations:** a `Station` interface: `enter(player)`, `exit(player)`, `handle_input(input_frame)`. The player's input is rerouted to the station while occupied.
- **Water-in-rooms:** per-room float `water_level` + a simple flow rate between connected rooms through open hatches. Render as a shader-clipped quad. No fluid sim.

### 11.2 Input abstraction (critical, build first)
- `PlayerInput` resource per player: `move: Vector2`, `interact: bool`, `use: bool`. 
- Providers: `KeyboardProvider`, `GamepadProvider`, `WebSocketProvider` (phone).
- Phone controller: Godot hosts a tiny HTTP page + WebSocket server (`WebSocketPeer`/`TCPServer` in-engine); phone browser shows a canvas joystick; messages are ~20-byte JSON at 30Hz. QR code on the lobby screen to join.

### 11.3 Procedural zones
- Handcrafted "chunk" scenes (200m of trench each) with spawn markers; runs stitch a shuffled sequence per zone + guaranteed event slots. Cheap, controllable, feels varied enough.

### 11.4 Save data
- Meta only: unlocked blueprints, sub layout, currencies, cosmetics. One JSON/`ConfigFile`. No mid-run saves in v1.

---

## 12. Scope: MVP → Vertical Slice → v1

**MVP (the "is this fun?" test):**
- 1 hardcoded 3-room sub (helm, engine, turret), 2 players (keyboard + gamepad), 1 zone, 2 enemy types, breaches + water + repair, win = reach 500m, lose = implode.
- No meta, no dry dock, no phone controllers, placeholder art.
- *If running between three stations while water rises isn't fun here, no amount of content fixes it.*

**Vertical slice:**
- Dry dock with 3 purchasable modules, 2 zones, 1 miniboss, salvage + death penalty loop, first-pass real art for the sub interior, phone controller prototype.

**v1 (shippable-ish):**
- 4 zones, 8–10 modules, 1 boss per zone, full art pass, 1–4 players all input types, solo "lock station" support, sound pass.

---

## 13. Risks & Open Questions

| Risk | Mitigation |
|---|---|
| Camera: cutaway interior + exterior threats at once | Single camera framing the sub with margin; sonar/edge indicators for off-screen threats. Prototype in MVP — this is the #1 unknown. |
| 4-player legibility | Strict color-coding per player + emotes; playtest at 2 first. |
| Phone controller latency/disconnects | LAN-only, auto-reconnect, gamepad fallback. Don't build until MVP proves fun. |
| Modular sub breaks handcrafted balance | Cap module count per run; price hardpoints, not just modules. |
| Scope creep toward Barotrauma sim depth | Pillar check: does it create a *station to run to*? If not, cut. |

**Open questions (resolved 2026-06-10):**
1. Sub stays upright with slight pitch tilt. ✔
2. Camera: fixed framing (sub + margin) for MVP; auto-zoom and helm-controlled zoom parked for later versions. ✔
3. Solo viability: still open — answer via solo playtests during MVP.

---

## 14. First Build Order (when we start)

1. Player character: run, climb, interact (1 day-ish)
2. Input abstraction layer (before anything else multiplies)
3. Sub shell + 2 stations (helm moves sub, turret shoots)
4. One dumb enemy + hull breach + water + repair
5. Playtest with your two testers. Then iterate the doc.
