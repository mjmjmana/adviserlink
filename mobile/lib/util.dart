import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';

const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String? imageMimeType(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseYmd(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime startOfWeek(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1)); // Lunes ang simula

List<DateTime> monthGrid(DateTime d) {
  final start = startOfWeek(DateTime(d.year, d.month, 1));
  return List.generate(42, (i) => DateTime(start.year, start.month, start.day + i));
}

String fmtTime(String hhmm) {
  final parts = hhmm.split(':');
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

String fmtDateLong(DateTime d) => '${weekdayNames[d.weekday - 1]}, ${monthNames[d.month - 1].substring(0, 3)} ${d.day}';

String firstName(String name) {
  final cleaned = name.replaceFirst(RegExp(r'^(Engr\.|Dr\.|Prof\.)\s+', caseSensitive: false), '');
  return cleaned.split(' ').first;
}

Uri? meetingUri(String value) {
  final link = value.trim();
  if (link.isEmpty || RegExp(r'\s').hasMatch(link)) return null;
  final candidate = RegExp(r'^https?://', caseSensitive: false).hasMatch(link)
      ? link
      : 'https://$link';
  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      uri.host.isEmpty ||
      !(uri.host.toLowerCase() == 'localhost' ||
          uri.host.contains('.') ||
          uri.host.contains(':')) ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

Future<bool> launchMeetingLink(String value) async {
  final uri = meetingUri(value);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
