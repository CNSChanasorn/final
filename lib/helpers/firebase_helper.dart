import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../models/incident_report.dart';
import '../models/polling_station.dart';
import '../models/violation_type.dart';

class FirebaseHelper {
  FirebaseHelper._();

  static final FirebaseHelper instance = FirebaseHelper._();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> upsertPollingStation(PollingStation station) async {
    await _firestore
        .collection(AppConstants.collectionPollingStation)
        .doc(station.stationId.toString())
        .set(station.toMap());
  }

  Future<void> upsertViolationType(ViolationType type) async {
    await _firestore
        .collection(AppConstants.collectionViolationType)
        .doc(type.typeId.toString())
        .set(type.toMap());
  }

  Future<bool> addReport(IncidentReport report) async {
    try {
      final data = report.toMap();
      data['isSynced'] = 1;
      if (report.reportId != null) {
        await _firestore
            .collection(AppConstants.collectionIncidentReport)
            .doc(report.reportId.toString())
            .set(data);
      } else {
        await _firestore
            .collection(AppConstants.collectionIncidentReport)
            .add(data);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<IncidentReport>> fetchReports() async {
    final snapshot = await _firestore
        .collection(AppConstants.collectionIncidentReport)
        .get();
    final result = <IncidentReport>[];
    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      if (!data.containsKey('report_id')) {
        final parsed = int.tryParse(doc.id);
        if (parsed != null) {
          data['report_id'] = parsed;
        }
      }
      data['isSynced'] = 1;
      result.add(IncidentReport.fromMap(data));
    }
    return result;
  }

  Future<void> updateReport(IncidentReport report) async {
    final data = report.toMap();
    data['isSynced'] = 1;
    if (report.reportId == null) {
      await _firestore
          .collection(AppConstants.collectionIncidentReport)
          .add(data);
      return;
    }
    await _firestore
        .collection(AppConstants.collectionIncidentReport)
        .doc(report.reportId.toString())
        .set(data);
  }

  Future<void> deleteReport(int reportId) async {
    await _firestore
        .collection(AppConstants.collectionIncidentReport)
        .doc(reportId.toString())
        .delete();
  }
}
