using System.Collections.ObjectModel;
using System.Globalization;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Microsoft.Win32;

namespace CodexEyes;

public partial class MainWindow : Window
{
    private readonly UsageViewModel _viewModel = new();
    private readonly DispatcherTimer _refreshTimer;
    private FileSystemWatcher? _watcher;
    private DispatcherTimer? _copyHintTimer;
    private double _lastLeft;
    private double _lastTop;

    public MainWindow()
    {
        InitializeComponent();
        DataContext = _viewModel;
        _viewModel.PropertyChanged += (_, _) => Dispatcher.Invoke(UpdateView);
        _refreshTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(30) };
        _refreshTimer.Tick += (_, _) => _viewModel.Refresh();
    }

    private void Window_Loaded(object sender, RoutedEventArgs e)
    {
        RestorePosition();
        _viewModel.Refresh();
        StartWatcher();
        _refreshTimer.Start();
        _ = LoadAvatarAsync(_viewModel.Account.AvatarUrl);
    }

    private void Window_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        SavePosition();
        _watcher?.Dispose();
        _refreshTimer.Stop();
    }

    private void Window_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ButtonState == MouseButtonState.Pressed)
        {
            try { DragMove(); } catch (InvalidOperationException) { }
        }
    }

    private void Summary_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        Clipboard.SetText(_viewModel.SummaryText);
        _copyHintTimer?.Stop();
        _copyHintTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1.8) };
        var oldText = ResetText.Text;
        ResetText.Text = "摘要已复制";
        _copyHintTimer.Tick += (_, _) =>
        {
            ResetText.Text = oldText;
            _copyHintTimer?.Stop();
        };
        _copyHintTimer.Start();
    }

    private void StartWatcher()
    {
        var path = CodexPaths.Sessions;
        if (!Directory.Exists(path)) return;
        _watcher = new FileSystemWatcher(path, "*.jsonl")
        {
            IncludeSubdirectories = true,
            NotifyFilter = NotifyFilters.LastWrite | NotifyFilters.Size | NotifyFilters.FileName,
            EnableRaisingEvents = true
        };
        FileSystemEventHandler changed = (_, _) => Dispatcher.BeginInvoke(new Action(_viewModel.Refresh));
        RenamedEventHandler renamed = (_, _) => Dispatcher.BeginInvoke(new Action(_viewModel.Refresh));
        _watcher.Changed += changed;
        _watcher.Created += changed;
        _watcher.Deleted += changed;
        _watcher.Renamed += renamed;
    }

    private void UpdateView()
    {
        var percent = Math.Clamp(_viewModel.UsedPercent, 0, 100);
        PercentText.Text = percent.ToString("0", CultureInfo.InvariantCulture);
        UsageRing.Percent = percent;
        UsageRing.Accent = _viewModel.UsageAccent;
        ProgressFill.Width = 238 * percent / 100;
        ProgressFill.Background = new SolidColorBrush(_viewModel.UsageAccent);
        AccountName.Text = _viewModel.Account.Name;
        AvatarInitials.Text = _viewModel.Account.Initials;
        PlanType.Text = _viewModel.PlanType;
        ResetText.Text = _viewModel.ResetText;
        GeneratedTokens.Text = FormatTokens(_viewModel.GeneratedTokens);
        ContextTokens.Text = FormatTokens(_viewModel.ContextTokens);
    }

    private async Task LoadAvatarAsync(string? url)
    {
        if (string.IsNullOrWhiteSpace(url) || !Uri.TryCreate(url, UriKind.Absolute, out var uri)) return;
        try
        {
            using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
            var bytes = await client.GetByteArrayAsync(uri);
            await Dispatcher.InvokeAsync(() =>
            {
                var image = new BitmapImage();
                using var stream = new MemoryStream(bytes);
                image.BeginInit();
                image.CacheOption = BitmapCacheOption.OnLoad;
                image.StreamSource = stream;
                image.EndInit();
                image.Freeze();
                AvatarImage.Source = image;
                AvatarImage.Visibility = Visibility.Visible;
                AvatarInitials.Visibility = Visibility.Collapsed;
            });
        }
        catch { }
    }

    private void RestorePosition()
    {
        var workArea = SystemParameters.WorkArea;
        var savedLeft = (double?)Registry.CurrentUser.OpenSubKey(CodexPaths.RegistryKey)?.GetValue("Left");
        var savedTop = (double?)Registry.CurrentUser.OpenSubKey(CodexPaths.RegistryKey)?.GetValue("Top");
        Left = savedLeft.HasValue && savedLeft.Value > 0 && savedLeft.Value < SystemParameters.VirtualScreenWidth ? savedLeft.Value : workArea.Right - Width - 58;
        Top = savedTop.HasValue && savedTop.Value > 0 && savedTop.Value < SystemParameters.VirtualScreenHeight ? savedTop.Value : workArea.Top + 38;
        _lastLeft = Left;
        _lastTop = Top;
    }

    private void SavePosition()
    {
        if (double.IsNaN(Left) || double.IsNaN(Top)) return;
        using var key = Registry.CurrentUser.CreateSubKey(CodexPaths.RegistryKey);
        key?.SetValue("Left", Left);
        key?.SetValue("Top", Top);
        _lastLeft = Left;
        _lastTop = Top;
    }

    private static string FormatTokens(long count) => count switch
    {
        >= 1_000_000 => $"{count / 1_000_000d:0.00}M",
        >= 1_000 => $"{count / 1_000d:0.0}k",
        _ => count.ToString("N0", CultureInfo.InvariantCulture)
    };
}

