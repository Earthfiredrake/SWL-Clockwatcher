# SWL-CDTracker
Utilities for mission cooldown tracking

## Overview
A collection of tools to help track mission cooldowns:
  Offline tracking - The mod saves the missions on cooldown before a character logs out. CDTracker.exe can be run from outside of the game to view the remaining time on these missions.

The mod is currently a proof of concept. It should work, but features are sparse and major changes are likely.

Settings are saved per character, as each has their own list of missions.

## Installation
The packaged release should be unzipped (including the internal folder) into the listed folder:
<br/>SWL: [SWL Directory]\Data\Gui\Custom\Flash
<br/>TSW: [TSW Directory]\Data\Gui\Customized\Flash

The safest method for upgrading (required for installing) is to have the client closed and delete any existing .bxml files in the LoreHound directory. Hotpatching (using /reloadui) works as long as neither Modules.xml or LoginPrefs.xml have changed.

CDTracker.exe requires v4.6 of the .net framework to be installed which can be downloaded from Microsoft if needed. Characters will not be listed until they have had some data saved by the mod. Logging a character in and doing a '/reloadui' will force an update of saved data, and can be used to quickly verify that things are properly installed. For convenience make a shortcut to CDTracker.exe instead of moving the executable; while not currently an issue, future features may expect it to share the directory with the mod.

I intend to permit setting migration from the first public beta to v1.0.x, but this may be subject to change. As with my other mods, this update compatibility window will occasionally be shifted to reduce legacy code clutter.

## Change Log

Version Next
+ Proof of concept
+ Tracking mod saves mission data (semi-regular snapshots during play (in case of crashes), and before logging out)
+ Offline tool loads and displays the data

## Known Issues

Mod:
+ There is a lack of notifications for pretty much everything

App:
+ Time Left displays and sorts oddly for cooldowns > 1 day and expired cooldowns
+ There's a few other slightly off behaviours in the UI

This is a very early version of this mod. Everything is an issue, some of them are known.
I'm always open to hearing comments and suggestions though, better to start with the good ideas than rewrite from the bad ones.

## Testing and Further Developments

Possible future features:
+ A lookup table could make several features viable:
  + Extended mission info (zone and questgiver would be handy at the very least)
  + Mission pinning/favourites, selectively displaying the list of missions with no-cd
  + Minimization of saved data sizes reduces the risk of setting file bloat
  + Would require updates as new missions come out, though that could be automated (UAC prompt from the app)
+ Lair cooldowns added to the in-game refresh and cooldown timer window.

As always, defect reports, suggestions, and contributions are welcome. Message Peloprata in #modding on the SWL discord, or in-game by mail or pm, or leave a message on the Curse or GitHub page.

Source Repository: https://github.com/Earthfiredrake/SWL-CDTracker

Curse Mirror: TBD

## Building from Source
Building from flash requires the SWL API. Existing project files are configured for Flash Pro CS5.5 and VS2017.

Master/Head is the most recent packaged release. Develop/Head is usually a commit or two behind my current test build. As much as possible I try to avoid regressions or broken commits but new features may be incomplete and unstable and there may be additional debug code intended to be removed or disabled prior to release.

For the ingame components, the flash project can be found in the Mod directory. Once built, 'CDTracker.swf', and the contents of 'config' should be copied to the directory 'CDTracker' in the game's mod directory. '/reloadui' is sufficient to force the game to load an updated swf or mod data file, but changes to the game config files (CharPrefs.xml and Modules.xml) will require a restart of the client and possible deletion of .bxml caches from the mod directory.

The C# project in App is for the offline tool, which does not currently have any particular post-build requirements, and can be run from any location.

## License and Attribution
Copyright (c) 2018 Earthfiredrake<br/>
Software and source released under the MIT License

TSW, SWL and the related API are copyright (c) 2012 Funcom GmBH<br/>

Special Thanks to:<br/>
The usual suspects (#modding and the giants of yore)
Leogrim for the initial spark
