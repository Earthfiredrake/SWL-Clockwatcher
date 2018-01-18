// Copyright 2018, Earthfiredrake
// Released under the terms of the MIT License
// https://github.com/Earthfiredrake/SWL-Clockwatcher

using System;
using System.Globalization;
using System.Timers;
using System.Windows;
using System.Windows.Data;

namespace Clockwatcher {
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window {
        public MainWindow() {
            InitializeComponent();
            DataContext = new Dataset();
            RefreshTimer.Elapsed += (sender, e) => Dispatcher.Invoke(() => (DataContext as Dataset)?.Refresh(false));
            RefreshTimer.Enabled = true;
        }

        private Timer RefreshTimer = new Timer(5000);
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
