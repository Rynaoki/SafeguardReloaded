# Changelog

## 1.3.1

Fixes two problems that made 1.3.0 unusable for a lot of players. Updating is
strongly recommended.

### Fixes

* **The options panel could not be opened at all.** `Settings.OpenToCategory` routes
  to `C_SettingsUtil.OpenSettingsPanel` on 1.15.x, which only accepts a numeric
  category id, but the panel name was being written over `category.ID`. That was a
  common trick back when the function still took a name. Because the resulting
  error was raised inside a slash handler, the chat edit box was never cleared and
  the Enter key appeared to stop working after typing `/sgr`.
* **Watched spells were never detected on a non-English client.** The combat log
  reports spell names in the client's language, so tables keyed by English names
  only ever matched in English. On a German client, casting Hearthstone produced
  "Ruhestein" and no group message was sent. Names are now resolved from spell ids
  at load time, which works on every locale and covers every rank of a spell.
* **Spell cast announcements never fired in a raid.** The check used `UnitInParty`,
  which is false in a raid group.
* Added Classic Era spell ids for `Ice Block`, `Invulnerability`, `Light of Elune`
  and `Petrification`, which the original addon carried as unconfirmed English
  string literals. Every watched spell now resolves on every locale.
* The version and author line in the options panel overlapped the first option row.
  It now sits on the title's baseline instead of a line of its own.

### Changes

* Spell names in messages and notifications are now always English, whatever the
  client language. A sentence stays in one language instead of reading "My
  Ruhestein cast has been stopped.", and a group of mixed-locale clients sees the
  same spell name rather than each member reading the sender's translation.
* Chat messages are prefixed with `[SGR]` instead of `[SafeguardReloaded]`. Twenty
  characters of prefix crowded out short messages such as "Help, my health is at
  25%!", and `[SGR]` does not collide with the original addon's `[Safeguard]`.

---

## 1.3.0

First release of SafeguardReloaded, continuing from Safeguard 1.2.2 by Tollski.

### Client support

* Updated the interface version to **11509** (Classic Era 1.15.9).
* Renamed the addon to `SafeguardReloaded`. The TOC files, the ADDON_LOADED check,
  the sound file paths and the error interceptor all follow the new folder name.
* Added `Compat.lua`, which keeps every client API difference in one place instead
  of scattered through the addon.
* Added `## IconTexture` and an addon compartment entry so the options panel can be
  opened from the minimap.

### Fixes

* **Raid frame icons had silently stopped working.** Blizzard replaced the global
  `CompactRaidFrameContainer_ApplyToFrames` with a method on the container. The
  addon now uses whichever the client provides.
* **Hovering a raid frame status icon threw a Lua error every time.** The tooltips
  anchored to `frame.ConnectedIcon`, `frame.DisconnectedIcon` and
  `frame.InCombatIcon`, none of which were ever assigned — the icons live under
  `frame.SgIconsContainerFrame`. Tooltips now anchor to the icon itself.
* **Group chat messages were dropped in raids and instance groups.** Messages were
  always sent to the `PARTY` channel, which silently fails outside a party. The
  channel is now resolved from the group the player is actually in.
* **The error interceptor errored during load.** It dereferenced
  `Safeguard_Settings.Options` before `ADDON_LOADED` had populated it, so any error
  raised while the addon was still loading produced a second error.
* Guarded `UnitDetailedThreatSituation`, `GetPVPTimer` and `BACKDROP_TUTORIAL_16_16`,
  none of which are guaranteed to exist on every client flavour.

### Changes

* Settings moved to `SAFEGUARDRELOADED_SETTINGS`. If the original Safeguard is still
  installed and loaded, its settings are imported once on first load.
* Option defaults are now driven by a single table instead of a chain of nil checks,
  so new options pick up their default automatically.
* Added `/sgr`, `/safeguardreloaded`, `/sgrdebug` and `/sgrtest`. The original
  `/sg`, `/safeguard`, `/sgdebug` and `/sgtest` still work.
* Fixed the misspelled `/sasfeguarddebug` and `/sasfeguardtest` commands.
* Addon message prefix stays `Safeguard` for cross-compatibility with players still
  running the original addon.
* Addon messages are now registered during `ADDON_LOADED` rather than on the first
  `PLAYER_ENTERING_WORLD`.

### Performance

* `NpcDatabase.lua` and `ZoneDatabase.lua` are no longer loaded, and are left out of
  the released package. Nothing referenced them, and they cost roughly 1.9 MB of
  memory on every login. The files are kept in the repository for future use.
* Removed the empty `UNIT_COMBAT` and `UNIT_TARGET` handlers and the empty
  `OnTooltipSetUnit` hook. All three ran on every fire and did nothing.

---

## 1.2.2 and earlier

Released as **Safeguard** by Tollski. See the
[CurseForge page](https://www.curseforge.com/wow/addons/safeguard) for that history.
