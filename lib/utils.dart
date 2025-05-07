import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

Future<bool> getTrialStatus() async {
  final prefs = await SharedPreferences.getInstance();
  final installDateStr = prefs.getString('installDate');

  // Zurücksetzen des Tests
  /* await prefs.remove('installDate'); */

  if (installDateStr == null) {
    // Erststart: Datum speichern
    final now = DateTime.now();
    await prefs.setString('installDate', now.toIso8601String());
    return false; // Testzeitraum gerade begonnen
  }

  // Nur für Testzwecke: Setze das Installationsdatum auf vor 8 Tagen
  /* await prefs.setString(
    'installDate',
    DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
  ); */

  final installDate = DateTime.parse(installDateStr);
  final daysUsed = DateTime.now().difference(installDate).inDays;

  return daysUsed > 7;
}

Future<String> getEndDate() async {
  final prefs = await SharedPreferences.getInstance();
  final installDateStr = prefs.getString('installDate');

  if (installDateStr == null) {
    return 'N/A';
  }

  final installDate = DateTime.parse(installDateStr);
  final endDate = installDate.add(const Duration(days: 7));

  return DateFormat('dd.MM.yyyy').format(endDate);
}

Future<String> getRemainingTime() async {
  final prefs = await SharedPreferences.getInstance();
  final installDateStr = prefs.getString('installDate');

  if (installDateStr == null) {
    return 'N/A';
  }

  final installDate = DateTime.parse(installDateStr);
  final endDate = installDate.add(const Duration(days: 7));
  final now = DateTime.now();
  final remainingDays = endDate.difference(now).inDays + 1;

  final days = remainingDays < 0 ? 0 : remainingDays;
  return '$days Tag${days == 1 ? '' : 'e'}';
}

Future<void> resetInstallDate() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('installDate');
  await prefs.setString('installDate', DateTime.now().toIso8601String());
}