public sealed class UsageRing : FrameworkElement
{
    public static readonly DependencyProperty PercentProperty = DependencyProperty.Register(nameof(Percent), typeof(double), typeof(UsageRing), new FrameworkPropertyMetadata(0d, FrameworkPropertyMetadataOptions.AffectsRender));
    public double Percent { get => (double)GetValue(PercentProperty); set => SetValue(PercentProperty, value); }
    private Color _accent = Color.FromRgb(139, 124, 255);
    public Color Accent { get => _accent; set { _accent = value; InvalidateVisual(); } }

    protected override void OnRender(DrawingContext drawingContext)
    {
        base.OnRender(drawingContext);
        var center = new Point(ActualWidth / 2, ActualHeight / 2);
        var radius = Math.Max(1, Math.Min(ActualWidth, ActualHeight) / 2 - 8);
        drawingContext.DrawEllipse(null, new Pen(new SolidColorBrush(Color.FromArgb(42, 255, 255, 255)), 8), center, radius, radius);
        var amount = Math.Clamp(Percent, 0, 100) * 3.6;
        if (amount > 0)
        {
            var start = PointOnCircle(center, radius, -90);
            var end = PointOnCircle(center, radius, -90 + amount);
            var geometry = new StreamGeometry();
            using (var context = geometry.Open())
            {
                context.BeginFigure(start, false, false);
                context.ArcTo(end, new Size(radius, radius), 0, amount > 180, SweepDirection.Clockwise, true, false);
            }
            geometry.Freeze();
            drawingContext.DrawGeometry(null, new Pen(new SolidColorBrush(Accent), 8) { StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round }, geometry);
        }
        var text = new FormattedText("用量", CultureInfo.GetCultureInfo("zh-CN"), FlowDirection.LeftToRight, new Typeface("Segoe UI"), 10, Brushes.White, 1.0);
        drawingContext.DrawText(text, new Point(center.X - text.Width / 2, center.Y - text.Height / 2));
    }

    private static Point PointOnCircle(Point center, double radius, double degrees)
    {
        var radians = degrees * Math.PI / 180;
        return new Point(center.X + radius * Math.Cos(radians), center.Y + radius * Math.Sin(radians));
    }
}

public static class CodexPaths
{
    public static string Root => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".codex");
    public static string Sessions => Path.Combine(Root, "sessions");
    public const string RegistryKey = "Software\\codexeyes";
}

public sealed class AccountProfile
{
    public string Name { get; init; } = "Codex";
    public string Email { get; init; } = "";
    public string Initials { get; init; } = "C";
    public string? AvatarUrl { get; init; }
    public bool IsAuthenticated { get; init; }
}

public sealed class UsageWindow
{
    public int Minutes { get; init; }
    public double Percent { get; init; }
    public DateTimeOffset? ResetAt { get; init; }
}

public sealed class UsageSnapshot
{
    public double UsedPercent { get; init; }
    public DateTimeOffset? ResetAt { get; init; }
    public string PlanType { get; init; } = "Codex";
    public long GeneratedTokens { get; init; }
    public long ContextTokens { get; init; }
    public bool HasData { get; init; }
}

