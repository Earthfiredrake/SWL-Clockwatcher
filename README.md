# SWL-Clockwatcher
Mission and agent cooldown tracking utilities

## Overview
A collection of tools to help track mission and agent cooldowns. Used by itself the mod adds:
+ Lair Timers - lockout timer window (shift-l); lists the longest remaining cooldown among missions in that lair
+ Login Agent Status - character selection; shows an icon if an agent mission is complete or an agent and open mission slot are both available

It also provides data support to the offline viewer program (exclusive to GitHub):
+ Offline tracking - Mission/lair cooldown timers and agent mission completion and recovery timers can be viewed from outside of the game (or while on an alt)
+ Audio alerts when an agent mission or recovery timer is completed
+ Audio alerts when groupfinder queues pop

Some general settings are saved per account. Offline mission lists are saved per character and can be disabled with `/setoption efdClockwatcherOfflineExport false` if you don't wish to use the viewer. Viewer settings are piggybacked onto the local app settings folder for SWL.

## Installation
The packaged release should be unzipped (including the internal folder) into the listed folder:
<br/>SWL: [SWL Directory]\Data\Gui\Custom\Flash
<br/>TSW: [TSW Directory]\Data\Gui\Customized\Flash (Untested, may have unexpected 'features')

The safest method for upgrading (required for installing) is to have the client closed and delete any existing .bxml files in the mod directory. Hotpatching (using /reloadui) works as long as neither Modules.xml or any *Prefs.xml files have changed.

Clockwatcher.exe requires v4.6 of the .net framework to be installed which can be downloaded from Microsoft if needed. It will not have any content until the mod has had an opportunity to save some data.

## Usage Notes
+ When the mod is first used, each character must be logged in once to cache data for the offline viewer
  + Character select agent alerts will be updated once an agent changes state (completes or starts a mission, or recovers from incapacitation)
+ Each lair's missions share a single entry in both the timer window and offline tracking tool, and the listed time is the longest of those missions' cooldowns
+ Clockwatcher.exe automatically refreshes every five seconds, merging new data with that already loaded and retaining any "Ready!" missions until manually cleared
+  Game state changes should force serialization, so the app will have the new data promptly after mission completions, agent status changes
+ Cooldowns seem to be tweaked occasionally by the server. Values provided by this mod, particularly while offline, should be considered estimates, usually accurate to within a minute or two
  + Agent recovery timers seem to be out of whack at the moment, with agents coming back on duty hours ahead of schedule. This can cause both the viewer and login alert system to think an agent is still busy long after they've recovered
+ Queue alerts:
  + Are not triggered for solo scens, or if queueing as a group
  + Use the same refresh cycle as the rest of the viewer, so may be delayed by up to five seconds

## Change Log
Version 1.3.1
+ Full support for new agent mission slots
  + Login alerts were ignoring empty slots after the third
+ Sequential groupfinder pops should now be better at triggering audio alerts
+ App no longer tied to mod directory
  + Autodetects running client instances and pulls their path info to find the logfiles
  + sfx folder is still required to be nearby (see the viewer only pack on github for required files)
+ Fixes a couple minor bugs with the app, and adds significant logging to track down any remaining issues
  + If you end up with an AppLog.txt file in your app directory, let me know

Version 1.3.0
+ Mod: Alternate login screen system hopefully fixes the login crashes (if it starts crashing on startup, let me know)
  + Does not reset the setting that disables this, so you'll need to do that yourself
+ Mod: Support for new viewer features
+ Viewer: Groupfinder pop alerts
+ Viewer: Tracked down and fixed some unbounded memory usage, memory footprint should be much more level now
+ Viewer: Alternate agent alert sounds have been added into the base download
  + Can be found in the `sfx/alt` subdirectory, and used by copying and renaming over the existing `sfx/AgentAlert.wav` file

Version 1.2.2
+ Mod: Lair lockout list no longer confused after encountering an active cooldown
+ Mod: Login agent alerts can now be disabled for stability (/setoption efdClockwatcherLoginAlerts false)
+ Mod/Viewer: Lairs now have the proper zone name attached
+ Viewer: Automatic refresh now more refreshing, loads changes to data without prompting, manual refresh has been retired
+ Viewer: "Clear Ready" now affects only the current character tab, refreshes no longer reload completed timers
+ Viewer: Audio and taskbar alerts when a timer runs out
+ Viewer: Now has a non-default icon

