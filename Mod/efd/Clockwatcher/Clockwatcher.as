// Copyright 2018, Earthfiredrake
// Released under the terms of the MIT License
// https://github.com/Earthfiredrake/SWL-Clockwatcher
//   Lockout timer window hook and lair listing based off LairCooldowns by Starfox
//   https://lomsglobal.com/threads/starfoxs-mod-depository.2517

import gfx.utils.Delegate;

import com.GameInterface.AgentSystem;
import com.GameInterface.AgentSystemAgent;
import com.GameInterface.AgentSystemMission;
import com.GameInterface.DistributedValue;
import com.GameInterface.Game.Character;
import com.GameInterface.Quest;
import com.GameInterface.Quests;
import com.GameInterface.Utils;
import com.Utils.Archive;
import com.Utils.Colors;
import com.Utils.LDBFormat;

import efd.Clockwatcher.lib.LocaleManager;
import efd.Clockwatcher.lib.Mod;

// TODO: Playfield names are slightly unwieldy for lair strings, consider revising

class efd.Clockwatcher.Clockwatcher extends Mod {
/// Initialization
	// Leaving this one as classic, hardly anything in it
	// Stateless mod, minimal subsystems
	private static var ModInfo:Object = {
		// Debug settings at top so that commenting out leaves no hanging ','
		// Trace : true,
		Name : "Clockwatcher",
		Version : "1.1.0"
	};

	public function Clockwatcher(hostMovie:MovieClip) {
		super(ModInfo, hostMovie);
		InitLairMissions();
		Quests.SignalMissionCompleted.Connect(MissionCompleted, this);
		LockoutsDV = DistributedValue.Create("lockoutTimers_window");
		LockoutsDV.SignalChanged.Connect(HookLockoutsWindow, this);
	}

/// Offline cooldown tracking
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
			// Using negative "MissionIDs" (actually zone IDs) to ensure that proxy missions for lairs are unique
			logData.AddEntry("MissionCD", [-(Number(s)), lairs[s], LocaleManager.FormatString("Clockwatcher", "LairName", LDBFormat.LDBGetText("Playfieldnames", lairs[i].zone))].join('|'));
		}

		// Agent Missions
		var agentMissions:Array = AgentSystem.GetActiveMissions();
		for (var i:Number = 0; i < agentMissions.length; ++i) {
			var mID:Number = agentMissions[i].m_MissionId;
			// Also using negative "MissionIDs", in range -1..-3 because there are no viable zones in that range
			logData.AddEntry("MissionCD", [-(i+1), AgentSystem.GetMissionCompleteTime(mID), "Agent: " + AgentSystem.GetAgentOnMission(mID).m_Name].join('|'));
		}

		return logData;
	}

