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
import com.GameInterface.Lore;
import com.GameInterface.Quest;
import com.GameInterface.Quests;
import com.GameInterface.Utils;
import com.Utils.Archive;
import com.Utils.Colors;
import com.Utils.LDBFormat;

import GUI.LoginCharacterSelection.CharacterListItemRenderer;

import efd.Clockwatcher.lib.LocaleManager;
import efd.Clockwatcher.lib.Mod;

import efd.Clockwatcher.AgentNotification;
import efd.Clockwatcher.lib.etu.MovieClipHelper;

// TODO: Playfield names are slightly unwieldy for lair strings, consider revising

class efd.Clockwatcher.Clockwatcher extends Mod {
/// Initialization
	// Leaving this one as classic, hardly anything in it
	// Stateless mod, minimal subsystems
	private static var ModInfo:Object = {
		// Debug setting at top so that commenting out leaves no hanging ','
		// Debug : true,
		Name : "Clockwatcher",
		Version : "1.2.0"
	};

	public function Clockwatcher(hostMovie:MovieClip) {
		super(ModInfo, hostMovie);
		InitLairMissions();

		OfflineExportDV = DistributedValue.Create(DVPrefix + ModName + "OfflineExport");

		LockoutsDV = DistributedValue.Create("lockoutTimers_window");
		LockoutsDV.SignalChanged.Connect(HookLockoutsWindow, this);

		HookCharSelect();
		AgentSystem.SignalActiveMissionsUpdated.Connect(UpdateAgentEvents, this);
		AgentSystem.SignalAgentStatusUpdated.Connect(UpdateAgentEvents, this);

		Quests.SignalMissionCompleted.Connect(SerializeMissions, this);
		AgentSystem.SignalActiveMissionsUpdated.Connect(SerializeMissions, this);
	}

	// Despite my best guesses I'm not getting an enable call until I log in
	//   Advantage: I don't need to worry overly much about writing to a logged out character's settings
	//   Disadvantage: Going to have to do all my hooking onLoad and fetch the config archive manually
	//   Decided to go with manual config instead of the framework version for now
	public function GameToggleModEnabled(state:Boolean, archive:Archive) {
		if (!state) {
			SerializeMissions();
			SerializeGlobal();
		} else {
			OfflineExportDV.SetValue(DistributedValue.GetDValue(DVPrefix + ModName + "Global").FindEntry("OfflineExport", true));
			GetAgentEvent(); // Ensuring that it's cached after a /reloadui
		}
		return super.GameToggleModEnabled(state, archive);
	}

	private function SerializeGlobal():Void {
		var archive:Archive = new Archive();
		archive.ReplaceEntry("OfflineExport", OfflineExportDV.GetValue());
		for (var char:String in AgentEvents) {
			archive.AddEntry("AgentEvent", char + "|" + AgentEvents[char].toString());
		}
		DistributedValue.SetDValue(DVPrefix + ModName + "Global", archive);
	}

/// Offline cooldown tracking
	private function SerializeMissions():Void {
		TraceMsg("Updating mission list");
		if (!OfflineExportDV.GetValue()) { return; }
		// Uses default array serialization and no actual persisting state
		var outArchive:Archive = new Archive();
		outArchive.AddEntry("CharName", Character.GetClientCharacter().GetName());
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
				outArchive.AddEntry("MissionCD", [q.m_ID, q.m_CooldownExpireTime, q.m_MissionName].join('|'));
			}
		}
		for (var s:String in lairs) {
			// Using negative "MissionIDs" (actually zone IDs) to ensure that proxy missions for lairs are unique
			outArchive.AddEntry("MissionCD", [-(Number(s)), lairs[s], LocaleManager.FormatString("Clockwatcher", "LairName", LDBFormat.LDBGetText("Playfieldnames", lairs[i].zone))].join('|'));
		}

		// Agent Missions
		var agentMissions:Array = AgentSystem.GetActiveMissions();
		for (var i:Number = 0; i < agentMissions.length; ++i) {
			var mID:Number = agentMissions[i].m_MissionId;
			// Also using negative "MissionIDs", in range -1..-3 because there are no viable zones in that range
			outArchive.AddEntry("MissionCD", [-(i+1), AgentSystem.GetMissionCompleteTime(mID), "Agent: " + AgentSystem.GetAgentOnMission(mID).m_Name].join('|'));
		}

		DistributedValue.SetDValue(DVPrefix + ModName + "MissionList", outArchive);
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

