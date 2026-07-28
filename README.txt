Manastorm Group Finder 2.3
WoW 3.3.5a clients, including Project Ascension.

*** THE FOLDER MUST BE NAMED  ManastormGroupFinder  ***
On the Releases page, download ManastormGroupFinder.zip from the Assets list,
NOT "Source code (zip)". The Assets file extracts with the correct folder name
and needs no renaming.

Anything else - "Source code (zip)", the green Code button, a tag download -
gives you a folder called ManastormGroupFinder-2.3 or -main. RENAME IT to
ManastormGroupFinder before putting it in Interface\AddOns, or the game
silently ignores it and it never shows up in your addon list. The client
requires the folder name to match ManastormGroupFinder.toc, so any suffix
breaks it.

  Interface\AddOns\ManastormGroupFinder\ManastormGroupFinder.toc      loads
  Interface\AddOns\ManastormGroupFinder-2.3\ManastormGroupFinder.toc  ignored
  Interface\AddOns\ManastormGroupFinder-main\ManastormGroupFinder.toc ignored

WHY 1.0 FOUND NOTHING
This build captures chat twice. It registers the chat events, and it also
hooks the chat display filters, so it reads exactly what your chat frame
prints. Every captured line runs inside a protected call, so a single error
cannot silently stop the scanner, which is what a client with Lua error
display switched off looks like from the outside. Duplicate delivery from the
two paths is filtered out.

IF IT STILL LISTS NOTHING
1. /msgf debug     turns on a log line for every scanned chat message.
2. /msgf stats     prints how many lines were seen, how many matched
                   Manastorm, how many rows exist, error count, whether the
                   channel event is registered, and the last error text.
Send me those two outputs and the fix is immediate.

INSTALL
The folder must be named exactly ManastormGroupFinder, no version number and
no -main suffix. Rename it first if yours has one.
Copy the ManastormGroupFinder folder into
   <game folder>\Interface\AddOns\ManastormGroupFinder
so that ManastormGroupFinder.toc sits directly inside it. Then /reload or
restart the client. Run /msgf clearall once after upgrading, because rows
stored by an older version are not reclassified.

WINDOW
Tabs LFM, LFG, Unsure, each with a live count.
Sortable columns, click a header, click again to reverse.
Resizable by the grip in the bottom right corner. The Message column takes
all the width you give it, the other columns keep their size.
Scrollbar on the right with arrows and a draggable thumb. The mouse wheel
scrolls over the table and over the window.
Timestamps are HH:MM:SS. Grey means older than five minutes. Rows drop after
fifteen minutes, adjust with /msgf expiry.

EDITING
Left click Role to cycle through the combinations.
Left click Aura or Looms to switch yes and no.
Left click Lvl, type a number, press Enter. Clicking anywhere else also
saves and closes the editor, Escape cancels.
Edited values turn blue and lock, so later messages never overwrite them.

SUGGEST INVITE
  On Ascension, a player who is in a group without rank cannot invite. The
  client offers "Suggest Invite" instead, which sends the group leader a
  popup to accept or deny.

  The row menu now follows that rule. It reads your party or raid state at the
  moment you right click:
    solo, party leader, raid leader, raid assistant  ->  Invite
    in a group with no rank                          ->  Suggest Invite

  Raid assistants keep Invite, because the server lets them invite.

  Tested on Ascension on 28 July 2026. The addon calls the client function
  SuggestInvite with the player name, the leader gets the accept or deny
  popup, and the addon prints a confirmation line in chat. One click, no
  targeting, no chat spam, and the player does not have to be near you.

  If a future client build renames the function, the addon looks for four
  other likely names, then any global whose name contains suggest and invite,
  then a slash command. It never calls RequestInvite, because asking for an
  invite for yourself is a different action.

  Two diagnostics stay in the build:
    /msgf group - the raw party and raid state the client reports
    /msgf probe - which suggest entry points exist, and which one was used


RIGHT CLICK ANYWHERE IN A ROW
Whisper, Invite, Target, Inspect, Trade, Follow, Duel, Who, Add friend,
Ignore, Copy name, Remove row.
Whisper, invite, who, friend and ignore work from the name alone. Inspect,
trade, follow and duel need a unit reference, so the addon targets the name
first and prints why it failed when the player is out of range or elsewhere.

