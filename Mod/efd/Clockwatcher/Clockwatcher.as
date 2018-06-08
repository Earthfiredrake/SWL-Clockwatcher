// Copyright 2018, Earthfiredrake
// Released under the terms of the MIT License
// https://github.com/Earthfiredrake/SWL-Clockwatcher
//   Lockout timer window hook and lair listing based off LairCooldowns by Starfox
//   https://lomsglobal.com/threads/starfoxs-mod-depository.2517

import gfx.utils.Delegate;

import com.GameInterface.AccountManagement;
import com.GameInterface.AgentSystem;
import com.GameInterface.AgentSystemAgent;
import com.GameInterface.AgentSystemMission;
import com.GameInterface.DistributedValue;
import com.GameInterface.Game.Character;
import com.GameInterface.Game.TeamInterface;
import com.GameInterface.GroupFinder;
import com.GameInterface.Lore;
import com.GameInterface.Quest;
import com.GameInterface.Quests;
import com.GameInterface.Utils;
import com.Utils.Archive;
import com.Utils.Colors;
import com.Utils.LDBFormat;
import GUIFramework.SFClipLoader;

import efd.Clockwatcher.lib.DebugUtils;
import efd.Clockwatcher.lib.LocaleManager;
import efd.Clockwatcher.lib.Mod;

// TODO: Playfield names are slightly unwieldy for lair strings, consider revising

class efd.Clockwatcher.Clockwatcher extends Mod {
/// Initialization
	// Leaving this one as classic, hardly anything in it
	private static var ModInfo:Object = {
		// Debug setting at top so that commenting out leaves no hanging ','
		// Debug : true,
		Name : "Clockwatcher",
		Version : "1.3.1"
	};

	public function Clockwatcher(hostMovie:MovieClip) {
		super(ModInfo, hostMovie);
		SystemsLoaded.Data = false;
		DataFile = LoadXmlAsynch("ModData", Delegate.create(this, ParseModData));

		LockoutsDV = DistributedValue.Create("lockoutTimers_window");
		LockoutsDV.SignalChanged.Connect(HookLockoutsWindow, this);

		OfflineExportDV = DistributedValue.Create(DVPrefix + ModName + "OfflineExport");
		OfflineExportDV.SignalChanged.Connect(ToggleOfflineData, this);

		LoginAlertsDV = DistributedValue.Create(DVPrefix + ModName + "LoginAlerts");
		if (_root.clockwatcherLoginAlerts == undefined) {
			SFClipLoader.LoadClip("Clockwatcher/LoginAlerts.swf", "clockwatcherLoginAlerts", false, _global.Enums.ViewLayer.e_ViewLayerTop, 4);
		}

		GroupFinderPopDV = DistributedValue.Create("groupFinder_readyPrompt");
		GroupFinderPopDV.SignalChanged.Connect(GroupPopAlert, this);
	}

	// Despite my best guesses I'm not getting an enable call until I log in
	//   Advantage: I don't need to worry overly much about writing to a logged out character's settings
	//   Disadvantage: Going to have to do all my hooking onLoad and fetch the config archive manually when needed
	//   Decided to go with manual config instead of the framework version for now
	public function GameToggleModEnabled(state:Boolean, archive:Archive) {
		if (state) {
			var globalSettings:Archive = DistributedValue.GetDValue(DVPrefix + ModName + "Global");
			OfflineExportDV.SetValue(globalSettings.FindEntry("OfflineExport", true));
			LoginAlertsDV.SetValue(globalSettings.FindEntry("LoginAlerts", true));
			GetOfflineAgentEvent(); // Ensuring that it's cached after a /reloadui so that it is serialized properly
			AgentSystem.SignalActiveMissionsUpdated.Connect(UpdateAgentEvents, this);
			AgentSystem.SignalMissionCompleted.Connect(UpdateAgentEvents, this);
			AgentSystem.SignalAgentStatusUpdated.Connect(UpdateAgentEvents, this);
		} else {
			AgentSystem.SignalActiveMissionsUpdated.Disconnect(UpdateAgentEvents, this);
			AgentSystem.SignalMissionCompleted.Disconnect(UpdateAgentEvents, this);
			AgentSystem.SignalAgentStatusUpdated.Disconnect(UpdateAgentEvents, this);
			SerializeGlobal();
			if (OfflineExportDV.GetValue()) { SerializeOfflineData(); }
			else { DistributedValue.SetDValue(DVPrefix + ModName + "MissionList", null); }
			OfflineExportDV.SetValue(false); // Toggling this when the mod is off ensures that the signals are properly reconnected when changing characters?
		}
		return super.GameToggleModEnabled(state, archive);
	}

