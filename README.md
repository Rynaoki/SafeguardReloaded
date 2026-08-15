# SafeguardReloaded

A World of Warcraft **Classic Era** addon that helps players stay alive.

SafeguardReloaded is a maintained continuation of [Safeguard](https://www.curseforge.com/wow/addons/safeguard)
by **Tollski**, which is no longer being updated. This fork brings the addon up to
date with the current Classic Era client and fixes several long-standing bugs.

| | |
|---|---|
| **Maintainer** | Rynaoki |
| **Original author** | Tollski |
| **Supported client** | Classic Era 1.15.9 (`## Interface: 11509`) |
| **Also ships a TOC for** | TBC Classic 2.5.5 |

## Installation

1. Download or clone this repository.
2. Copy the folder into `World of Warcraft\_classic_era_\Interface\AddOns\`.
3. **The folder must be named `SafeguardReloaded`** — WoW matches the folder name
   against the `.toc` file name, and the addon will not load if they differ.
4. Restart the game, or type `/reload` if it was already running.

If you previously used the original Safeguard, disable or remove it. Both addons
register the same `/sg` and `/safeguard` slash commands, and running them side by
side means duplicate chat messages to your group.

## Usage

| Command | What it does |
|---|---|
| `/sgr` or `/safeguardreloaded` | Open the options panel |
| `/sg`, `/safeguard` | Same, kept from the original addon |
| `/sgrdebug`, `/sgdebug` | Print the last 50 debug log entries |
| `/sgrtest`, `/sgtest` | Print the loaded addon version |

The options panel is also reachable through the minimap addon compartment and via
*Game Menu → Options → AddOns → SafeguardReloaded*.

## Features

Alerts you when your health is low by flashing the screen and playing a sound.

Optionally alerts you when your mana drops below a threshold you set. Off by default.

Optionally forces the "Floating Combat Text" interface option to stay enabled.

Optionally shows a timer tracking when you will be unflagged from PvP.

Onscreen notifications when:

* You or a group member disconnects.
* You or a nearby player is affected by certain threat-altering effects.
* You or a group member enters combat.
* You or a group member has low health.
* You or a group member has low mana, if you enable it.
* You are flagged for PvP.
* A group member casts certain spells (e.g. Hearthstone).
* A group member is crowd controlled (e.g. stunned, silenced).
* A group member is logging out.
* A group member goes offline.
* An enemy stores extra attacks (e.g. Thrash).

Automatic chat messages to your group when:

* You have critically low health.
* You have low mana, if you enable it.
* You cast certain spells (e.g. Hearthstone).
* You are crowd controlled (e.g. stunned, silenced).
* You are logging out.
* A deadly enemy targeting you stores extra attacks.

## Compatibility with the original Safeguard

The addon message prefix is deliberately still `Safeguard`, so group members running
the original addon and members running SafeguardReloaded can still exchange status
information with each other.

Settings are stored under `SAFEGUARDRELOADED_SETTINGS`. On first load, if the
original Safeguard is still installed and loaded, your existing configuration is
imported automatically.

## What changed in this fork

See [CHANGELOG.md](CHANGELOG.md) for the full list. The short version:

* Updated to the Classic Era 1.15.9 interface version.
* Fixed the options panel, which could not be opened at all on 1.15.x and left the
  chat box unusable when you tried.
* Fixed watched spells never being detected on a non-English client, where the
  combat log reports translated spell names.
* Spell names in messages are now always English, so a mixed-locale group reads the
  same text.
* Fixed raid frame icons, which were broken by Blizzard replacing
  `CompactRaidFrameContainer_ApplyToFrames` with a container method.
* Fixed a Lua error thrown every time you hovered a raid frame status icon.
* Fixed group chat messages being sent to the wrong channel in raids and instance
  groups, where they were silently dropped.
* Added a `Compat.lua` shim layer so API changes are handled in one place.
* Stopped loading ~1.9 MB of unused NPC and zone data on every login.

## Project layout

```
Compat.lua                 API shims for client differences
Enum.lua                   Message / notification / crowd-control enums
FlashFrame.lua             Fullscreen low-health flash
HelperFunctions.lua        Generic Lua helpers
IntervalManager.lua        Periodic combat, connection and heartbeat checks
Main.lua                   Event registration and handlers
MessageManager.lua         Addon and chat message send/receive
NotificationFrame.lua      Draws the onscreen notifications
NotificationManager.lua    Builds and throttles onscreen notifications
Options.lua                Options panel
PlayerStates.lua           Per-player state structs
PvpFlagTimerWindow.lua     Draggable PvP flag timer
RaidFramesManager.lua      Status icons on compact raid frames
UnitHelperFunctions.lua    Unit id / GUID lookups
NpcDatabase.lua            Scraped NPC data (kept for reference, not loaded)
ZoneDatabase.lua           UiMap to AreaId mapping (kept for reference, not loaded)
```

## Credits and licensing

All original code and design is by **Tollski**, author of Safeguard. This fork is
maintained by **Rynaoki** 


## Contributing

Bug reports and pull requests are welcome. When reporting a bug, please run
`/sgrdebug` and include the output along with your client version.