public sealed class UsageViewModel : System.ComponentModel.INotifyPropertyChanged
{
    private UsageSnapshot _snapshot = new();
    public AccountProfile Account { get; } = CodexAccountReader.Read();
    public event System.ComponentModel.PropertyChangedEventHandler? PropertyChanged;
    public double UsedPercent => _snapshot.UsedPercent;
    public long GeneratedTokens => _snapshot.GeneratedTokens;
    public long ContextTokens => _snapshot.ContextTokens;
    public string PlanType => _snapshot.PlanType.ToUpperInvariant();
    public string ResetText => _snapshot.ResetAt is { } reset
        ? $"还剩 {Math.Max(0, (int)Math.Ceiling((reset - DateTimeOffset.Now).TotalDays))} 天 · {reset.ToLocalTime():M月 d日}重置"
        : Account.IsAuthenticated ? "等待 Codex 数据" : "请登录 Codex";
    public Color UsageAccent => UsedPercent >= 95 ? Color.FromRgb(250, 87, 110) : UsedPercent >= 80 ? Color.FromRgb(255, 161, 61) : Color.FromRgb(139, 124, 255);
    public Brush AccentBrush => new SolidColorBrush(UsageAccent);
    public string SummaryText => $"codexeyes · {Account.Name} · {UsedPercent:0}% · 生成 {FormatTokens(GeneratedTokens)} · 上下文 {FormatTokens(ContextTokens)} · {ResetText}";

    public void Refresh()
    {
        _snapshot = CodexUsageReader.Read();
        OnChanged(nameof(UsedPercent));
        OnChanged(nameof(GeneratedTokens));
        OnChanged(nameof(ContextTokens));
        OnChanged(nameof(PlanType));
        OnChanged(nameof(ResetText));
        OnChanged(nameof(UsageAccent));
        OnChanged(nameof(AccentBrush));
        OnChanged(nameof(SummaryText));
    }

    private void OnChanged(string name) => PropertyChanged?.Invoke(this, new(name));
    private static string FormatTokens(long count) => count >= 1_000_000 ? $"{count / 1_000_000d:0.00}M" : count >= 1_000 ? $"{count / 1_000d:0.0}k" : count.ToString(CultureInfo.InvariantCulture);
}

internal sealed class UsageRecord
{
    public DateTimeOffset Date { get; init; }
    public long Output { get; init; }
    public long Input { get; init; }
    public List<UsageWindow> Limits { get; init; } = [];
    public string? PlanType { get; init; }
}

internal static class CodexUsageReader
{
    public static UsageSnapshot Read()
    {
        if (!Directory.Exists(CodexPaths.Sessions)) return new();
        var allFiles = new List<List<UsageRecord>>();
        try
        {
            foreach (var file in Directory.EnumerateFiles(CodexPaths.Sessions, "*.jsonl", SearchOption.AllDirectories))
            {
                var records = ReadFile(file);
                if (records.Count > 0) allFiles.Add(records);
            }
        }
        catch { return new(); }
        if (allFiles.Count == 0) return new();

        var all = allFiles.SelectMany(x => x).ToList();
        var latest = all.MaxBy(x => x.Date);
        var latestWindows = new Dictionary<int, (DateTimeOffset Date, UsageWindow Limit)>();
        foreach (var record in all)
        foreach (var limit in record.Limits)
            if (!latestWindows.TryGetValue(limit.Minutes, out var current) || record.Date > current.Date)
                latestWindows[limit.Minutes] = (record.Date, limit);

        var main = latestWindows.Values.OrderBy(x => x.Limit.Minutes).LastOrDefault().Limit ?? latest?.Limits.FirstOrDefault();
        var resetAt = main?.ResetAt;
        var minutes = main?.Minutes > 0 ? main.Minutes : 10080;
        var windowStart = resetAt?.AddMinutes(-minutes) ?? DateTimeOffset.UtcNow.AddMinutes(-minutes);
        long outputTotal = 0;
        long inputTotal = 0;
        foreach (var records in allFiles)
        {
            long? previousOutput = null;
            long? previousInput = null;
            foreach (var record in records.OrderBy(x => x.Date))
            {
                if (record.Date < windowStart)
                {
                    previousOutput = record.Output;
                    previousInput = record.Input;
                    continue;
                }
                outputTotal += Math.Max(0, record.Output - (previousOutput ?? 0));
                inputTotal += Math.Max(0, record.Input - (previousInput ?? 0));
                previousOutput = record.Output;
                previousInput = record.Input;
            }
        }

        return new UsageSnapshot
        {
            UsedPercent = Math.Clamp(main?.Percent ?? latest?.Limits.FirstOrDefault()?.Percent ?? 0, 0, 100),
            ResetAt = resetAt,
            PlanType = latest?.PlanType ?? "Codex",
            GeneratedTokens = outputTotal,
            ContextTokens = inputTotal,
            HasData = true
        };
    }

