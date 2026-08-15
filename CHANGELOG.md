# Changelog

## Unreleased

### New

* **Separate onscreen notification switches for low mana**, one for yourself and one
  for your group, matching how low health already worked. Previously every mana
  notification hung off the single "enable low mana alerts" switch.

### Changes

* **The options panel has been rebuilt.** It is now split into five labelled
  sections — low health, low mana, chat messages, onscreen notifications and
  interface — with the alerts first, since that is what the addon is for.

  The notification switches sit in a proper grid under **You** and **Party** column
  headings. They used to be scattered across offsets that differed from block to
  block, so nothing lined up vertically. Where a column does not apply to a row it
  now shows a dash rather than an empty space that looks like a missing checkbox.

  The panel scrolls, so the lower rows can no longer be cut off at smaller
  resolutions or higher UI scales.

  Clicking a label toggles its checkbox — previously only the small box itself
  responded — and a change is saved the moment you make it instead of when the panel
  closes.

  Options whose parent switch is off are greyed out, which replaces the static
  "(Requires Low Health Alerts)" note next to a control that still looked active.

### Fixes

* **Low health alerts could leave your dialog volume stuck at maximum.** The alert
  sound plays on the Dialog channel, so the addon briefly forces the dialog cvars on
  and restores them a second later. Dropping through both health thresholds at once
  fires two alerts inside that second, and the second one mistook the values the
  first had already forced for your own settings and wrote them back permanently.
  Your dialog volume then stayed at maximum until you noticed and reset it by hand.

---

## 1.3.4

### Changes

* **The chat prefix is `[Safeguard]` again**, reverting the `[SGR]` introduced in
  1.3.1. A group now reads one consistent tag instead of two spellings of the same
  addon. The cost is that a chat line no longer tells you which of the two addons
  sent it, and that the longer prefix eats more of the 255 character limit on short
  messages.

  This is the prefix on chat and on the addon's own printed lines. The addon message
  prefix used for addon-to-addon traffic was already `Safeguard` and is unchanged.

---

## 1.3.3

### New

* **Low mana alerts.** Off by default. Switch them on in the options, set your own
  threshold, and you get an onscreen notification and an optional party chat message
  when your mana drops below it. Group members running the addon are covered too.

  One threshold rather than the two health uses, because there is no useful
  difference between low and critically low mana. The alert fires on the way down
  and not again until mana has recovered past the threshold, so hovering either side
  of the line does not produce a stream of messages.

### Changes

* **Onscreen notifications are far easier to read.** They no longer go through the
  game's error frame, which draws flat white text with no outline — over snow, sand
  or a lit interior that was close to unreadable, on exactly the messages you can
  least afford to miss. They are now drawn with an outlined font in a frame of their
  own, sitting directly below the game's error text.

  Long messages wrap instead of running off the edge of the screen, which the error
  frame did not do. A long mob name in an extra attacks warning stays on screen.

  The game's own error messages are deliberately left untouched.
* `/sgrtest` now shows two sample notifications, so the onscreen text can be checked
  without waiting for something to actually go wrong.

---

## 1.3.2

### Fixes

* **The Low Health % and Critically Low Health % fields could not be edited.** Both
  cap at two letters and hold a two digit percentage, so as soon as the saved value
  was loaded they sat at the character limit and the client rejected every
  keystroke. Clicking a field and typing did nothing at all, with no error to
  explain it.

  Clicking a field now selects its contents, so typing replaces the value. Enter
  and Escape both release focus, and leaving a field saves it immediately instead
  of waiting for the options panel to be closed.

---

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
