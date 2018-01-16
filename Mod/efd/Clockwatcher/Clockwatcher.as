// Copyright 2018, Earthfiredrake
// Released under the terms of the MIT License
// https://github.com/Earthfiredrake/SWL-Clockwatcher

import com.GameInterface.Game.Character;
import com.GameInterface.Quest;
import com.GameInterface.Quests;
import com.Utils.Archive;

import efd.Clockwatcher.lib.Mod;

class efd.Clockwatcher.Clockwatcher extends Mod {
	private static var ModInfo:Object = {
		// Debug settings at top so that commenting out leaves no hanging ','
		// Trace : true,
		GuiFlags : ef_ModGui_NoIcon | ef_ModGui_NoConfigWindow, // ef_ModGui_Console
		// ERM??? not sure how to categorize it
		//  Currently it's pretty much passive, it just sits there and creates settings
		//  Intended features add a mixture of reactive and interface
		Type : e_ModType_Reactive,
		Name : "Clockwatcher",
		Version : "0.0.1.alpha"
	};
	
	public function Clockwatcher(hostMovie:MovieClip) {	super(ModInfo, hostMovie); }
	
	public function GameToggleModEnabled(state:Boolean, archive:Archive) {
		if (!state) {
			// Append mission cooldowns into the settings archive
			// Bypasses ConfigWrapper to use default array serialization
			var logData:Archive = super.GameToggleModEnabled(state);
			logData.AddEntry("CharName", Character.GetClientCharacter().GetName());
			var cdQuests:Array = Quests.GetAllQuestsOnCooldown(); // Uncertain if no-repeat quests can end up in this list
			for (var i:Number = 0; i < cdQuests.length; ++i) {
				var q:Quest = cdQuests[i];
				// Cooldown expiries are in Unix std time format
				logData.AddEntry("MissionCD", [q.m_ID, q.m_CooldownExpireTime, q.m_MissionName].join('|'));
			}
			return logData;
		} else { super.GameToggleModEnabled(state, archive); }
	}
}