	private function SerializeGlobal():Void {
		var archive:Archive = new Archive();
		archive.AddEntry("OfflineExport", OfflineExportDV.GetValue());
		archive.AddEntry("LoginAlerts",  LoginAlertsDV.GetValue());
		for (var char:String in AgentEvents) {
			archive.AddEntry("AgentEvent", char + "|" + AgentEvents[char].toString());
		}
		DistributedValue.SetDValue(DVPrefix + ModName + "Global", archive);
	}

/// Offline cooldown tracking
	private function ToggleOfflineData(dv:DistributedValue):Void {
		if (dv.GetValue()) {
			Quests.SignalMissionCompleted.Connect(SerializeOfflineData, this);
			AgentSystem.SignalActiveMissionsUpdated.Connect(SerializeOfflineData, this);
			AgentSystem.SignalMissionCompleted.Connect(SerializeOfflineData, this);
			AgentSystem.SignalAgentStatusUpdated.Connect(SerializeOfflineData, this);
		} else {
			Quests.SignalMissionCompleted.Disconnect(SerializeOfflineData, this);
			AgentSystem.SignalActiveMissionsUpdated.Disconnect(SerializeOfflineData, this);
			AgentSystem.SignalMissionCompleted.Disconnect(SerializeOfflineData, this);
			AgentSystem.SignalAgentStatusUpdated.Disconnect(SerializeOfflineData, this);
		}
	}

	private function SerializeOfflineData():Void {
		if (AccountManagement.GetInstance().GetLoginState() == _global.Enums.LoginState.e_LoginStateWaitingForGameServerConnection) { return; } // Client has DCed from server which will cause a crash when accessing the Agent system, avoid it by skipping the update
		var outArchive:Archive = new Archive();
		outArchive.AddEntry("CharName", Character.GetClientCharacter().GetName());
		var lairs:Object = new Object();
		var cdQuests:Array = Quests.GetAllQuestsOnCooldown(); // Uncertain if no-repeat quests can end up in this list
		for (var i:Number = 0; i < cdQuests.length; ++i) {
			var q:Quest = cdQuests[i];
			if (q.m_ID < 1000) { Debug.DevMsg("Quest: " + q.m_MissionName + "(ID: " + q.m_ID + ") may conflict with agent ID range"); }
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
			// Using negative "MissionIDs" (actually zone IDs) to ensure that proxy missions for lairs are unique (zoneIDs have collisions with missionIDs)
			outArchive.AddEntry("MissionCD", [-(Number(s)), lairs[s], LocaleManager.FormatString("Clockwatcher", "LairName", LDBFormat.LDBGetText("Playfieldnames", Number(s)))].join('|'));
		}

		// Agent IDs do not conflict with mission IDs, so make use of their given range
		//   (dev warnings are issued if an ID is found to be in potentially overlapping range)
		// Since being on a mission and incapped are exclusive possibilities, there should be no issue with sharing the same (unique/agent) IDs
		// Agent Missions
		var agentMissions:Array = AgentSystem.GetActiveMissions();
		for (var i:Number = 0; i < agentMissions.length; ++i) {
			var mID:Number = agentMissions[i].m_MissionId;
			var agent:AgentSystemAgent = AgentSystem.GetAgentOnMission(mID);
			outArchive.AddEntry("AgentCD", [agent.m_AgentId, AgentSystem.GetMissionCompleteTime(mID), agent.m_Name, false].join('|'));
		}
		// Incapacitated Agents
		var agents:Array = AgentSystem.GetAgents();
		for (var i:Number = 0; i < agents.length; ++i) {
			var agent:AgentSystemAgent = agents[i];
			var aID:Number = agent.m_AgentId;
			if (aID <= 1000) { Debug.DevMsg("Agent: " + agent.m_Name + "(ID: " + aID + ") may conflict with quest ID range"); }
			if (AgentSystem.IsAgentFatigued(aID)) { outArchive.AddEntry("AgentCD", [aID, AgentSystem.GetAgentRecoverTime(aID), agent.m_Name, true].join('|')); }
		}

		DistributedValue.SetDValue(DVPrefix + ModName + "MissionList", outArchive);
	}

/// Timer window lair tracking
	private function HookLockoutsWindow(dv:DistributedValue):Void {
		if (!dv.GetValue()) { return; }
		var content:MovieClip = _root.lockouttimers.m_Window.m_Content;
		if (!content) { setTimeout(Delegate.create(this, HookLockoutsWindow), 40, dv); }
		else { ApplyHook(content); }
	}

