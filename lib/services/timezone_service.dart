import 'package:hive/hive.dart';

/// 一个固定偏移的时区选项（暂不考虑夏令时）。
class Timezone {
  final String name;
  final String label;
  final double offsetHours;

  const Timezone({
    required this.name,
    required this.label,
    required this.offsetHours,
  });

  Duration get offset => Duration(minutes: (offsetHours * 60).round());
}

/// 时区服务：统一管理服务器时间的解析与显示时区转换。
///
/// 假设：
///   - 服务器返回的无时区字符串代表服务器本地时间（默认 UTC+8，北京）。
///   - 带时区（Z 或 +/-）的字符串按标准解析为 UTC。
///   - 最终显示时间 = 选定时区偏移后的本地时间。
class TimezoneService {
  const TimezoneService._();

  static late Box _box;
  static Timezone? _selected;

  static const _key = 'selected_timezone';

  /// 服务器本地时区偏移（北京/上海 UTC+8）。
  static const double serverOffsetHours = 8;

  static Future<void> init() async {
    _box = await Hive.openBox('settings');
  }

  static List<Timezone> get supported => const [
    Timezone(name: 'UTC', label: 'UTC', offsetHours: 0),
    Timezone(name: 'Asia/Shanghai', label: '北京/上海 (UTC+8)', offsetHours: 8),
    Timezone(name: 'Asia/Tokyo', label: '东京/首尔 (UTC+9)', offsetHours: 9),
    Timezone(name: 'Asia/Bangkok', label: '曼谷/河内 (UTC+7)', offsetHours: 7),
    Timezone(name: 'Asia/Singapore', label: '新加坡 (UTC+8)', offsetHours: 8),
    Timezone(name: 'Asia/Dubai', label: '迪拜 (UTC+4)', offsetHours: 4),
    Timezone(name: 'Asia/Kolkata', label: '孟买/新德里 (UTC+5:30)', offsetHours: 5.5),
    Timezone(name: 'Europe/London', label: '伦敦 (UTC+0)', offsetHours: 0),
    Timezone(name: 'Europe/Paris', label: '巴黎/柏林 (UTC+1)', offsetHours: 1),
    Timezone(name: 'Europe/Moscow', label: '莫斯科 (UTC+3)', offsetHours: 3),
    Timezone(name: 'America/New_York', label: '纽约 (UTC-5)', offsetHours: -5),
    Timezone(name: 'America/Los_Angeles', label: '洛杉矶 (UTC-8)', offsetHours: -8),
    Timezone(name: 'Australia/Sydney', label: '悉尼 (UTC+10)', offsetHours: 10),
    Timezone(name: 'Pacific/Auckland', label: '奥克兰 (UTC+12)', offsetHours: 12),
  ];

  static Timezone _beijing() =>
      supported.firstWhere((t) => t.name == 'Asia/Shanghai');

  static Timezone get selected {
    if (_selected != null) return _selected!;
    final saved = _box.get(_key) as String?;
    _selected = supported.firstWhere(
      (t) => t.name == saved,
      orElse: _beijing,
    );
    return _selected!;
  }

  static Future<void> setSelected(Timezone tz) async {
    _selected = tz;
    await _box.put(_key, tz.name);
  }

  /// 把服务器时间转换为当前选定时区的本地时间。
  static DateTime convert(DateTime serverDt) {
    final utc = serverDt.isUtc ? serverDt : _toUtc(serverDt);
    return utc.add(selected.offset);
  }

  /// 解析 API 返回的时间字符串。无时区时按服务器本地时区解析。
  static DateTime? parseServerDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return null;
    if (dt.isUtc) return dt;
    return _toUtc(dt);
  }

  static DateTime _toUtc(DateTime serverLocal) {
    final serverOffset = Duration(
      minutes: (serverOffsetHours * 60).round(),
    );
    return DateTime.utc(
      serverLocal.year,
      serverLocal.month,
      serverLocal.day,
      serverLocal.hour,
      serverLocal.minute,
      serverLocal.second,
      serverLocal.millisecond,
      serverLocal.microsecond,
    ).subtract(serverOffset);
  }

  /// 格式化 API 时间字符串。
  static String format(
    String? raw, {
    bool showDate = true,
    bool showTime = true,
  }) {
    final dt = parseServerDateTime(raw);
    if (dt == null) return raw ?? '';
    return formatDateTime(dt, showDate: showDate, showTime: showTime);
  }

  /// 格式化已解析的服务器时间（应为 UTC）。
  static String formatDateTime(
    DateTime dt, {
    bool showDate = true,
    bool showTime = true,
  }) {
    final local = convert(dt);
    final y = local.year.toString().substring(2);
    final m = local.month;
    final d = local.day;
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    if (showDate && showTime) return '$y.$m.$d-$h:$mi';
    if (showDate) return '$y.$m.$d';
    return '$h:$mi';
  }

  static String formatDateTimeNullable(
    DateTime? dt, {
    bool showDate = true,
    bool showTime = true,
  }) {
    if (dt == null) return '';
    return formatDateTime(dt, showDate: showDate, showTime: showTime);
  }
}