/// Character select agent notifications
	private function HookCharSelect():Void {
		if (CharacterListItemRenderer.prototype == undefined) { Mod.LogMsg("Uhoh"); return; }
		if (CharacterListItemRenderer.prototype._UpdateVisuals == undefined) {
			CharacterListItemRenderer.prototype._UpdateVisuals = CharacterListItemRenderer.prototype["UpdateVisuals"];
			CharacterListItemRenderer.prototype["UpdateVisuals"] = function():Void {
				this._UpdateVisuals();
				if (this.data == undefined || this.data.m_CreateCharacter) { return; }
				var agentEventTime = Clockwatcher.GetAgentEvent(this.data.m_Id);
				if (agentEventTime != undefined && agentEventTime <= Utils.GetServerSyncedTime()) {
					var agentAlert:MovieClip = this.createEmptyMovieClip("AgentAlert", this.getNextHighestDepth());
					agentAlert.loadMovie("Clockwatcher\\gfx\\AgentAlert.png");
					agentAlert._x = 10;
					agentAlert._y = this.m_Level._y + 19;
				}
			};
		}
	}

	// If done onLoad the mod won't have access to the settings yet
	// Waiting until onActivate requires it to finish logging in, which is no more useful
	// Trying for a lazy load, it had better exist when I need it
	public static function GetAgentEvent(charID:Number):Object {
		if (AgentEvents == undefined) {
			AgentEvents = new Object();
			var agentTimes:Array = DistributedValue.GetDValue(DVPrefix + "ClockwatcherGlobal").FindEntryArray("AgentEvent");
			for (var i:Number = 0; i < agentTimes.length; ++i) {
				var split:Array = agentTimes[i].split('|');
				AgentEvents[split[0]] = Number(split[1]);
			}
		}
		return AgentEvents[charID];
	}

	private function UpdateAgentEvents():Void {
		AgentEvents[Character.GetClientCharID().m_Instance] = NextAgentEventTime();
		SerializeGlobal();
	}

	// Returns the lowest of: Completion times for active missions and recovery times for agents (to fill an open mission slot)
	// Undefined if there are no agents
	// Assumes that it is impossible to totally drain the mission pool
	private function NextAgentEventTime():Number {
		var unlockedSlots:Number = Lore.IsLocked(10638) ? 1 : 2;
		unlockedSlots += Character.GetClientCharacter().IsMember() ? 1 : 0;
		var activeMissions:Array = AgentSystem.GetActiveMissions();
		var agents:Array = AgentSystem.GetAgents();
		if (!agents.length) { return undefined; }

		var eventTime:Number = Number.POSITIVE_INFINITY;
		for (var i:Number = 0; i < activeMissions.length; ++i) {
			eventTime = Math.min(eventTime, AgentSystem.GetMissionCompleteTime(activeMissions[i].m_MissionId));
		}

		// Open mission slot, see if there's any agents able to fill it, or if one will recover from fatigue before a mission ends
		if (activeMissions.length < unlockedSlots) {
			for (var i:Number = 0; i < agents.length; ++i) {
				var agentID:Number = agents[i].m_AgentId;
				if (!AgentSystem.HasAgent(agentID) || AgentSystem.IsAgentOnMission(agentID)) { continue; } // Mission timess are already accounted for
				if (AgentSystem.IsAgentFatigued(agentID)) { eventTime = Math.min(eventTime, AgentSystem.GetAgentRecoverTime(agentID)); }
				else { return 0; } // Agent and open mission available
			}
		}

		if (eventTime == Number.POSITIVE_INFINITY) { TraceMsg("Next agent event time is infinite"); }
		return eventTime;
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

	private static var AgentEvents:Object; // [charID] = eventTime map

	private var OfflineExportDV:DistributedValue;
}