FILTERS
The Filters button opens a panel anchored under the button. It never follows
the cursor. The panel is fully opaque, nothing behind it shows through.
Clicking outside it or pressing Close closes it.
Contents: role, aura, looms, which side you are on, level range and a message
keyword. The panel filters the table and decides which new rows raise an
alert. Aura and looms match a mention, so both yes and maybe pass.

I AM LOOKING FOR
  a group to join    shows recruit posts, alerts only on LFM
  players to join me shows offers, alerts only on LFG
  both               leaves the tab alone, alerts on either
Recruit posts are far scarcer than offers, so an LFM alert holds on screen
2.5 times longer than an LFG alert before it fades.
Picking one switches the tab and the alert scope together, so you do not have
to set them separately.

WHISPER BUTTON
  Every row has a narrow W column between Lvl and Message. Left click it and
  the addon sends your saved line to that player as a whisper, at once. The
  cell then turns green and reads "sent", so you can see who you contacted.

  Press the "Whisper..." button at the bottom of the window to write the
  lines, or use /msgf whisper. There is one line per tab:
    LFM tab - sent to a player leading a group looking for players
    LFG tab - sent to a player who is looking for a group

  Placeholders are replaced at the moment you click:
    {name}    the listed player
    {role}    their role as shown in the table
    {level}   their level, ? when unknown
    {aura}    yes, no or maybe as shown
    {looms}   yes, no or maybe as shown
    {size}    group size when the message states one
    {myname}  your character name
    {mylevel} your level

  Example for the LFM tab:
    Hi {name}, lvl {mylevel} dps with looms and aura, room in your MS?

  Nothing is ever sent on its own. One click, one whisper. Hover a row to see
  the exact text before you send it.


ALERT POPUP
The frame is measured against the text, so a short line gets a small frame.
Width runs from 220 to 520 pixels and the height follows the wrapped text.
It appears at its final spot with a 0.1 second fade, no sliding and no
scaling, holds 2 seconds for LFG and 5 seconds for LFM, then fades out.

ALERTS
Left click the Alerts button to switch alerts on or off. Right click cycles
sound and chat output. When a new row passes the filters:
  - the original message appears at mid height, two thirds across the screen
  - it appears in place, no slide and no zoom
  - it holds for two seconds, then fades
  - up to five alerts queue up
Alert scope: /msgf alert mode lfm | lfg | any.

STYLES
/msgf style vanilla   Blizzard dialog frame and gold text, like the Friends
                      List window
/msgf style dark      neutral dark panel
/msgf style grid      dark panel with column separators and stronger row
                      banding, the most explicit table structure
All three use textures already in the client, so nothing extra ships here.

GROUP SIZE TOKENS
MS15 means Manastorm with fifteen players, and that number is a group size,
not a level and not a wanted count. Recognised: ms15, ms 15, ms5, ms10,
ms20, ms25, ms40, manastorm15, mstorm15, 15 man. The size shows in the row
tooltip, and the Filters keyword box accepts ms15 when you want only that
size. Group progress such as 3/3, 8/10 or 14/15 is read as progress, so those
numbers never land in the Level column either.

CLASSIFICATION
A message must reference Manastorm: manastorm, mana storm, mstorm or ms.
The ms token is rejected in loot contexts such as ms>os and mainspec.
Then, in order:
  1. Questions, trade spam and guild recruitment with no lf token -> Unsure
  2. Counted or role targeted recruiting -> LFM
     lf3m, lf 1 healer, lf1 heal, lf 1 aoe dps, need 2 dps, need healer,
     lf tank, 2 more, 1 spot
  3. Direct invite request -> LFG
     inv me, invite pls, can i join, lf inv, add me
  4. What the lf token points at -> LFG
     lf ms, lf ms dps, lf ms farm, lf manastorm, lf group, lf grp, lf raid,
     lf ms15, searching for ms. The object beats word order: in LF MS DPS the
     sender is looking for the group, so dps is their own role.
  5. A role plus any lf token -> LFG
     dps lf ms, tank with aura lf ms, healer lf ms lvling, aoe dps lg ms,
     small dps lf grupe ms
  6. lfm, forming, spots left, pst for inv -> LFM
  7. lfg, lf group, lf grp, lf grupe, lg ms, plus1 -> LFG
  8. A role plus a self advertisement, no lf token -> LFG
     full looms gigadps prestiged dps, tank w/aura
  9. Anything else -> Unsure
Two rules do the work. First, what the lf token points at: a group word means
the sender wants in, a role or a headcount means they are filling a group.
Second, where the roles sit: lf dps recruits, dps lf offers.

