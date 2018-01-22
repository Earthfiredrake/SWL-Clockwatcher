// Copyright 2018, Earthfiredrake
// Released under the terms of the MIT License
// https://github.com/Earthfiredrake/SWL-Clockwatcher

import com.GameInterface.Game.Character;
import com.GameInterface.Quest;
import com.GameInterface.Quests;
import com.Utils.Archive;

import efd.Clockwatcher.lib.Mod;

class efd.Clockwatcher.Clockwatcher extends Mod {
/// Initialization
	// Leaving this one as classic, hardly anything in it
	// Stateless mod, minimal subsystems
	private static var ModInfo:Object = {
		// Debug settings at top so that commenting out leaves no hanging ','
		// Trace : true,
		Name : "Clockwatcher",
		Version : "0.0.1.alpha"
	};

	public function Clockwatcher(hostMovie:MovieClip) {	super(ModInfo, hostMovie); }

	public function GameToggleModEnabled(state:Boolean, archive:Archive) {
		if (!state) {
			super.GameToggleModEnabled(state);
			// Uses default array serialization and no actual persisting state
			var logData:Archive = new Archive();
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
