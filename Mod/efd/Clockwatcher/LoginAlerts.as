// Copyright 2018, Earthfiredrake
// Released under the terms of the MIT License
// https://github.com/Earthfiredrake/SWL-Clockwatcher

import flash.geom.Point;

import com.GameInterface.Utils;

// Note: By including this, and because the master copy does not remain pre-loaded at all times, this mod doesn't do perfect code injection
//   Specifically, after a /reloadui, this mod's copy will be the one used to generate the prototype
//   Maintainers should be careful to track this file in the API so that updates can be released in a timely manner
import GUI.LoginCharacterSelection.CharacterListItemRenderer;

import efd.Clockwatcher.Clockwatcher;
import efd.Clockwatcher.lib.DebugUtils;
import efd.Clockwatcher.lib.util.WeakDelegate;

class efd.Clockwatcher.LoginAlerts {
	public function LoginAlerts(hostMovie:MovieClip) {
		HostMovie = hostMovie;

		Alerts = {
			renderer0 : hostMovie.attachMovie("CWAgentAlertIcon", "SlotAlerts1", hostMovie.getNextHighestDepth(), {_visible : false}),
			renderer1 : hostMovie.attachMovie("CWAgentAlertIcon", "SlotAlerts2", hostMovie.getNextHighestDepth(), {_visible : false}),
			renderer2 : hostMovie.attachMovie("CWAgentAlertIcon", "SlotAlerts3", hostMovie.getNextHighestDepth(), {_visible : false}),
			renderer3 : hostMovie.attachMovie("CWAgentAlertIcon", "SlotAlerts4", hostMovie.getNextHighestDepth(), {_visible : false})
		};
		var proto:Object = CharacterListItemRenderer.prototype;
		proto._ApplyAlerts = WeakDelegate.Create(this, ApplyAlerts);
		if (proto._UpdateVisuals == undefined) {
			proto._UpdateVisuals = proto.UpdateVisuals;
			proto.UpdateVisuals = function():Void {
				this._UpdateVisuals();
				var pos:Point = new Point(9, this.m_Level._y + 17);
				this.localToGlobal(pos);
				this._ApplyAlerts(this._name, pos, this.data.m_CreateCharacter ? undefined : this.data.m_Id);
			};
		}
	}

	private function ApplyAlerts(slot:String, pos:Point, charID:Number) {
		var alertClip:MovieClip = Alerts[slot];
		alertClip._x = pos.x;
		alertClip._y = pos.y;
		var agentEventTime:Number = Clockwatcher.GetOfflineAgentEvent(charID);
		alertClip._visible = agentEventTime != undefined && agentEventTime <= Utils.GetServerSyncedTime();
	}

	private var HostMovie:MovieClip;
	private var Alerts:Object; // Map of MovieClips by renderer name
}
