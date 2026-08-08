# Changelog

## 1.3.0

First release of SafeguardReloaded, continuing from Safeguard 1.2.2 by Tollski.

### Client support

* Updated the interface version to **11509** (Classic Era 1.15.9).
* Renamed the addon to `SafeguardReloaded`. The TOC files, the ADDON_LOADED check,
  the sound file paths and the error interceptor all follow the new folder name.
* Added `## IconTexture` and an addon compartment entry so the options panel can be
  opened from the minimap.

### Fixes

* **Raid frame icons no longer silently stop working.** Blizzard removed the global
  `CompactRaidFrameContainer_ApplyToFrames` in favour of a method on the container.
  The addon now uses whichever the client provides.
* **Fixed a Lua error on every raid frame icon hover.** The tooltips anchored to
  `frame.ConnectedIcon` / `frame.DisconnectedIcon` / `frame.InCombatIcon`, none of
  which were ever assigned — the icons live under `frame.SgIconsContainerFrame`.
  Tooltips now anchor to the icon itself.
* **Fixed group chat messages being dropped.** Messages were always sent to the
  `PARTY` channel, which fails in a raid or an instance group. The channel is now
  resolved from the group the player is actually in.
* **Fixed the error interceptor erroring during load.** It dereferenced
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

* `NpcDatabase.lua` and `ZoneDatabase.lua` are no longer loaded. Nothing referenced
  them, and they cost roughly 1.9 MB of memory on every login. The files are kept in
  the repository for future use.
* Removed the empty `UNIT_COMBAT` and `UNIT_TARGET` handlers and the empty
  `OnTooltipSetUnit` hook. All three ran on every fire and did nothing.

---

## 1.2.2 and earlier

Released as **Safeguard** by Tollski. See the
[CurseForge page](https://www.curseforge.com/wow/addons/safeguard) for that history.
