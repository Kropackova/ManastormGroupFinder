# Changelog

## 2.8

- **Suggest Invite confirmed working.** Tested on Ascension on 28 July 2026: the client global `SuggestInvite` takes a plain player name, and the group leader receives the accept or deny popup. The row menu calls it directly, so one click reaches a player anywhere on the server.
- Removed the temporary **Player menu** entry. It was the fallback while the entry point was unknown, and it is no longer needed.
- `Compat.lua` keeps the name scans as a safety net in case a future client build renames the function, and still refuses to call `RequestInvite`.
- `/msgf group` and `/msgf probe` stay in the build as diagnostics.

## 2.7.1

- Menu entry renamed to **Suggest Invite**, the client's exact wording.
- Five exact function names are now checked before the generic scan: `SuggestInvite`, `SuggestInviteByName`, `SuggestInviteUnit`, `SuggestGroupInvite`, `SuggestPartyInvite`. `/msgf probe` prints the result of every check by name.
- `RequestInvite` and similar names are reported but never called. Requesting an invite for yourself is a different action.

## 2.7

- Row menu now respects Ascension's invite rules. In a group without rank the **Invite** entry becomes **Suggest an invite**, which asks the group leader through the client's own accept or deny popup. Raid assistants keep **Invite**, because the server lets them invite.
- New **Player menu** entry opens the real player menu for that name, the same one you get by right clicking a name in chat. Everything the client adds to that menu is reachable from a row.
- New `/msgf probe`, which lists every suggest related function, slash command, menu button and dialog the client exposes, and `/msgf group`, which prints the raw party and raid state.
- New file `Compat.lua`. It assumes no function names. Entry points are looked up in the running client and cached, and the player menu is the fallback when no direct call exists.

## 2.6

- Fixed the whisper panel: the LFG template box drew without its background because the stock input box art only rendered on the first box. Both boxes are now built with their own solid backdrop and look identical.
- Clearer labels: *LFM tab - sent to a player leading a group looking for players*, *LFG tab - sent to a player who is looking for a group*.
- Removed `{myrole}` from the placeholder legend. It was never implemented, because Ascension characters are classless and nothing in the API states your intended role.

## 2.5

- New **W** column between **Lvl** and **Message**. Left click sends your saved whisper to that player at once, and the cell then reads `sent` in green.
- Whisper templates, one line per tab, set with the **Whisper...** button at the bottom of the window or `/msgf whisper`. LFM wording and LFG wording are kept apart.
- Placeholders filled in at click time: `{name}`, `{role}`, `{level}`, `{aura}`, `{looms}`, `{size}`, `{myname}`, `{mylevel}`.
- Hovering a row previews the exact whisper text and the time an earlier one was sent.
- New commands `/msgf whisper`, `/msgf whisper lfm <text>`, `/msgf whisper lfg <text>`.

## 2.4
- **Fixed the biggest classification error: `LF MS` now means LFG.** What the looking-for token points at decides the side, and that beats the role-position rule. `LF MS DPS`, `LF MS dps 33`, `LF MS FARM`, `searching for ms` are all offers, not recruit posts.
- A role named after `lf ms` is now read as the sender's own role, not as a role being recruited.
- Recruit signals still win over the new rule: an explicit headcount (`LF 2 DPS for MS`), a leader phrase (`pst`, `pm info`, `invite bot`, `w me`), or a progress fraction (`13/15`, `2/2 tanks`) keeps the post in LFM.
- Group objects recognised after the token: `ms`, `manastorm`, `ms15`, `group`, `grp`, `party`, `raid`, `run`, `farm`, `spam`, `loop`, `push`, `carry`, `leveling`, `duo`, `trio`, with filler words such as `for`, `a`, `the`, `big`, `giga` skipped.
- Group size read from `duo` and `trio` as 2 and 3.

## 2.3
- Aura and looms are now read per tab. On **LFG** and **Unsure** a mention means **yes**, since the sender is advertising what they bring. On **LFM** a mention means **maybe**, since a leader naming aura or looms may mean a requirement, a nice to have, or what the group already carries. An explicit negative is always **no**.
- Clicking an aura or looms cell cycles **no -> maybe -> yes** and locks the value.
- Moving a row between tabs recomputes both cells for the new tab.
- Filter panel gained **I am looking for**: *a group to join*, *players to join me*, *both*. Picking one sets the tab and the alert scope together.
- Filter checkboxes renamed from *aura only* / *looms only* to **aura** / **looms**. They now match a mention, so `maybe` passes too.
- Alert popup is sized to its text, from 220 to 520 pixels wide, with a thinner border and tighter padding.
- Alert animation minimised: it appears at its final position with a 0.1 second fade, no sliding and no zooming.
- LFM alerts hold 5 seconds against 2 seconds for LFG, since recruit posts are far scarcer.

## 2.2
- Size tokens understood: `MS15`, `ms 15`, `ms15man`, `size15`, and progress fractions such as `14/15` or `3/3 aura`.
- Classification rewritten around word position: a role stated before the intent word means the sender is offering themselves, a role after it means they are recruiting.
- Recruit counts parsed from `LF2M`, `LF3M`, `need 2 dps`.
- New role words including `pumper`, `frost`, `healo`, phrase `big pumper`.
- Tooltip shows detected group size and how many players are wanted.
- Right-click menu gained **Move to LFM / LFG / Unsure**.

## 2.1
- Aura and looms made deterministic, never unknown, with negation handling and glued forms such as `noaura` and `unloomed`.
- Filter panel made fully opaque so chat no longer bleeds through it.
- Aura and looms columns widened, headers relabelled per tab.

## 2.0
- Second capture path through the chat display filters, so the addon reads exactly what your chat frame shows.
- Every message handled inside a protected call, with `/msgf debug` and `/msgf stats` for diagnosis.
- On-screen alert popup with queue.
- Rewritten window: row-level right-click menu, editable cells, visible scrollbar plus wheel, resize grip, three styles, anchored filter panel, minimap button, three tabs, sortable headers.

## 1.0
- First release: chat scanning, LFM and LFG buckets, parsed role, aura, looms and level, sortable table, slash commands.
