// Copyright 2018, Earthfiredrake
// Released under the terms of the MIT License
// https://github.com/Earthfiredrake/SWL-Clockwatcher

using System;
using System.IO;
using System.Windows;
using System.Windows.Threading;

namespace Clockwatcher {
    public partial class App : Application {

        public App() {
            DispatcherUnhandledException += UnhandledException;
            if (File.Exists(LogFilePath)) { File.Delete(LogFilePath); }
        }

        internal static void LogMessage(string msg) {
            using (StreamWriter log = File.AppendText(LogFilePath)) {
                log.WriteLine(msg);
                log.Close();
            }
        }

        private void UnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e) {
            LogMessage(e.Exception.ToString());
            e.Handled = true; // Supress exception to prevent hard crash
        }

        private static readonly string LogFilePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Funcom", "SWL", "Mods", "Clockwatcher", "AppLog.txt");
    }
}