	private function ApplyHook(content:MovieClip):Void {
		if (!SanityCheck(content)) {
			Debug.ErrorMsg("UI code has changed in a way that conflicts with this mod, modifications to the UI have been cancelled.");
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
			allClear = target.m_Lairs[i].UpdateExpiry(time) && allClear;
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

	// If done onLoad the mod won't have access to the settings yet
	//   Waiting until onActivate requires it to finish logging in, which is no more useful
	//   Trying for a lazy load, it had better exist when I need it
	// Loading into static/_global as the ClockWatcher instance is destroyed when logging out
	//   Could load it into LoginAlerts, which might make sense, but then it would need update logic or cross serialization anyway
	public static function GetOfflineAgentEvent(charID:Number):Number {
		var globalSettings:Archive = DistributedValue.GetDValue(DVPrefix + "ClockwatcherGlobal");
		var agentTimes:Array = globalSettings.FindEntryArray("AgentEvent");
		if (AgentEvents == undefined && agentTimes != undefined) {
			AgentEvents = new Object();
			for (var i:Number = 0; i < agentTimes.length; ++i) {
				var split:Array = agentTimes[i].split('|');
				AgentEvents[split[0]] = Number(split[1]);
			}
		}
		return globalSettings.FindEntry("LoginAlerts", true) ? AgentEvents[charID] : undefined;
	}

	private function UpdateAgentEvents():Void {
		AgentEvents[Character.GetClientCharID().m_Instance] = NextAgentEventTime();
		SerializeGlobal();
	}

	// Returns the lowest of: Completion times for active missions and recovery times for agents (to fill an open mission slot)
	// Undefined if there are no unlocked agents
	// Assumes that it is impossible to totally drain the mission pool
	private function NextAgentEventTime():Number {
		var unlockedSlots:Number = Lore.IsLocked(10638) ? 1 : 2;
		unlockedSlots += Character.GetClientCharacter().IsMember() ? 1 : 0;
		var activeMissions:Array = AgentSystem.GetActiveMissions();
		var agents:Array = AgentSystem.GetAgents();

		var eventTime:Number = Number.POSITIVE_INFINITY;
		for (var i:Number = 0; i < activeMissions.length; ++i) {
			eventTime = Math.min(eventTime, AgentSystem.GetMissionCompleteTime(activeMissions[i].m_MissionId));
		}

		// TODO: Option to only notify on pending reports
		// Open mission slot, see if there's any agents able to fill it, or if one will recover from fatigue before a mission ends
		if (activeMissions.length < unlockedSlots) {
			for (var i:Number = 0; i < agents.length; ++i) {
				var agentID:Number = agents[i].m_AgentId;
				if (!AgentSystem.HasAgent(agentID) || AgentSystem.IsAgentOnMission(agentID)) { continue; } // Mission times are already accounted for
				if (AgentSystem.IsAgentFatigued(agentID)) { eventTime = Math.min(eventTime, AgentSystem.GetAgentRecoverTime(agentID)); }
				else { return 0; } // Agent and open slot available
			}
		}

		if (eventTime == Number.POSITIVE_INFINITY) { return undefined; }
		return eventTime;
	}

/// Queue pop alerts
	private function GroupPopAlert(dv:DistributedValue):Void {
		if (!dv.GetValue()) { return; }
		if (TeamInterface.GetClientTeamInfo()) {
			Debug.DevMsg("Pre-Grouped");
			return;
		}
		var popEvent = GroupFinder.GetActiveQueue();
		if (popEvent >= _global.Enums.LFGQueues.e_ScenarioSoloElite1 &&
			popEvent <= _global.Enums.LFGQueues.e_ScenarioSoloElite10) {
			// Exclude solo queues, they'll always pop instantly
			return;
		}
		Debug.LogMsg("Groupfinder queue popped"); // Message text is used by app as trigger
		Debug.LogMsg("Alert triggered"); // Prevent "previous message was logged x times" from obstructing further pop alerts
	}

/// Data file parser
	private function ParseModData(success:Boolean):Void {
		if (!success) {
			Debug.ErrorMsg("Failed to open data file", { fatal : true });
			return;
		}
		var xmlRoot:XMLNode = DataFile.firstChild;
		if (xmlRoot.nodeName != "ClockwatcherData") {
			Debug.ErrorMsg("Unknown data format: Expects root <ClockwatcherData>", { fatal : true });
			return;
		}
		var children:Array = xmlRoot.childNodes;
		for (var i:Number = 0; i < children.length; ++i) {
			switch (children[i].nodeName) {
				case "Lairs": {
					ParseLairData(children[i]);
					break;
				}
				default: {
					Debug.DevMsg("Unexpected entry in datafile");
					break;
				}
			}
		}
		delete DataFile;
		UpdateLoadProgress("Data");
	}

	private static function ParseLairData(root:XMLNode):Void {
		if (LairZones.length > 0) { return; } // Static values already initialized
		var zones:Array = root.childNodes;
		for (var i:Number = 0; i < zones.length; ++i) {
			if (zones[i].nodeName != "Zone") {
				DebugUtils.DevMsgS("Unexpected lair entry in datafile");
				continue;
			}
			var zoneID:Number = Number(zones[i].attributes.id);
			LairZones.push(zoneID);
			var missions:Array = zones[i].childNodes;
			for (var j:Number = 0; j < missions.length; ++j) {
				if (missions[j].nodeName != "Mission") {
					DebugUtils.DevMsgS("Unexpected lair entry in datafile");
					continue;
				}
				LairMissions[missions[j].attributes.id] = zoneID;
			}
		}
	}

/// Variables
	private var DataFile:XML;
	private static var LairZones:Array = new Array();
	private static var LairMissions:Object = new Object();
	private var LockoutsDV:DistributedValue;

	private static var AgentEvents:Object; // [charID] = eventTime map

	private var GroupFinderPopDV:DistributedValue;

	private var OfflineExportDV:DistributedValue;
	private var LoginAlertsDV:DistributedValue;
}

// Notes on ID ranges:
//   - Playzone IDs: In general range from 1000-8000 but will probably expand
//                   Open world zones (with lairs) currently fit into the 3000-3200 range (with some space for expansion)
//   - Agent IDs: Range from 100-300 (Dev alert if 1K+)
//   - Mission IDs: Range from 2000 - 5000, known collisions on relevant playzone IDs (Dev alert if < 1K)