Recruit signals still beat the object rule, so LF MS keeps its place in LFM
when the line also carries a headcount (LF 2 DPS for MS), a leader phrase
(pst, pm info, invite bot, w me) or a progress fraction (13/15, 2/2 tanks).

How the position rule reads real lines:
  LF MS dps 33                            lf points at ms            -> LFG
  LF MS DPS                               lf points at ms            -> LFG
  LF MS FARM - LVL 47 DPS full heirloom   lf points at ms            -> LFG
  LF 60 Dps for MS Duo push               lf points at a role        -> LFM
  LF MS15 DPS AURA, TANK LOOM PM INFO    ms object but leader words  -> LFM
  LF MS leveling, dps w/ looms           one role after, self ad     -> LFG
  2 dps full looms & aura w aoe LF MS    roles before lf             -> LFG
  LF 49 DPS w. Aura/Looms LF MS          49 is a level, not a count  -> LFG
  MS15 Full Loom Dps                     no lf, role plus self ad   -> LFG
  MS15 DPS AURA, TANK LOOM PM INFO        no lf, leader wording      -> LFM
  dps searching for ms                    role before searching      -> LFG
  MS Need Tank + 1 aura                   role after need            -> LFM
  LF MS: 2/2 Tanks, 3/3 Heals, NEED 2 DPS progress and a count       -> LFM
  MS Raid 3/3 Aura, need tank ONLY, PM    role after need, leader    -> LFM
  Tank LF MS farm. Send invite please     asks to be invited         -> LFG
  LFM FOR MANASTORM, TANKS PRIORITY PST   explicit lfm               -> LFM
  aoe DPS lfg MS                          explicit lfg               -> LFG
  MS 14/15 PM WITH LEVEL                  progress, leader wording   -> LFM
A number after lf is a headcount only up to nine, so lf 3 dps is a count
while LVL 49 DPS LF MS is a level.

When the wording is truly ambiguous, right click the row and pick Move to
LFM, Move to LFG or Move to Unsure. The row keeps every edited value.

AURA AND LOOMS
What a mention means depends on who wrote the line, so the value depends on
the tab. Nothing is ever unknown, and the reading is deterministic.

LFG and Unsure tabs, header Aura and Looms. The sender is advertising what
they bring, so the value is a plain fact:
  - mentioned          -> yes
  - not mentioned      -> no
  - negated            -> no

LFM tab, header Aura req and Looms req. A leader who names aura or looms can
mean a hard requirement, a nice to have, or what the group already carries,
and the text does not say which:
  - mentioned          -> maybe, shown in yellow
  - not mentioned      -> no requirement
  - negated            -> no
So a mention in a recruit post is never reported as a firm requirement.

Moving a row between tabs with the right-click menu recomputes both cells for
the new tab, unless you edited them yourself.

Clicking a cell cycles no, maybe, yes and locks your choice.

How the text is read in either case:
  - one mention of aura or looms          -> mentioned
  - no mention at all                     -> no
  - a negated mention                     -> no
Negation is read word by word and carries across a list, so:
  "dps lf ms aura looms"        aura yes,  looms yes
  "dps lf ms"                   aura no,   looms no
  "dps lf ms no aura"           aura no,   looms no
  "no aura or looms lf ms"      aura no,   looms no
  "no looms but aura lf ms"     aura yes,  looms no
  "aura off, full looms"        aura no,   looms yes
  "unloomed dps with aura"      aura yes,  looms no
Glued forms are handled too: noaura, nolooms, unloomed. Common misspellings
of heirlooms are in the token list in Parser.lua.

Level stays ? when nobody states it, since Manastorm callers rarely do.

COMMANDS
/msgf                       toggle the window
/msgf lfm | lfg | unsure    pick a tab
/msgf style vanilla|dark|grid
/msgf clear                 clear the current tab
/msgf clearall              clear every tab
/msgf minimap               show or hide the minimap button
/msgf alert on | off | sound | chat | popup | mode lfm|lfg|any
/msgf alert test            preview the popup
/msgf expiry 900            row lifetime in seconds
/msgf own                   include or ignore your own messages
/msgf debug                 log every scanned line
/msgf stats                 capture counters and last error
/msgf test <message>        parse a line without sending it
/manastorm                  same as /msgf

FILES
ManastormGroupFinder.toc  load order
Parser.lua                tokens and classification, tune wording here
Core.lua                  capture, storage, filters, slash commands
Alerts.lua                on screen notification
UI.lua                    window, table, editing, player menu, minimap
