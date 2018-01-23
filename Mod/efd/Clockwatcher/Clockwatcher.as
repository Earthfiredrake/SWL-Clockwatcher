// Copyright 2018, Earthfiredrake
// Released under the terms of the MIT License
// https://github.com/Earthfiredrake/SWL-Clockwatcher

import com.GameInterface.DistributedValue;
import com.GameInterface.Game.Character;
import com.GameInterface.Quest;
import com.GameInterface.Quests;
import com.Utils.Archive;
import com.Utils.LDBFormat;

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

	public function Clockwatcher(hostMovie:MovieClip) {
		super(ModInfo, hostMovie);
		InitLairMissions();
		Quests.SignalMissionCompleted.Connect(MissionCompleted, this);
	}

	public function GameToggleModEnabled(state:Boolean, archive:Archive) {
		if (!state) {
			super.GameToggleModEnabled(state);
			return GetMissionList();
		} else { super.GameToggleModEnabled(state, archive); }
	}

	private function MissionCompleted(missionID:Number):Void {
		DistributedValue.SetDValue("efdClockwatcherConfig", GetMissionList());
	}

	private static function GetMissionList():Archive {
		// Uses default array serialization and no actual persisting state
		var logData:Archive = new Archive();
		logData.AddEntry("CharName", Character.GetClientCharacter().GetName());
		var lairs:Object = new Object();
		var cdQuests:Array = Quests.GetAllQuestsOnCooldown(); // Uncertain if no-repeat quests can end up in this list
		for (var i:Number = 0; i < cdQuests.length; ++i) {
			var q:Quest = cdQuests[i];
			if (LairMissions[q.m_ID]) {
				lairs[LairMissions[q.m_ID]] = lairs[LairMissions[q.m_ID]] ?
					Math.max(lairs[LairMissions[q.m_ID]], q.m_CooldownExpireTime) :
					q.m_CooldownExpireTime;
			} else {
				// Cooldown expiries are in Unix std time format
				logData.AddEntry("MissionCD", [q.m_ID, q.m_CooldownExpireTime, q.m_MissionName].join('|'));
			}
		}
		for (var s:String in lairs) {
			// Using negative MissionIDs to ensure that proxy missions for lairs are unique
			logData.AddEntry("MissionCD", [-(Number(s)), lairs[s], LDBFormat.LDBGetText("Playfieldnames", Number(s)) + " Lair"].join('|'));
		}
		return logData;
	}

	private static function InitLairMissions():Void {
		LairMissions["3434"] = 3030;
		LairMissions["3445"] = 3030;
		LairMissions["3422"] = 3030;
		LairMissions["3446"] = 3040;
		LairMissions["3436"] = 3040;
		LairMissions["3423"] = 3040;
		LairMissions["3447"] = 3050;
		LairMissions["3424"] = 3050;
		LairMissions["3439"] = 3050;
		LairMissions["3448"] = 3090;
		LairMissions["3426"] = 3090;
		LairMissions["3428"] = 3090;
		LairMissions["3449"] = 3100;
		LairMissions["3425"] = 3100;
		LairMissions["3429"] = 3100;
		LairMissions["3413"] = 3120;
		LairMissions["3412"] = 3120;
		LairMissions["3411"] = 3120;
		LairMissions["3415"] = 3130;
		LairMissions["3416"] = 3130;
		LairMissions["3421"] = 3130;
		LairMissions["3418"] = 3140;
		LairMissions["3419"] = 3140;
		LairMissions["3414"] = 3140;
		LairMissions["4056"] = 3070;
		LairMissions["4054"] = 3070;
		LairMissions["4064"] = 3070;
	}

	private static var LairMissions:Object = new Object();
}
