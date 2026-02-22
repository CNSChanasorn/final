import '../models/incident_report.dart';
import '../models/polling_station.dart';
import '../models/violation_type.dart';
import 'database_helper.dart';
import 'firebase_helper.dart';

class SyncHelper {
  static Future<void> syncPendingData() async {
    await syncPendingReports();
  }

  static Future<void> syncAll() async {
    await _syncPollingStations();
    await _syncViolationTypes();
    await syncPendingReports();
  }

  static Future<void> refreshFromFirebase() async {
    final reports = await FirebaseHelper.instance.fetchReports();
    for (final report in reports) {
      if (report.reportId != null) {
        await DatabaseHelper.instance.upsertReport(report);
      }
    }
  }

  static Future<int> addReportOfflineFirst(IncidentReport report) async {
    final id = await DatabaseHelper.instance.insertReport(report);
    final local = report.copyWith(reportId: id);
    final synced = await FirebaseHelper.instance.addReport(local);
    if (synced) {
      await DatabaseHelper.instance.updateSynced(id);
    }
    return id;
  }

  static Future<void> syncPendingReports() async {
    final pending = await DatabaseHelper.instance.getUnsyncedReports();
    for (final report in pending) {
      final synced = await FirebaseHelper.instance.addReport(report);
      if (synced && report.reportId != null) {
        await DatabaseHelper.instance.updateSynced(report.reportId!);
      }
    }
  }

  static Future<void> _syncPollingStations() async {
    final stations = await DatabaseHelper.instance.getPollingStations();
    for (final PollingStation station in stations) {
      await FirebaseHelper.instance.upsertPollingStation(station);
    }
  }

  static Future<void> _syncViolationTypes() async {
    final types = await DatabaseHelper.instance.getViolationTypes();
    for (final ViolationType type in types) {
      await FirebaseHelper.instance.upsertViolationType(type);
    }
  }
}
