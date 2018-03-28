// Copyright 2018, Earthfiredrake
// Released under the terms of the MIT License
// https://github.com/Earthfiredrake/SWL-Clockwatcher

using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Timers;
using System.Windows.Data;
using System.Windows.Input;
using System.Xml.Linq;

namespace Clockwatcher {
    internal sealed class Dataset {
        internal Dataset() {
            TabPanels.Add(Settings);

            RefreshTimer.Elapsed += (sender, e) => Refresh();

            Refresh();
        }

        private void Refresh() {
            RefreshTimer.Enabled = false;
            try {
                // Load settings files
                foreach (var charFile in FindCharacterFiles()) {
                    var charData = ExtractCharacterMissions(charFile);
                    if (charData != null) {
                        var existing = (from e in CharacterMissionLists
                                        where e.TabName == charData.TabName
                                        select e).SingleOrDefault();
                        if (existing != null) { // Merge with existing character record
                            existing.Merge(charData.TimerList);
                        } else { // Add new character
                            CharacterMissionLists.Add(charData);
                            TabPanels.Insert(TabPanels.Count - 1, charData);
                        }
                    }
                }

                // Update time displays and trigger alert states
                if ((from c in CharacterMissionLists
                     from m in c.TimerList
                     where m.Refresh(Settings.AlertFilter)
                     select m).ToList().Any()) {
                    RaiseAlert?.Invoke(this, EventArgs.Empty);
                }
            } finally {
                // Unhandled exceptions were causing the refresh timer to stop
                // A bit of an issue now that there's no way to restart it
                RefreshTimer.Enabled = true;
            }
        }

        private IEnumerable<string> FindCharacterFiles() {
            return from account in Directory.EnumerateDirectories(PrefsPath)
                   from character in Directory.EnumerateDirectories(account, CharDirFilter)
                   select Path.Combine(character, PrefsFileName);
        }

        private CharacterTimers ExtractCharacterMissions(string settingsFilePath) {
            Debug.Assert(File.Exists(settingsFilePath));
            try {
                using (Stream file = new FileStream(settingsFilePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite)) {
                    var trackerData = (from e in XElement.Load(file).Elements("Archive")
                                       where e.Attribute("name").Value == CWArchiveName
                                       select e).SingleOrDefault();
                    // Mod not in use on this character (no mod archive), no tab required
                    // Characters who only lack mission entries, are listed to show they have no cooldowns active
                    if (trackerData == null) { return null; }
                    // Character name should be in saved data, otherwise use the Char# folder name which isn't so informative
                    var charName = (from e in trackerData.Elements("String")
                                    where e.Attribute("name").Value == "CharName"
                                    select e).SingleOrDefault()?.Attribute("value").Value?.Trim('"')
                                    ?? Directory.GetParent(settingsFilePath).Name;
                    // Coerce the serialization difference between a single and multi element array into a single IEnumerable
                    var missions = from e in EnumerateArchiveEntry(trackerData, "MissionCD")
                                   select new MissionTimer((e.Attribute("value").Value).Trim('"'));
                    var agents = from e in EnumerateArchiveEntry(trackerData, "AgentCD")
                                 select new AgentTimer((e.Attribute("value").Value).Trim('"'));
                    return new CharacterTimers(charName, Enumerable.Empty<TimerEntry>().Concat(missions).Concat(agents));
                }
            } catch (IOException) {
                // File in use or other issue... either way no data from this one, so skip it
                return null;
            }
        }

        // Multi and single element arrays serialize differently, this coerces them into a single IEnumerable structure
        private IEnumerable<XElement> EnumerateArchiveEntry(XElement archive, string tag) {
            return (from e in archive.Elements("Array")
                    where (string)e.Attribute("name") == tag
                    select e).SingleOrDefault()?.Elements("String")
                    ?? (from e in archive.Elements("String")
                        where (string)e.Attribute("name") == tag
                        select e);
        }

        public ConfigPanel Settings { get; } = new ConfigPanel();
        public IList<TabPanelData> TabPanels { get; } = new ObservableCollection<TabPanelData>();
        public ICommand RefreshCommand { get; }

        public event EventHandler RaiseAlert;

        private ICollection<CharacterTimers> CharacterMissionLists = new List<CharacterTimers>();
        private readonly Timer RefreshTimer = new Timer(5000);

        private static readonly string PrefsPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Funcom", "SWL", "Prefs");
        private const string CharDirFilter = "Char*";
        private const string PrefsFileName = "Prefs_2.xml";

        private const string CWArchiveName = "efdClockwatcherMissionList";
    }

    internal abstract class TabPanelData : INotifyPropertyChanged {
        protected internal TabPanelData(string name) {
            TabName = name;
        }

        public string TabName { get; }

        public event PropertyChangedEventHandler PropertyChanged;
        protected virtual void RaisePropertyChanged(string propertyName) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }

    internal sealed class ConfigPanel : TabPanelData {
        internal ConfigPanel() : base("Settings") {
            LoadConfig();
        }

        private void LoadConfig() {
            var settingsFile = Path.Combine(SettingsDir, SettingsFile);
            if (File.Exists(settingsFile)) {
                using (var stream = new FileStream(settingsFile, FileMode.Open, FileAccess.Read, FileShare.ReadWrite)) {
                    var settings = XElement.Load(stream);
                    EnableAudioAlerts = Boolean.Parse(settings.Element("AgentAudioAlert").Attribute("Enabled").Value);
                }
            }
        }

