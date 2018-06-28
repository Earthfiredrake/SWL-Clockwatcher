// Copyright 2018, Earthfiredrake
// Released under the terms of the MIT License
// https://github.com/Earthfiredrake/SWL-Clockwatcher

import flash.geom.Point;

import gfx.utils.Delegate;

import com.GameInterface.DistributedValue;
import com.GameInterface.Utils;

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
		
		LoginScreenDV = DistributedValue.Create("login_characterselection_gui");
		LoginScreenDV.SignalChanged.Connect(HookUI, this);
		HookUI(LoginScreenDV);
	}
	
	private function HookUI(dv:DistributedValue):Void {
		if (!HookApplied) {
			var proto:Object = _global.GUI.LoginCharacterSelection.CharacterListItemRenderer.prototype;
			if (proto) {
				proto._ApplyAlerts = WeakDelegate.Create(this, ApplyAlerts);
				var wrapper:Function = function():Void {
					arguments.callee.base.apply(this, arguments);
					var pos:Point = new Point(9, this.m_Level._y + 17);
					this.localToGlobal(pos);
					this._ApplyAlerts(this._name, pos, this.data.m_CreateCharacter ? undefined : this.data.m_Id);
				};
				wrapper.base = proto.UpdateVisuals;
				proto.UpdateVisuals = wrapper;
				HookApplied = true;
			}
			else if (dv.GetValue()) { setTimeout(Delegate.create(this, HookUI), 50, dv); }
		}
	}

	private function ApplyAlerts(slot:String, pos:Point, charID:Number):Void {
		var alertClip:MovieClip = Alerts[slot];
		alertClip._x = pos.x;
		alertClip._y = pos.y;
		var agentEventTime:Number = Clockwatcher.GetOfflineAgentEvent(charID);
		alertClip._visible = agentEventTime != undefined && agentEventTime <= Utils.GetServerSyncedTime();
	}

	private var HostMovie:MovieClip;
	private var Alerts:Object; // Map of MovieClips by renderer name
	private var LoginScreenDV:DistributedValue;
	private static var HookApplied:Boolean = false;
}
