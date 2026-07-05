import 'package:intl/intl.dart';

/// Centralised date formatting helpers so the whole app stays consistent.
class DateFormatter {
  DateFormatter._();

  static final DateFormat _dateFmt = DateFormat('d MMM yyyy');
  static final DateFormat _dateTimeFmt = DateFormat('d MMM yyyy · h:mm a');
  static final DateFormat _timeFmt = DateFormat('h:mm a');
  static final DateFormat _shortFmt = DateFormat('d MMM');

  static String date(DateTime dt, {String? locale}) => locale != null
      ? DateFormat('d MMM yyyy', locale).format(dt)
      : _dateFmt.format(dt);

  static String dateTime(DateTime dt, {String? locale}) => locale != null
      ? DateFormat('d MMM yyyy · H:mm', locale).format(dt)
      : _dateTimeFmt.format(dt);

  static String time(DateTime dt, {String? locale}) => locale != null
      ? DateFormat('H:mm', locale).format(dt)
      : _timeFmt.format(dt);

  static String shortDate(DateTime dt, {String? locale}) => locale != null
      ? DateFormat('d MMM', locale).format(dt)
      : _shortFmt.format(dt);

  static String relative(DateTime dt, {String? locale}) {
    final Duration diff = DateTime.now().difference(dt);
    final isFr = locale == 'fr';
    if (diff.inSeconds < 60) {
      return isFr ? "À l'instant" : 'Just now';
    }
    if (diff.inMinutes < 60) {
      return isFr ? 'Il y a ${diff.inMinutes} min' : '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return isFr ? 'Il y a ${diff.inHours} h' : '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) {
      return isFr ? 'Hier' : 'Yesterday';
    }
    if (diff.inDays < 7) {
      return isFr ? 'Il y a ${diff.inDays} j' : '${diff.inDays}d ago';
    }
    return date(dt, locale: locale);
  }
}
