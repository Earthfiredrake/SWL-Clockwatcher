# SWL-Clockwatcher
Utilities for mission cooldown tracking

## Overview
A collection of tools to help track mission cooldowns:
+ Offline tracking - The mod saves a list of missions on cooldown. Clockwatcher.exe displays the remaining cooldown times without needing to log into the game
+ Lair Timers - Adds lairs to the lockout timer window (shift-l), listing the longest remaining cooldown among missions in that lair.

Note: CurseForge download does not include Clockwatcher.exe. It is available through GitHub as either a separate download, or as part of the main release.

Mission lists are saved per character.

## Installation
The packaged release should be unzipped (including the internal folder) into the listed folder:
<br/>SWL: [SWL Directory]\Data\Gui\Custom\Flash
<br/>TSW: [TSW Directory]\Data\Gui\Customized\Flash (Untested, may have unexpected 'features')

The safest method for upgrading (required for installing) is to have the client closed and delete any existing .bxml files in the mod directory. Hotpatching (using /reloadui) works as long as neither Modules.xml or LoginPrefs.xml have changed.

Clockwatcher.exe requires v4.6 of the .net framework to be installed which can be downloaded from Microsoft if needed. It will not have any content until the mod has had an opportunity to save some data.

## Usage Notes
+ Each lair's missions share a single entry in both the timer window and offline tracking tool, and the listed time is the longest of those missions' cooldowns
+ Clockwatcher.exe automatically does a minor refresh to update the time display, but will only load new data on manual refreshes. This merges new data with that already loaded, retaining any "Ready!" missions until the program exits
+ Cooldowns seem to be tweaked occasionally by the server. Values provided by this mod, particularly while offline, should be considered estimates, usually accurate to within a minute or two.

## Change Log
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
As this is new there may be some bugs in it. Please let me know if you run into them.

Possible future features:
+ Should probably add Incapacitated agents to the tracking too, but I'll wait until they're actually working right
+ Lookup tables could make several features viable:
  + Extended mission info (zone and questgiver would be handy at the very least)
  + Mission pinning/favourites, selectively displaying missions with no cooldown data
  + Minimization of saved data sizes reduces the risk of setting file bloat
  + Would require updates as new missions come out
    + There is a slightly complicated method of turning it into a self-learning system
	+ May require a UAC prompt to implement though
+ Compact list of mission cooldowns as a secondary tab on the timer window, like days of yore

As always, defect reports, suggestions, and contributions are welcome. Message Peloprata in #modding on the SWL discord, or in-game by mail or pm, or leave a message on CurseForge or GitHub.

Source Repository: https://github.com/Earthfiredrake/SWL-Clockwatcher

CurseForge Mirror: https://www.curseforge.com/swlegends/tswl-mods/clockwatcher

## Building from Source
Building from flash requires the SWL API. Existing project files are configured for Flash Pro CS5.5 and VS2017.

Master/Head is the most recent packaged release. Develop/Head is usually a commit or two behind my current test build. As much as possible I try to avoid regressions or broken commits but new features may be incomplete and unstable and there may be additional debug code intended to be removed or disabled prior to release.

For the ingame components, the flash project can be found in the Mod directory. Once built, 'Clockwatcher.swf', and the contents of 'config' should be copied to the directory 'Clockwatcher' in the game's mod directory. '/reloadui' is sufficient to force the game to load an updated swf or mod data file, but changes to the game config files (CharPrefs.xml and Modules.xml) will require a restart of the client and possible deletion of .bxml caches from the mod directory.

The C# project in App is for the offline tool, which does not currently have any particular post-build requirements, and can be run from any location.

## License and Attribution
Copyright (c) 2018 Earthfiredrake<br/>
Software and source released under the MIT License

TSW, SWL and the related API are copyright (c) 2012 Funcom GmBH<br/>

Curseforge icon adapted from CC licensed artwork: <br/>
https://www.flickr.com/photos/double-m2/3938357377 <br/>
https://pixabay.com/en/eye-icon-symbol-look-vision-see-1915455/ <br/>

Special Thanks to:<br/>
The usual suspects (#modding and the giants of yore)
Leogrim for the initial spark
Starfox for the LairCooldowns mod, of which this mod drank deeply
