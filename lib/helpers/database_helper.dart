import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import '../constants/app_constants.dart';
import '../models/incident_report.dart';
import '../models/polling_station.dart';
import '../models/violation_type.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final filePath = path.join(dbPath, AppConstants.dbName);
    return openDatabase(
      filePath,
      version: AppConstants.dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedLookups(db);
      },
      onOpen: (db) async {
        await _createTables(db);
        await _seedLookups(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS ${AppConstants.tablePollingStation} ('
      'station_id INTEGER PRIMARY KEY, '
      'station_name TEXT, '
      'zone TEXT, '
      'province TEXT'
      ')',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS ${AppConstants.tableViolationType} ('
      'type_id INTEGER PRIMARY KEY, '
      'type_name TEXT, '
      'severity TEXT'
      ')',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS ${AppConstants.tableIncidentReport} ('
      'report_id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'station_id INTEGER, '
      'type_id INTEGER, '
      'reporter_name TEXT, '
      'description TEXT, '
      'evidence_photo TEXT, '
      'timestamp TEXT, '
      'ai_result TEXT, '
      'ai_confidence REAL, '
      'isSynced INTEGER, '
      'FOREIGN KEY (station_id) REFERENCES ${AppConstants.tablePollingStation}(station_id), '
      'FOREIGN KEY (type_id) REFERENCES ${AppConstants.tableViolationType}(type_id)'
      ')',
    );
  }

  Future<void> _seedLookups(Database db) async {
    final stationCount = await _tableCount(
      db,
      AppConstants.tablePollingStation,
    );
    final typeCount = await _tableCount(db, AppConstants.tableViolationType);
    if (stationCount == 0) {
      final batch = db.batch();
      batch.insert(AppConstants.tablePollingStation, {
        'station_id': 101,
        'station_name': 'โรงเรียนวัดพระมหาธาตุ',
        'zone': 'เขต 1',
        'province': 'นครศรีธรรมราช',
      });
      batch.insert(AppConstants.tablePollingStation, {
        'station_id': 102,
        'station_name': 'เต็นท์หน้าตลาดท่าวัง',
        'zone': 'เขต 1',
        'province': 'นครศรีธรรมราช',
      });
      batch.insert(AppConstants.tablePollingStation, {
        'station_id': 103,
        'station_name': 'ศาลากลางหมู่บ้านคีรีวง',
        'zone': 'เขต 2',
        'province': 'นครศรีธรรมราช',
      });
      batch.insert(AppConstants.tablePollingStation, {
        'station_id': 104,
        'station_name': 'หอประชุมอำเภอทุ่งสง',
        'zone': 'เขต 3',
        'province': 'นครศรีธรรมราช',
      });
      await batch.commit(noResult: true);
    }
    if (typeCount == 0) {
      final batch = db.batch();
      batch.insert(AppConstants.tableViolationType, {
        'type_id': 1,
        'type_name': 'ซื้อสิทธิ์ขายเสียง (Buying Votes)',
        'severity': 'High',
      });
      batch.insert(AppConstants.tableViolationType, {
        'type_id': 2,
        'type_name': 'ขนคนไปลงคะแนน (Transportation)',
        'severity': 'High',
      });
      batch.insert(AppConstants.tableViolationType, {
        'type_id': 3,
        'type_name': 'หาเสียงเกินเวลา (Overtime Campaign)',
        'severity': 'Medium',
      });
      batch.insert(AppConstants.tableViolationType, {
        'type_id': 4,
        'type_name': 'ทำลายป้ายหาเสียง (Vandalism)',
        'severity': 'Low',
      });
      batch.insert(AppConstants.tableViolationType, {
        'type_id': 5,
        'type_name': 'เจ้าหน้าที่วางตัวไม่เป็นกลาง (Bias Official)',
        'severity': 'High',
      });
      await batch.commit(noResult: true);
    }
  }

  Future<int> _tableCount(Database db, String table) async {
    final rows = await db.rawQuery('SELECT COUNT(*) as cnt FROM $table');
    final value = rows.isNotEmpty ? rows.first['cnt'] : 0;
    return (value as int?) ?? 0;
  }

  Future<int> insertReport(IncidentReport report) async {
    final db = await database;
    return db.insert(
      AppConstants.tableIncidentReport,
      report.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> upsertReport(IncidentReport report) async {
    final db = await database;
    return db.insert(
      AppConstants.tableIncidentReport,
      report.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<IncidentReport>> getAllReports() async {
    final db = await database;
    final rows = await db.query(
      AppConstants.tableIncidentReport,
      orderBy: 'report_id DESC',
    );
    return rows.map(IncidentReport.fromMap).toList();
  }

  Future<IncidentReport?> getReportById(int reportId) async {
    final db = await database;
    final rows = await db.query(
      AppConstants.tableIncidentReport,
      where: 'report_id = ?',
      whereArgs: [reportId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return IncidentReport.fromMap(rows.first);
  }

  Future<List<IncidentReport>> getUnsyncedReports() async {
    final db = await database;
    final rows = await db.query(
      AppConstants.tableIncidentReport,
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'report_id ASC',
    );
    return rows.map(IncidentReport.fromMap).toList();
  }

  Future<int> updateSynced(int reportId) async {
    final db = await database;
    return db.update(
      AppConstants.tableIncidentReport,
      {'isSynced': 1},
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
  }

  Future<List<String>> getUniqueReporters() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT reporter_name 
      FROM ${AppConstants.tableIncidentReport}
      WHERE reporter_name IS NOT NULL AND reporter_name != ''
      ORDER BY reporter_name ASC
    ''');
    return rows.map((row) => row['reporter_name'] as String).toList();
  }

  Future<int> updateReport(IncidentReport report) async {
    final db = await database;
    final data = report.toMap();
    data.remove('report_id');
    return db.update(
      AppConstants.tableIncidentReport,
      data,
      where: 'report_id = ?',
      whereArgs: [report.reportId],
    );
  }

  Future<int> deleteReport(int reportId) async {
    final db = await database;
    return db.delete(
      AppConstants.tableIncidentReport,
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
  }

  Future<List<PollingStation>> getPollingStations() async {
    final db = await database;
    final rows = await db.query(
      AppConstants.tablePollingStation,
      orderBy: 'station_id ASC',
    );
    return rows.map(PollingStation.fromMap).toList();
  }

  Future<PollingStation?> getPollingStationById(int id) async {
    final db = await database;
    final rows = await db.query(
      AppConstants.tablePollingStation,
      where: 'station_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return PollingStation.fromMap(rows.first);
  }

  Future<List<ViolationType>> getViolationTypes() async {
    final db = await database;
    final rows = await db.query(
      AppConstants.tableViolationType,
      orderBy: 'type_id ASC',
    );
    return rows.map(ViolationType.fromMap).toList();
  }

  Future<ViolationType?> getViolationTypeById(int id) async {
    final db = await database;
    final rows = await db.query(
      AppConstants.tableViolationType,
      where: 'type_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ViolationType.fromMap(rows.first);
  }

  Future<int> getTotalOfflineReports() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${AppConstants.tableIncidentReport}',
    );
    final value = rows.isNotEmpty ? rows.first['cnt'] : 0;
    return (value as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getTop3ComplainedStations() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT polling_station.station_name, COUNT(incident_report.report_id) AS total '
      'FROM incident_report '
      'JOIN polling_station ON incident_report.station_id = polling_station.station_id '
      'GROUP BY incident_report.station_id '
      'ORDER BY total DESC '
      'LIMIT 3',
    );
    return rows;
  }

  Future<List<IncidentReport>> searchReports(String keyword) async {
    final db = await database;
    if (keyword.isEmpty) {
      final rows = await db.rawQuery(
        'SELECT * FROM ${AppConstants.tableIncidentReport} ORDER BY timestamp DESC',
      );
      return rows.map(IncidentReport.fromMap).toList();
    }
    final searchPattern = '%$keyword%';
    final rows = await db.rawQuery(
      'SELECT * FROM ${AppConstants.tableIncidentReport} '
      'WHERE LOWER(COALESCE(reporter_name, \'\')) LIKE LOWER(?) '
      'OR LOWER(COALESCE(description, \'\')) LIKE LOWER(?) '
      'ORDER BY timestamp DESC',
      [searchPattern, searchPattern],
    );
    return rows.map(IncidentReport.fromMap).toList();
  }

  Future<List<IncidentReport>> searchAndFilterReports(
    String keyword,
    String severity,
  ) async {
    final db = await database;
    if (keyword.isEmpty && severity == 'All') {
      final rows = await db.rawQuery(
        'SELECT incident_report.* '
        'FROM ${AppConstants.tableIncidentReport} '
        'ORDER BY incident_report.timestamp DESC',
      );
      return rows.map(IncidentReport.fromMap).toList();
    }
    final searchPattern = '%$keyword%';
    final rows = await db.rawQuery(
      'SELECT incident_report.* '
      'FROM ${AppConstants.tableIncidentReport} '
      'JOIN ${AppConstants.tableViolationType} '
      'ON incident_report.type_id = violation_type.type_id '
      'WHERE '
      '(incident_report.reporter_name LIKE ? OR incident_report.description LIKE ?) '
      'AND '
      '(? = ? OR violation_type.severity = ?) '
      'ORDER BY incident_report.timestamp DESC',
      [searchPattern, searchPattern, 'All', severity, severity],
    );
    return rows.map(IncidentReport.fromMap).toList();
  }
}
