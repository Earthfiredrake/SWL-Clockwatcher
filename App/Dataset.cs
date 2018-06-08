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
using System.Windows;
using System.Windows.Data;
using System.Windows.Input;
using System.Xml.Linq;

namespace Clockwatcher {
    internal sealed class Dataset : INotifyPropertyChanged, IDisposable {
        internal Dataset() {
            TabPanels.Add(Settings);
            Settings.PropertyChanged += SettingsChanged;
            OpenGameLog();
            Refresh();
        }

        private void OpenGameLog() {
            LogReader?.Dispose();
            try {
                LogReader = new StreamReader(new FileStream(Path.Combine(Settings.GameDir, "ClientLog.txt"), FileMode.Open, FileAccess.Read, FileShare.ReadWrite));
                LogReader.BaseStream.Seek(0, SeekOrigin.End); // Skip existing content (adding state based toggles, such as current logged in character, would require alternate solution
            } catch (IOException) {
                MessageBox.Show("Unable to open game log file. Group finder alerts disabled.\n Please verify game installation directory:\n" + Settings.GameDir + "\nChange in Settings if incorrect", "Clockwatcher Error");
            }
        }

        private void SettingsChanged(object sender, PropertyChangedEventArgs e) {
            switch (e.PropertyName) {
                case nameof(ConfigPanel.GameDir): {
                        OpenGameLog();
                        break;
                    }
            }
        }

        internal void Refresh() {
            // Basic re-entrancy guard
            if (Refreshing) {
                // Warning: previous refresh took longer than 5s. Will skip this cycle
                return;
            }
            Refreshing = true;
            // Scan the logfile for alerts or other state messages
            try {
                while (!LogReader?.EndOfStream ?? false) {
                    var line = LogReader.ReadLine();
                    if (line.Length > 32 && line.IndexOf("Scaleform.Clockwatcher", 32) != -1) {
                        if (line.EndsWith("Groupfinder queue popped")) {
                            RaiseAlert?.Invoke(this, new AudioAlertEventArgs(AudioAlertType.GroupfinderAlert));
                        }
                    }
                }
                // Load settings files
                foreach (var charFile in FindCharacterFiles()) {
                    var charData = ExtractCharacterMissions(charFile, out var charName);
                    if (charData != null) {
                        var existing = (from e in CharacterMissionLists
                                        where e.TabName == charName
                                        select e).SingleOrDefault();
                        if (existing != null) { // Merge with existing character record
                            existing.Merge(charData);
                        } else { // Add new character
                            var charPanel = new CharacterTimers(charName, charData);
                            CharacterMissionLists.Add(charPanel);
                            TabPanels.Insert(TabPanels.Count - 1, charPanel);
                        }
                    }
                }

                // Update time displays and trigger alert states
                if ((from c in CharacterMissionLists
                     from m in c.TimerList
                     where m.Refresh(Settings.AlertFilter)
                     select m).ToList().Any()) {
                    RaiseAlert?.Invoke(this, new AudioAlertEventArgs(AudioAlertType.AgentAlert));
                }
            } finally {
                Refreshing = false;
            }
        }

        private IEnumerable<string> FindCharacterFiles() {
            return from account in Directory.EnumerateDirectories(PrefsPath)
                   from character in Directory.EnumerateDirectories(account, CharDirFilter)
                   select Path.Combine(character, PrefsFileName);
        }