        private void SaveConfig() {
            var settings = new XElement("Settings",
                new XElement("AgentAudioAlert",
                    new XAttribute("Enabled", EnableAudioAlerts)
                ));
            Directory.CreateDirectory(SettingsDir);
            settings.Save(Path.Combine(SettingsDir, SettingsFile));
        }

        protected override sealed void RaisePropertyChanged(string propertyName) {
            base.RaisePropertyChanged(propertyName);
            SaveConfig();
        }

        public bool EnableAudioAlerts {
            get { return _EnableAudioAlerts; }
            set {
                if (value != _EnableAudioAlerts) {
                    _EnableAudioAlerts = value;
                    RaisePropertyChanged(nameof(EnableAudioAlerts));
                }
            }
        }
        public string AlertSoundFileName { get; } = "sfx\\AgentAlert.wav";

        internal TimerClass AlertFilter { get; } = TimerClass.Agent;

        private bool _EnableAudioAlerts = true;
        private string SettingsDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Funcom", "SWL", "Mods", "Clockwatcher");
        private string SettingsFile = "ViewerSettings.xml";
    }

    // Nested data

    internal sealed class CharacterTimers : TabPanelData {
        internal CharacterTimers(string charName, IEnumerable<TimerEntry> timers) :
            base(charName) {

            var view = CollectionViewSource.GetDefaultView(TimerList);
            view.SortDescriptions.Add(new SortDescription(nameof(TimerEntry.RemainingTime), ListSortDirection.Ascending));
            ((ICollectionViewLiveShaping)view).IsLiveSorting = true;

            foreach (var timer in timers) { TimerList.Add(timer); }

            ClearReadyCommand = new CommandWrapper(o => ClearReady(), o => true);
        }

        internal void Merge(IEnumerable<TimerEntry> other) {
            foreach (var t in other) {
                var existing = TimerList.FirstOrDefault((x) => x.ID == t.ID);
                if (existing != null) {
                    existing.UnlockTime = t.UnlockTime;
                    if (existing.Class != t.Class) { existing.ChangeTimerClass(t.Class); }
                } else if (!t.IsReady) {
                    App.Current.Dispatcher.Invoke(() => TimerList.Add(t));
                }
            }
        }

        private void ClearReady() {
            foreach (var tReady in (from t in TimerList
                                    where t.IsReady
                                    select t).ToList()) {
                TimerList.Remove(tReady);
            }
        }

        public ICommand ClearReadyCommand { get; }
        public ICollection<TimerEntry> TimerList { get; } = new ObservableCollection<TimerEntry>();
    }

    [Flags]
    internal enum TimerClass {
        None = 0,
        AgentMission = 1,
        AgentRecovery = 2,
        Agent = AgentMission | AgentRecovery,
        Lair = 4,
        Mission = 8
    }

    internal abstract class TimerEntry : INotifyPropertyChanged {

        protected internal TimerEntry(string entryData) {
            var dataFields = entryData.Split('|');
            ID = int.Parse(dataFields[0]);
            Name = dataFields[2];
            UnlockTime = DateTimeOffset.FromUnixTimeSeconds(long.Parse(dataFields[1])).LocalDateTime;
        }

        internal bool Refresh(TimerClass alertFilter) {
            RaisePropertyChanged(nameof(RemainingTime));
            return IsReady != AlertDone ? (AlertDone = IsReady) && ((alertFilter & Class) != TimerClass.None) : false;
        }

        internal abstract void ChangeTimerClass(TimerClass newClass);

        internal int ID { get; }
        public string Name { get; }
        internal DateTimeOffset UnlockTime { get; set; }
        public TimeSpan RemainingTime => UnlockTime - DateTime.Now;
        internal bool IsReady => RemainingTime.TotalSeconds <= 0;

        public event PropertyChangedEventHandler PropertyChanged;
        protected void RaisePropertyChanged(string propertyName) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));

        public abstract TimerClass Class { get; }

        private bool AlertDone = false;
    }

    internal sealed class AgentTimer : TimerEntry, INotifyPropertyChanged {
        internal AgentTimer(string agentInfo) : base(agentInfo) {
            IsRecovering = Boolean.Parse(agentInfo.Split('|')[3]);
        }

        internal override void ChangeTimerClass(TimerClass newClass) {
            IsRecovering = newClass == TimerClass.AgentRecovery;
            RaisePropertyChanged(nameof(Class));
        }

        private bool IsRecovering { get; set; }
        public override TimerClass Class => IsRecovering ? TimerClass.AgentRecovery : TimerClass.AgentMission;
    }

    internal sealed class MissionTimer : TimerEntry {
        internal MissionTimer(string missionInfo) : base(missionInfo) { }

        // Mission classes are unique by ID, they should not change
        internal override void ChangeTimerClass(TimerClass newClass) => throw new NotSupportedException();

        public override TimerClass Class => ID > 0 ? TimerClass.Mission : TimerClass.Lair;
    }

    // Helper classes

    internal sealed class CommandWrapper : ICommand {
        public event EventHandler CanExecuteChanged;

        internal CommandWrapper(Action<object> execute, Func<object, bool> canExecute) {
            _CanExecute = canExecute;
            _Execute = execute;
        }

        public bool CanExecute(object parameter) => _CanExecute(parameter);
        public void Execute(object parameter) => _Execute(parameter);

        private readonly Func<object, bool> _CanExecute;
        private readonly Action<object> _Execute;
    }
}
