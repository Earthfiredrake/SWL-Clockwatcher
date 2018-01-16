// Copyright 2018, Earthfiredrake
// Released under the terms of the MIT License
// https://github.com/Earthfiredrake/SWL-CDTracker

import com.GameInterface.Game.Character;
import com.GameInterface.Log;
import com.GameInterface.Quest;
import com.GameInterface.Quests;
import com.GameInterface.Utils;
import com.Utils.Archive;

var DebugTrace:Boolean = true;

function TraceMsg(message:String, options:Object):Void {
	// Debug messages, should be independent of localization system to allow traces before it loads
	if (DebugTrace) {
		if (!options.noPrefix) {
			var sysPrefix:String = options.system ? (options.system + " - ") : "";
			message = "<font color='#FFB555'> CDTracker </font>: Trace - " + sysPrefix + message;
		}
		Utils.PrintChatText(message);
	}
}
function LogMsg(message:String, noTrace:Boolean):Void { 
	if (!noTrace) { TraceMsg(message, {system : "Log"}); }
	Log.Error("CDTracker", message);
}

function onLoad():Void {}
function OnModuleActivated(archive:Archive):Void {}
function OnModuleDeactivated():Archive {
	var logData:Archive = new Archive();
	logData.AddEntry("CharName", Character.GetClientCharacter().GetName());
	var cdQuests:Array = Quests.GetAllQuestsOnCooldown(); // Uncertain if no-repeat quests can end up in this list
	for (var i:Number = 0; i < cdQuests.length; ++i) {
		var q:Quest = cdQuests[i];
		// Cooldown expiries are in Unix std time format
		logData.AddEntry("MissionCD", [q.m_ID, q.m_CooldownExpireTime, q.m_MissionName].join('|'));
	}	
	return logData;
}
function OnUnload():Void {}
