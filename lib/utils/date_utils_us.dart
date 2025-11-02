import 'package:intl/intl.dart';

class DateUtilsUS {
  // MM/DD/YY
  static String formatShort(DateTime date) {
    return DateFormat('MM/dd/yy').format(date);
  }

  // MM/DD/YYYY
  static String formatLong(DateTime date) {
    return DateFormat('MM/dd/yyyy').format(date);
  }

  static String formatRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    if (start != null && end == null) return formatShort(start);
    if (start == null && end != null) return formatShort(end);
    return '${formatShort(start!)} – ${formatShort(end!)}';
  }
}


