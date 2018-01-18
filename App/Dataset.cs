using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Windows.Input;
using System.Xml.Linq;

namespace Clockwatcher {
    internal class Dataset {
        public Dataset() {
            RefreshCommand = new CommandWrapper(o => Refresh(true), o => true);
            Refresh(true);
        }

        public void Refresh(bool reload) {
            if (reload) {
                // Load new data
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
        }

        private IEnumerable<string> FindCharacterFiles() {
            var path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Funcom", "SWL", "Prefs");
            return from dirA in Directory.EnumerateDirectories(path) // Accounts
                   from dirB in Directory.EnumerateDirectories(dirA, "Char*") // Char# directories
                   select Path.Combine(dirB, "Prefs_2.xml"); // Pref files
        }

        private CharacterMissions ExtractCharacterMissions(string settingsFilePath) {
            Debug.Assert(File.Exists(settingsFilePath));
            var trackerData = (from e in XElement.Load(settingsFilePath).Elements("Archive")
                               where (string)e.Attribute("name") == "efdClockwatcherConfig"
                               select e).SingleOrDefault();
            // Mod not in use on this character (no mod archive), no tab required
            // Characters who only lack mission entries, are listed to show they have no cooldowns active
            if (trackerData == null) { return null; }
            // Character name should be in saved data, otherwise use the Char# folder name which isn't so informative
            var charName = ((string)(from e in trackerData.Elements("String")
                                     where (string)e.Attribute("name") == "CharName"
                                     select e).SingleOrDefault()?.Attribute("value"))?.Trim('"')
                            ?? Directory.GetParent(settingsFilePath).Name;
            // Coerce the serialization difference between a single and multi element array into a single type
            var source = (from e in trackerData.Elements("Array")
                          where (string)e.Attribute("name") == "MissionCD"
                          select e).SingleOrDefault()?.Elements("String")
                        ?? (from e in trackerData.Elements("String")
                            where (string)e.Attribute("name") == "MissionCD"
                            select e);
            var missions = from e in source
                           let m = new Mission(((string)e.Attribute("value")).Trim('"'))
                           orderby m.UnlockTime
                           select m;
            return new CharacterMissions(charName, missions);
        }

        public ObservableCollection<CharacterMissions> CharacterMissionLists { get; } = new ObservableCollection<CharacterMissions>();
        public ICommand RefreshCommand { get; }
    }

    // Nested data

    internal class CharacterMissions {
        public CharacterMissions(string charName, IEnumerable<Mission> missions) {
            CharName = charName;
            Merge(missions);
        }

        public void Merge(IEnumerable<Mission> additional) {
            foreach (var m in additional.Except(MissionList, new EqualityWrapper<Mission>((m1, m2) => m1.ID == m2.ID))) {
                MissionList.Add(m);
            }
        }

        public string CharName { get; }
        public ObservableCollection<Mission> MissionList { get; } = new ObservableCollection<Mission>();
    }

    internal class Mission : INotifyPropertyChanged {

        public Mission(string missionInfo) {
            var entries = missionInfo.Split('|');
            ID = int.Parse(entries[0]);
            Name = entries[2];
            UnlockTime = DateTimeOffset.FromUnixTimeSeconds(long.Parse(entries[1])).LocalDateTime;
        }


        public void Refresh() {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(RemainingTime)));
        }

        public event PropertyChangedEventHandler PropertyChanged;

        public int ID { get; }
        public string Name { get; }
        public DateTimeOffset UnlockTime { get; }
        public TimeSpan RemainingTime { get => UnlockTime - DateTime.Now; }
    }

    // Helper classes

    internal class CommandWrapper : ICommand {
        public event EventHandler CanExecuteChanged;

        public CommandWrapper(Action<object> execute, Func<object, bool> canExecute) {
            _CanExecute = canExecute;
            _Execute = execute;
        }

        public bool CanExecute(object parameter) => _CanExecute(parameter);
        public void Execute(object parameter) => _Execute(parameter);

        private readonly Func<object, bool> _CanExecute;
        private readonly Action<object> _Execute;
    }

    internal class EqualityWrapper<T> : IEqualityComparer<T> {
        public EqualityWrapper(Func<T, T, bool> comparer) : this(comparer, t => 0) { }
        public EqualityWrapper(Func<T, T, bool> comparer, Func<T, int> hash) {
            _Equals = comparer;
            _Hash = hash;
        }

        public bool Equals(T x, T y) { return _Equals(x, y); }
        public int GetHashCode(T obj) { return _Hash(obj); }
        private readonly Func<T, T, bool> _Equals;
        private readonly Func<T, int> _Hash;
    }
}
