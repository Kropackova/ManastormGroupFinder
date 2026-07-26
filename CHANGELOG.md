# Changelog

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