/// Timer window lair tracking
	private function HookLockoutsWindow(dv:DistributedValue):Void {
		if (dv.GetValue()) {
			var content:MovieClip = _root.lockouttimers.m_Window.m_Content;
			if (!content) { setTimeout(Delegate.create(this, HookLockoutsWindow), 40, dv); }
			else { ApplyHook(content); }
		}
	}

	private function ApplyHook(content:MovieClip):Void {
		if (!SanityCheck(content)) {
			ErrorMsg("UI code has changed in a way that conflicts with this mod, modifications to the UI have been cancelled.");
			return;
		}
		content.m_RaidsHeader.text = LocaleManager.FormatString("Clockwatcher", "LockoutSectionTitle", content.m_RaidsHeader.text);
		var proto:MovieClip = content.m_EliteRaid;
		var lairs:Array = GetLairList();
		content.m_Lairs = new Array();
		for (var i:Number = 0; i < lairs.length; ++i) {
			var clip:MovieClip = proto.duplicateMovieClip("m_Lair" + lairs[i].zone, content.getNextHighestDepth());
			clip._x = proto._x;
			clip._y = proto._y + 20 * (i + 1);
			clip.m_Name.text = LocaleManager.FormatString("Clockwatcher", "LairName", LDBFormat.LDBGetText("Playfieldnames", lairs[i].zone));
			clip.m_Expiry = lairs[i].expiry;
			clip.UpdateExpiry = UpdateExpiry;
			content.m_Lairs.push(clip);
		}
		content.SignalSizeChanged.Emit();

		content.UpdateLairs = ContentUpdateLairs;
		content.ClearTimeInterval = proto.ClearTimeInterval;
		content.onUnload = onContentUnload;
		content.m_TimeInterval = setInterval(content, "UpdateLairs", 1000);
		content.UpdateLairs();
	}

	private static function SanityCheck(content:MovieClip):Boolean {
		//if (content._height != 300) { return false; } // Bad test, people might have scaled the window
		if (content.m_RaidsHeader == undefined) { return false; }
		if (content.m_EliteRaid == undefined) { return false; }
		if (content.m_Lairs != undefined) { return false; }
		if (content.m_TimeInterval != undefined) { return false; }
		if (content.SignalSizeChanged == undefined) { return false; }
		if (content.UpdateLairs != undefined) { return false; }
		if (content.ClearTimeInterval != undefined) { return false; }
		if (content.hasOwnProperty("onUnload")) { return false; }
		for (var i:Number = 0; i < LairZones.length; ++i) {
			if (content["m_Lair" + LairZones[i]] != undefined) { return false; }
		}
		return true;
	}

	private static function GetLairList():Array {
		var lairs:Object = new Object;
		var cdQuests:Array = Quests.GetAllQuestsOnCooldown();
		for (var i:Number = 0; i < cdQuests.length; ++i) {
			var q = cdQuests[i];
			if (LairMissions[q.m_ID]) {
				lairs[LairMissions[q.m_ID]] = lairs[LairMissions[q.m_ID]] ?
				Math.max(lairs[LairMissions[q.m_ID]], q.m_CooldownExpireTime):
				q.m_CooldownExpireTime;
			}
		}
		// Sort result based on zone
		var listed:Array = new Array();
		for (var i:Number = 0; i < LairZones.length; ++i) {
			listed.push({zone : LairZones[i], expiry : lairs[LairZones[i]]});
		}
		return listed;
	}

	// Called in context of LockoutTimersContent movieclip
	private function onContentUnload():Void {
		var target:Object = this;
		target.ClearTimeInterval();
		target.super.onUnload();
	}

	private function ContentUpdateLairs():Void {
		var target:Object = this;
		var allClear:Boolean = true;
		var time:Number = Utils.GetServerSyncedTime();
		for (var i:Number = 0; i < target.m_Lairs.length; ++i) {
			allClear = allClear && target.m_Lairs[i].UpdateExpiry(time);
		}
		if (allClear) { target.ClearTimeInterval(); }
	}

	// Called in context of Lair LockoutEntry movieclip
	// Time is in seconds
	private function UpdateExpiry(time:Number):Boolean {
		var target:Object = this;
		var timeStr:String = FormatRemainingTime(target.m_Expiry, time);
		if (timeStr) { target.m_Lockout.text = timeStr; }
		else {
			target.m_Lockout.textColor = Colors.e_ColorGreen;
			target.m_Lockout.text = LDBFormat.LDBGetText("MiscGUI", "LockoutTimers_Available");
			return true;
		}
		return false;
	}

	// Input times are both in seconds
	private static function FormatRemainingTime(expiry:Number, time:Number):String {
		if (!expiry) { return undefined; }
		var remaining:Number = Math.floor(expiry - time);
		if (remaining <= 0) { return undefined; }
		var hours:String = String(Math.floor(remaining / 3600));
		if (hours.length == 1) { hours = "0" + hours; }
		var minutes:String = String(Math.floor((remaining / 60) % 60));
		if (minutes.length == 1) { minutes = "0" + minutes; }
		var seconds:String = String(Math.floor(remaining % 60));
		if (seconds.length == 1) { seconds = "0" + seconds; }
		return hours + ":" + minutes + ":" + seconds;
	}

/// Variables
	// TODO: These can be offloaded to a datafile
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

	private static var LairZones:Array = [3030, 3040, 3050, 3090, 3100, 3120, 3130, 3140, 3070];
	private static var LairMissions:Object = new Object();
	private var LockoutsDV:DistributedValue;
}
