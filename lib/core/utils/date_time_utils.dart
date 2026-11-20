import 'package:intl/intl.dart';
import '../localization/app_strings.dart';

class DateTimeUtils {
  DateTimeUtils._();

  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String formatDate(DateTime dt, {String locale = 'vi'}) {
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  static String formatTime(DateTime dt) {
    return DateFormat('HH:mm').format(dt);
  }

  static String formatDateTime(DateTime dt, {String locale = 'vi'}) {
    return '${formatTime(dt)} • ${formatDate(dt, locale: locale)}';
  }

  static String formatMonthYear(DateTime dt, {String locale = 'vi'}) {
    if (locale == 'vi') {
      return 'Tháng ${dt.month}, ${dt.year}';
    }
    return DateFormat('MMMM yyyy', 'en_US').format(dt);
  }

  /// Formats live ticking countdown e.g. "Còn 02 ngày 04 giờ 18 phút" or "00:12:45".
  static String formatCountdown(DateTime target, DateTime now, AppStrings s) {
    final diff = target.difference(now);
    if (diff.isNegative) {
      if (diff.inSeconds.abs() < 60) return s.dueNow;
      return s.overdue;
    }

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;

    String pad(int n) => n.toString().padLeft(2, '0');

    if (days > 0) {
      return '${s.remainingPrefix} ${pad(days)} ${s.daysShort} ${pad(hours)} ${s.hoursShort} ${pad(minutes)} ${s.minutesShort}';
    }
    if (hours > 0) {
      return '${s.remainingPrefix} ${pad(hours)} ${s.hoursShort} ${pad(minutes)} ${s.minutesShort} ${pad(seconds)}s';
    }
    return '${s.remainingPrefix} ${pad(minutes)} ${s.minutesShort} ${pad(seconds)}s';
  }

  static String formatPreReminderOffset(int minutes, AppStrings s) {
    if (minutes >= 1440 && minutes % 1440 == 0) {
      final d = minutes ~/ 1440;
      return '$d ${s.daysShort}';
    }
    if (minutes >= 60 && minutes % 60 == 0) {
      final h = minutes ~/ 60;
      return '$h ${s.hoursShort}';
    }
    return '$minutes ${s.minutesShort}';
  }

  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}
