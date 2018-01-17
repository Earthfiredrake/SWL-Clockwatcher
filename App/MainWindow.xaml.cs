// Copyright 2018, Earthfiredrake
// Released under the terms of the MIT License
// https://github.com/Earthfiredrake/SWL-Clockwatcher

using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Input;
using System.Xml.Linq;

namespace Clockwatcher {
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window {

        public MainWindow() {
            InitializeComponent();
            DataContext = this;
            RefreshCommand = new CommandWrapper(param => RefreshData(), param => true);
            RefreshData();            
        }

        private void RefreshData() {
            MissionLists.Clear();
            foreach (var charFile in FindCharacterFiles()) {
                var charData = ExtractCharacterData(charFile);
                if (charData != null) { MissionLists.Add(charData); }
            }
        }

        private IEnumerable<string> FindCharacterFiles() {
            var path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Funcom", "SWL", "Prefs");
            return from dirA in Directory.EnumerateDirectories(path) // Accounts
                   from dirB in Directory.EnumerateDirectories(dirA, "Char*") // Char# directories
                   select Path.Combine(dirB, "Prefs_2.xml"); // Pref files
        }

        private Object ExtractCharacterData(string settingsFile) {
            Debug.Assert(File.Exists(settingsFile));
            var trackerData = (from e in XElement.Load(settingsFile).Elements("Archive")
                               where (string)e.Attribute("name") == "efdClockwatcherConfig"
                               select e).SingleOrDefault();
            // Mod not in use on this character (no mod archive), no tab required
            // Characters who only lack mission entries, are listed to show they have no cooldowns active
            if (trackerData == null) { return null; }
            // Character name should be in saved data, otherwise use the Char# folder name which isn't so informative
            var charName = ((string)(from e in trackerData.Elements("String")
                                     where (string)e.Attribute("name") == "CharName"
                                     select e).SingleOrDefault()?.Attribute("value"))?.Trim('"')
                            ?? Directory.GetParent(settingsFile).Name;
            // Coerce the serialization difference between a single and multi element array into a single type
            var source = (from e in trackerData.Elements("Array")
                          where (string)e.Attribute("name") == "MissionCD"
                          select e).SingleOrDefault()?.Elements("String")
                        ?? (from e in trackerData.Elements("String")
                            where (string)e.Attribute("name") == "MissionCD"
                            select e);
            var missions = from e in source
                           let entry = ((string)e.Attribute("value")).Trim('"').Split('|')
                           orderby entry[1] // Apply default sort on remaining cooldown time
                           // DateTime.Now keeps sneaking milliseconds into the math, and formatting options are limited, so stripping them out instead
                           let remaining = Round((DateTimeOffset.FromUnixTimeSeconds(long.Parse(entry[1])).LocalDateTime - DateTime.Now), new TimeSpan(0, 0, 1))
                           select new {
                               ID = entry[0], Name = entry[2], Cooldown = TimeSpan.Zero.CompareTo(remaining) < 0 ? remaining.ToString("g") : "Ready!"
                           };
            return new { CharName = charName, Missions = missions };
        }

        private TimeSpan Round(TimeSpan timeSpan, TimeSpan interval) {
            var halfIntervalTicks = (interval.Ticks + 1) >> 1;
            return timeSpan.Add(new TimeSpan(halfIntervalTicks - ((timeSpan.Ticks + halfIntervalTicks) % interval.Ticks)));
        }

        public ICommand RefreshCommand { get; }
        public ObservableCollection<object> MissionLists { get; } = new ObservableCollection<object>();
    }

    class CommandWrapper : ICommand {
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
}
