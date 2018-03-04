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
    internal class Dataset {
        internal Dataset() {
            RefreshCommand = new CommandWrapper(o => Refresh(true), o => true);
            RefreshTimer.Elapsed += (sender, e) => Refresh(false);
            Refresh(true);
        }

        internal void Refresh(bool reload) {
            RefreshTimer.Enabled = false;
            if (reload) { // Load settings files
                foreach (var charFile in FindCharacterFiles()) {
                    var charData = ExtractCharacterMissions(charFile);
                    if (charData != null) {
                        var existing = (from e in CharacterMissionLists
                                        where e.CharName == charData.CharName
                                        select e).SingleOrDefault();
                        if (existing != null) { // Merge with existing character record
                            existing.Merge(charData.MissionList);
                        } else { // Add new character
                            CharacterMissionLists.Add(charData);
                        }
                    }
                }
            }
            // Update time displays
            foreach (var m in from c in CharacterMissionLists
                              from m in c.MissionList
                              select m) { m.Refresh(); }
            RefreshTimer.Enabled = true;
        }

        private IEnumerable<string> FindCharacterFiles() {
            return from account in Directory.EnumerateDirectories(PrefsPath)
                   from character in Directory.EnumerateDirectories(account, CharDirFilter)
                   select Path.Combine(character, PrefsFileName);
        }

        private CharacterMissions ExtractCharacterMissions(string settingsFilePath) {
            Debug.Assert(File.Exists(settingsFilePath));
            try {
                var trackerData = (from e in XElement.Load(settingsFilePath).Elements("Archive")
                                   where (string)e.Attribute("name") == CWArchiveName
                                   select e).SingleOrDefault();
                // Mod not in use on this character (no mod archive), no tab required
                // Characters who only lack mission entries, are listed to show they have no cooldowns active
                if (trackerData == null) { return null; }
                // Character name should be in saved data, otherwise use the Char# folder name which isn't so informative
                var charName = ((string)(from e in trackerData.Elements("String")
                                         where (string)e.Attribute("name") == "CharName"
                                         select e).SingleOrDefault()?.Attribute("value"))?.Trim('"')
                                ?? Directory.GetParent(settingsFilePath).Name;
                // Coerce the serialization difference between a single and multi element array into a single IEnumerable
                var source = (from e in trackerData.Elements("Array")
                              where (string)e.Attribute("name") == "MissionCD"
                              select e).SingleOrDefault()?.Elements("String")
                            ?? (from e in trackerData.Elements("String")
                                where (string)e.Attribute("name") == "MissionCD"
                                select e);
                var missions = from e in source
                               select new Mission(((string)e.Attribute("value")).Trim('"'));
                return new CharacterMissions(charName, missions);
            } catch (IOException) {
                // File in use or other issue... either way no data from this one, so skip it
                return null;
            }
        }

        public ICollection<CharacterMissions> CharacterMissionLists { get; } = new ObservableCollection<CharacterMissions>();
        public ICommand RefreshCommand { get; }
        private readonly Timer RefreshTimer = new Timer(5000);

        private static readonly string PrefsPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Funcom", "SWL", "Prefs");
        private const string CharDirFilter = "Char*";
        private const string PrefsFileName = "Prefs_2.xml";

        private const string CWArchiveName = "efdClockwatcherMissionList";
    }

    // Nested data

    internal class CharacterMissions {
        internal CharacterMissions(string charName, IEnumerable<Mission> missions) {
            CharName = charName;
            var view = CollectionViewSource.GetDefaultView(MissionList);
            view.SortDescriptions.Add(new SortDescription(nameof(Mission.RemainingTime), ListSortDirection.Ascending));
            ((ICollectionViewLiveShaping)view).IsLiveSorting = true;
            Merge(missions);
        }

        internal void Merge(IEnumerable<Mission> additional) {
            foreach (var m in additional) {
                var existing = MissionList.FirstOrDefault((x) => x.ID == m.ID);
                if (existing != null) {
                    existing.UnlockTime = m.UnlockTime;
                    // Refresh cycle will trigger PropertyChanged
                } else { MissionList.Add(m); }
            }
        }

        public string CharName { get; }
        public ICollection<Mission> MissionList { get; } = new ObservableCollection<Mission>();
    }

    internal class Mission : INotifyPropertyChanged {

        internal Mission(string missionInfo) {
            var entries = missionInfo.Split('|');
            ID = int.Parse(entries[0]);
            Name = entries[2];
            UnlockTime = DateTimeOffset.FromUnixTimeSeconds(long.Parse(entries[1])).LocalDateTime;
        }

        internal void Refresh() { PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(RemainingTime))); }

        public event PropertyChangedEventHandler PropertyChanged;

        internal int ID { get; }
        public string Name { get; }
        internal DateTimeOffset UnlockTime { get; set; }
        public TimeSpan RemainingTime { get => UnlockTime - DateTime.Now; }
    }

    // Helper classes

    internal class CommandWrapper : ICommand {
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