Version 1.2.1
+ Mod: No longer converts lost connections into desktop visits (crash fix)
+ Mod/Viewer: Now exports recovery times for incapacitated agents
+ Viewer: Colour coding for lairs (lavender) and agents (blue on mission or red when recovering)
  + Due to data mapping changes, agents may appear with lair colouring until all the character caches are refreshed
+ Viewer: Added a button to clear the "Ready" mission entries from the display
  +  If they still exist in the data cache they will be reloaded with the next manual refresh

Version 1.2.0
+ Mod: Agent status now displayed on character selection
+ Mod: /setoption efdClockwatcherOfflineExport added to disable data export if not using viewer
+ Viewer: Mission list retains sort order when swapping between characters

Version 1.1.0
+ UI mod update only; missions are missions, the offline tool didn't care about the differences
+ Agent missions have been monkey wrenched in (thank you Amir, please excuse the screaming)
+ Ingame lair cooldowns should now more accurately reflect the mission journal
+ Looks before it leaps; attempts to detect any game updates that would conflict with the lockout window edits before making them

Version 1.0.0
+ Lairs are listed in the lockout timer window (shift-l)
+ Mod saves mission cooldowns on completion, on logout, and intermittently during play
+ Tool to view these cooldowns outside of the game

## Known Issues & Further Developments
+ Still some strange update behaviours being reported, if you see an AppLog.txt file created it might have some info to help track them down
  + CDs that report as ready when they aren't or vice versa
  + Problems toggling agents between on mission and incapacitated
  + I seem to have a 30s lag comparing the server timeouts to those in the app, uncertain why this is
+ There may be an issue login alerts won't appear if you go back to character select from in-game
  + Thought I saw it, but have been unable to reproduce, suspect it would only occur after a /reloadui

Possible future features:
+ Compact list of mission cooldowns as a secondary tab on the timer window, like days of yore
+ Lookup tables could make several features viable:
  + Extended mission info (zone and questgiver would be handy at the very least)
  + Mission pinning/favourites, selectively displaying missions even with no cooldown data
  + Minimization of saved data sizes, reducing risk of setting file bloat
  + Would require updates as new missions come out
    + There is a slightly complicated method of turning it into a self-learning system
	+ May require a UAC prompt from the viewer to implement though

As always, defect reports, suggestions, and contributions are welcome. The official forum post is great, but I also keep track of the CurseForge and GitHub comments, or find me on the SWL discord or via in-game mail @Peloprata.

Forum Topic: https://forums.funcom.com/t/clockwatcher-agent-and-mission-alerts/1600

Source Repository: https://github.com/Earthfiredrake/SWL-Clockwatcher

CurseForge Mirror: https://www.curseforge.com/swlegends/tswl-mods/clockwatcher

## Building from Source
Building from flash requires the SWL API. Existing project files are configured for Flash Pro CS5.5 and VS2017.

Master/Head is the most recent packaged release. Develop/Head is usually a commit or two behind my current test build. As much as possible I try to avoid regressions or broken commits but new features may be incomplete and unstable and there may be additional debug code intended to be removed or disabled prior to release.

For the ingame components, the flash project can be found in the Mod directory. Once built, 'Clockwatcher.swf', 'LoginAlerts.swf', and the contents of 'config' should be copied to the directory 'Clockwatcher' in the game's mod directory. '/reloadui' is sufficient to force the game to load an updated swf or mod data file, but changes to the game config files (*Prefs.xml and Modules.xml) will require a restart of the client and possible deletion of .bxml caches from the mod directory.

The C# project in App is for the offline tool, which does not currently have any particular post-build requirements, and can be run from any location.

## License and Attribution
Copyright (c) 2018 Earthfiredrake <br/>
Software and source released under the MIT License

TSW, SWL, the related APIs, and most graphics elements are copyright (c) 2012 Funcom GmBH<br/>
Used under the terms of the Funcom UI License<br/>

TabContent.cs behaviour copyright (c) Ivan Krivyakov <br/>
Used under the terms of the Apache License 2.0

Alternate audio alerts provided by:
+ Jakfass (vocal version)
+ Mikail (game audio version)

Curseforge icon adapted from CC licensed artwork: <br/>
https://www.flickr.com/photos/double-m2/3938357377 <br/>
https://pixabay.com/en/eye-icon-symbol-look-vision-see-1915455/ <br/>

Special Thanks to:<br/>
The usual suspects (#modding and the giants of yore)
Leogrim for the initial spark
Starfox for the LairCooldowns mod, of which this mod drank deeply