    private static List<UsageRecord> ReadFile(string path)
    {
        var result = new List<UsageRecord>();
        try
        {
            foreach (var line in File.ReadLines(path))
            {
                try
                {
                    using var document = JsonDocument.Parse(line);
                    var root = document.RootElement;
                    if (!TryGet(root, "timestamp", out var timestamp) || !DateTimeOffset.TryParse(timestamp.GetString(), CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var date)) continue;
                    if (!TryGet(root, "payload", out var payload) || !TryGet(payload, "type", out var type) || type.GetString() != "token_count") continue;
                    if (!TryGet(payload, "info", out var info) || !TryGet(info, "total_token_usage", out var totals)) continue;
                    var input = Number(totals, "input_tokens");
                    var output = Number(totals, "output_tokens");
                    var limits = new List<UsageWindow>();
                    string? plan = null;
                    if (TryGet(payload, "rate_limits", out var rate))
                    {
                        plan = String(rate, "plan_type");
                        AddLimit(rate, "primary", limits);
                        AddLimit(rate, "secondary", limits);
                    }
                    result.Add(new UsageRecord { Date = date, Input = input, Output = output, Limits = limits, PlanType = plan });
                }
                catch (JsonException) { }
                catch (InvalidOperationException) { }
            }
        }
        catch (IOException) { }
        return result.OrderBy(x => x.Date).ToList();
    }

    private static void AddLimit(JsonElement parent, string name, ICollection<UsageWindow> output)
    {
        if (!TryGet(parent, name, out var item)) return;
        var minutes = (int)Number(item, "window_minutes");
        if (minutes <= 0) return;
        DateTimeOffset? reset = null;
        var seconds = Number(item, "resets_at");
        if (seconds > 0) reset = DateTimeOffset.FromUnixTimeSeconds(seconds);
        output.Add(new UsageWindow { Minutes = minutes, Percent = NumberDouble(item, "used_percent"), ResetAt = reset });
    }

    private static bool TryGet(JsonElement element, string name, out JsonElement value) => element.TryGetProperty(name, out value) || element.TryGetProperty(ToCamel(name), out value);
    private static string ToCamel(string name) => string.Concat(name.Split('_').Select((part, index) => index == 0 ? part : char.ToUpperInvariant(part[0]) + part[1..]));
    private static long Number(JsonElement element, string name) => TryGet(element, name, out var value) && value.TryGetInt64(out var number) ? number : 0;
    private static double NumberDouble(JsonElement element, string name) => TryGet(element, name, out var value) && value.TryGetDouble(out var number) ? number : 0;
    private static string? String(JsonElement element, string name) => TryGet(element, name, out var value) ? value.GetString() : null;
}

internal static class CodexAccountReader
{
    public static AccountProfile Read()
    {
        var path = Path.Combine(CodexPaths.Root, "auth.json");
        try
        {
            using var document = JsonDocument.Parse(File.ReadAllText(path));
            var root = document.RootElement;
            if (!TryGet(root, "tokens", out var tokens) || !TryGet(tokens, "id_token", out var token)) return new();
            var claims = DecodeClaims(token.GetString() ?? "");
            string? name = null;
            var email = "";
            string? avatar = null;
            if (claims is JsonElement claimElement)
            {
                name = claimElement.TryGetProperty("name", out var nameElement) ? nameElement.GetString() : null;
                email = claimElement.TryGetProperty("email", out var emailElement) ? emailElement.GetString() ?? "" : "";
                avatar = claimElement.TryGetProperty("picture", out var picture) ? picture.GetString() : null;
                avatar ??= claimElement.TryGetProperty("avatar_url", out var avatarElement) ? avatarElement.GetString() : null;
            }
            name = string.IsNullOrWhiteSpace(name) ? "Codex" : name.Trim();
            return new AccountProfile { Name = name, Email = email, AvatarUrl = avatar, Initials = Initials(name), IsAuthenticated = true };
        }
        catch { return new(); }
    }

    private static JsonElement? DecodeClaims(string token)
    {
        var parts = token.Split('.');
        if (parts.Length < 2) return null;
        var encoded = parts[1].Replace('-', '+').Replace('_', '/');
        encoded += new string('=', (4 - encoded.Length % 4) % 4);
        try
        {
            using var document = JsonDocument.Parse(Convert.FromBase64String(encoded));
            return document.RootElement.Clone();
        }
        catch { return null; }
    }

    private static string Initials(string name)
    {
        var parts = name.Split([' ', '-'], StringSplitOptions.RemoveEmptyEntries);
        return parts.Length > 1 ? string.Concat(parts.Take(2).Select(x => x[0])).ToUpperInvariant() : name[..Math.Min(2, name.Length)].ToUpperInvariant();
    }

    private static bool TryGet(JsonElement element, string name, out JsonElement value) => element.TryGetProperty(name, out value) || element.TryGetProperty(string.Concat(name.Split('_').Select((part, index) => index == 0 ? part : char.ToUpperInvariant(part[0]) + part[1..])), out value);
}
