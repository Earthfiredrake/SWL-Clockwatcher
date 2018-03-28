// Copyright 2018, Earthfiredrake
// Released under the terms of the MIT License
// https://github.com/Earthfiredrake/SWL-Clockwatcher

using System;
using System.Globalization;
using System.Media;
using System.Windows;
using System.Windows.Data;
using System.Windows.Shell;

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
        }

        private void Context_RaiseAlert(object sender, EventArgs e) => Dispatcher.Invoke(EmitAlert);

        private void EmitAlert() {
            if (!IsActive || WindowState == WindowState.Minimized) {
                if (AlertSound.IsEnabled) {
                    AlertSound.Play();
                }// else { SystemSounds.Exclamation.Play(); }
                TaskbarItemInfo.ProgressState = TaskbarItemProgressState.Paused;
            }
        }

        private void ClearTaskbarAlert(object sender, EventArgs e) => TaskbarItemInfo.ProgressState = TaskbarItemProgressState.None;

        private void ResetAlertSound(object sender, RoutedEventArgs e) => AlertSound.Stop();
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
}
