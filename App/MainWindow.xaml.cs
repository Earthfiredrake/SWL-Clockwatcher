// Copyright 2018, Earthfiredrake
// Released under the terms of the MIT License
// https://github.com/Earthfiredrake/SWL-Clockwatcher

using System;
using System.Globalization;
using System.Timers;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Shell;
using System.Windows.Threading;

namespace Clockwatcher {
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window {
        public MainWindow() {
            InitializeComponent();
            var context = new Dataset();
            context.RaiseAlert += Context_RaiseAlert;
            DataContext = context;
            RefreshTimer.Elapsed += (sender, e) => context.Refresh();
            RefreshTimer.Start();
        }

        private void Context_RaiseAlert(object sender, AudioAlertEventArgs e) {
            Dispatcher.Invoke((Action<AudioAlertEventArgs>)EmitAlert, e);
        }

        private void EmitAlert(AudioAlertEventArgs e) {
            switch (e.AlertType) {
                case AudioAlertType.AgentAlert:
                    if (!IsActive || WindowState == WindowState.Minimized) {
                        AgentAlertSound.Play();
                        TaskbarItemInfo.ProgressState = TaskbarItemProgressState.Paused;
                    }
                    break;
                case AudioAlertType.GroupfinderAlert:
                    GFPopAlertSound.Play();
                    if (!IsActive || WindowState == WindowState.Minimized) {
                        TaskbarItemInfo.ProgressState = TaskbarItemProgressState.Error;
                    }
                    break;
            }
        }

        private void ClearTaskbarAlert(object sender, EventArgs e) => TaskbarItemInfo.ProgressState = TaskbarItemProgressState.None;

        private void ResetAlertSound(object sender, RoutedEventArgs e) => (sender as MediaElement)?.Stop();

        private readonly Timer RefreshTimer = new Timer(5000);
    }

    [ValueConversion(typeof(TimeSpan), typeof(string))]
    public class TimeFormatConverter : IValueConverter {
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture) {
            var t = (TimeSpan)value;
            if (t.TotalSeconds > 0) {
                return Math.Floor(t.TotalHours) + culture.DateTimeFormat.TimeSeparator + t.Minutes.ToString("00") + culture.DateTimeFormat.TimeSeparator + t.Seconds.ToString("00");
            } else { return "Ready!"; }
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) {
            var s = (string)value;
            if (s == "Ready!") { return TimeSpan.Zero; }
            return TimeSpan.Parse(s);
        }
    }

    [ValueConversion(typeof(bool), typeof(bool))]
    public class InverseBooleanConverter : IValueConverter {
        public object Convert(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture) {
            return !(bool)value;
        }

        public object ConvertBack(object value, Type targetType, object parameter, System.Globalization.CultureInfo culture) {
            return !(bool)value;
        }
    }
}