        private IEnumerable<TimerEntry> ExtractCharacterMissions(string settingsFilePath, out string charName) {
            Debug.Assert(File.Exists(settingsFilePath));
            try {
                using (Stream file = new FileStream(settingsFilePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite)) {
                    var trackerData = (from e in XElement.Load(file).Elements("Archive")
                                       where e.Attribute("name").Value == CWArchiveName
                                       select e).SingleOrDefault();
                    // Mod not in use on this character (no mod archive), no tab required
                    // Characters who only lack mission entries, are listed to show they have no cooldowns active
                    if (trackerData == null) { charName = null; return null; }
                    // Character name should be in saved data, otherwise use the Char# folder name which isn't so informative
                    charName = (from e in trackerData.Elements("String")
                                where e.Attribute("name").Value == "CharName"
                                select e).SingleOrDefault()?.Attribute("value").Value?.Trim('"')
                                    ?? Directory.GetParent(settingsFilePath).Name;
                    // Coerce the serialization difference between a single and multi element array into a single IEnumerable
                    var missions = from e in EnumerateArchiveEntry(trackerData, "MissionCD")
                                   select new MissionTimer((e.Attribute("value").Value).Trim('"'));
                    var agents = from e in EnumerateArchiveEntry(trackerData, "AgentCD")
                                 select new AgentTimer((e.Attribute("value").Value).Trim('"'));
                    return Enumerable.Empty<TimerEntry>().Concat(missions).Concat(agents);
                }
            } catch (IOException) {
                // File in use or other issue... either way no data from this one, so skip it
                charName = null;
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

        public void Dispose() => Dispose(true);

        private void Dispose(bool disposing) {
            if (!Disposed) {
                if (disposing) {
                    LogReader.Dispose();
                }
                Disposed = true;
            }
        }

        public ConfigPanel Settings { get; } = new ConfigPanel();
        public ObservableCollection<TabPanelData> TabPanels { get; } = new ObservableCollection<TabPanelData>();

        public event EventHandler<AudioAlertEventArgs> RaiseAlert;
        public event PropertyChangedEventHandler PropertyChanged; // Unused, fulfils implementation requirements for WPF

        private bool Refreshing = false;
        private StreamReader LogReader;
        private ICollection<CharacterTimers> CharacterMissionLists = new List<CharacterTimers>();

        private static readonly string PrefsPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Funcom", "SWL", "Prefs");
        private const string CharDirFilter = "Char*";
        private const string PrefsFileName = "Prefs_2.xml";
        private const string CWArchiveName = "efdClockwatcherMissionList";

        private bool Disposed = false;
    }

    internal enum AudioAlertType {
        AgentAlert,
        GroupfinderAlert
    }

    internal sealed class AudioAlertEventArgs : EventArgs {
        internal AudioAlertEventArgs(AudioAlertType alertType) {
            AlertType = alertType;
        }

        public AudioAlertType AlertType { get; }
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
            DropFocusCommand = new CommandWrapper(o => DropFocus((FrameworkElement)o), o => o is FrameworkElement);
        }

        private void LoadConfig() {
            var settingsFile = Path.Combine(SettingsDir, SettingsFile);
            if (File.Exists(settingsFile)) {
                using (var stream = new FileStream(settingsFile, FileMode.Open, FileAccess.Read, FileShare.Read)) {
                    var settings = XElement.Load(stream);
                    var gameDir = GetSetting(settings, "GameInfo", "Path");
                    if (gameDir != null) { _GameDir = gameDir; }
                    if (Boolean.TryParse(GetSetting(settings, "AgentAudioAlert", "Enabled"), out var b)) {
                        _AgentAlertEnabled = b;
                    }
                    var alertFile = GetSetting(settings, "AgentAudioAlert", "FileName");
                    if (alertFile != null) { _AgentAlertFile = alertFile; }
                    if (Boolean.TryParse(GetSetting(settings, "GFPopAudioAlert", "Enabled"), out b)) {
                        _GFPopAlertEnabled = b;
                    }
                    alertFile = GetSetting(settings, "GFPopAudioAlert", "FileName");
                    if (alertFile != null) { _GFPopAlertFile = alertFile; }
                }
            }
            SaveConfig(); // Update the file with any new settings
        }

        private string GetSetting(XElement settings, string group, string key) {
            return settings.Element(group)?.Attribute(key)?.Value;
        }

        private void SaveConfig() {
            var settings = new XElement("Settings",
                new XElement("GameInfo",
                  new XAttribute("Path", GameDir)
                ),
                new XElement("AgentAudioAlert",
                    new XAttribute("Enabled", EnableAgentAudioAlert),
                    new XAttribute("FileName", _AgentAlertFile)
                ),
                new XElement("GFPopAudioAlert",
                    new XAttribute("Enabled", EnableGFPopAudioAlert),
                    new XAttribute("FileName", _GFPopAlertFile)
                ));
            Directory.CreateDirectory(SettingsDir);
            settings.Save(Path.Combine(SettingsDir, SettingsFile));
        }

        protected override sealed void RaisePropertyChanged(string propertyName) {
            base.RaisePropertyChanged(propertyName);
            SaveConfig();
        }

        public bool EnableAgentAudioAlert {
            get { return _AgentAlertEnabled; }
            set {
                if (value != _AgentAlertEnabled) {
                    _AgentAlertEnabled = value;
                    RaisePropertyChanged(nameof(EnableAgentAudioAlert));
                }
            }
        }
        public string AgentAlertFile => Path.Combine(Directory.GetCurrentDirectory(), "sfx", _AgentAlertFile);

        public bool EnableGFPopAudioAlert {
            get { return _GFPopAlertEnabled; }
            set {
                if (value != _GFPopAlertEnabled) {
                    _GFPopAlertEnabled = value;
                    RaisePropertyChanged(nameof(EnableGFPopAudioAlert));
                }
            }
        }
        public string GFPopAlertFile => Path.Combine(Directory.GetCurrentDirectory(), "sfx", _GFPopAlertFile);

        public string GameDir {
            get { return _GameDir; }
            set {
                if (value != _GameDir) {
                    _GameDir = value;
                    RaisePropertyChanged(nameof(GameDir));
                }
            }
        }

        public ICommand DropFocusCommand { get; }
        private static void DropFocus(FrameworkElement param) {
            var parent = param.Parent as FrameworkElement;
            while (parent != null && ((!(parent as IInputElement)?.Focusable) ?? true)) {
                parent = parent.Parent as FrameworkElement;
            }

            var scope = FocusManager.GetFocusScope(param);
            FocusManager.SetFocusedElement(scope, (IInputElement)parent);
            if (param.IsKeyboardFocused) { Keyboard.ClearFocus(); }
        }

        internal TimerClass AlertFilter { get; } = TimerClass.Agent;

        private string SettingsDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Funcom", "SWL", "Mods", "Clockwatcher");
        private string SettingsFile = "ViewerSettings.xml";

        private string _GameDir = Path.GetFullPath(Path.Combine("..", "..", "..", "..", ".."));

        private bool _AgentAlertEnabled = true;
        private string _AgentAlertFile = "AgentAlert.wav";
        private bool _GFPopAlertEnabled = true;
        private string _GFPopAlertFile = "GFPopAlert.wav";
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
        public ObservableCollection<TimerEntry> TimerList { get; } = new ObservableCollection<TimerEntry>();
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
            if (IsReady && AlertDone) { return false; } // No need to update or trigger alerts
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

    internal sealed class AgentTimer : TimerEntry {
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
