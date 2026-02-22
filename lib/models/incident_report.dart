class IncidentReport {
  final int? reportId;
  final int stationId;
  final int typeId;
  final String reporterName;
  final String description;
  final String evidencePhoto;
  final String timestamp;
  final String aiResult;
  final double aiConfidence;
  final int isSynced;

  const IncidentReport({
    this.reportId,
    required this.stationId,
    required this.typeId,
    required this.reporterName,
    required this.description,
    required this.evidencePhoto,
    required this.timestamp,
    required this.aiResult,
    required this.aiConfidence,
    required this.isSynced,
  });

  IncidentReport copyWith({
    int? reportId,
    int? stationId,
    int? typeId,
    String? reporterName,
    String? description,
    String? evidencePhoto,
    String? timestamp,
    String? aiResult,
    double? aiConfidence,
    int? isSynced,
  }) {
    return IncidentReport(
      reportId: reportId ?? this.reportId,
      stationId: stationId ?? this.stationId,
      typeId: typeId ?? this.typeId,
      reporterName: reporterName ?? this.reporterName,
      description: description ?? this.description,
      evidencePhoto: evidencePhoto ?? this.evidencePhoto,
      timestamp: timestamp ?? this.timestamp,
      aiResult: aiResult ?? this.aiResult,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'station_id': stationId,
      'type_id': typeId,
      'reporter_name': reporterName,
      'description': description,
      'evidence_photo': evidencePhoto,
      'timestamp': timestamp,
      'ai_result': aiResult,
      'ai_confidence': aiConfidence,
      'isSynced': isSynced,
    };
    if (reportId != null) {
      data['report_id'] = reportId;
    }
    return data;
  }

  factory IncidentReport.fromMap(Map<String, dynamic> map) {
    return IncidentReport(
      reportId: map['report_id'] as int?,
      stationId: map['station_id'] as int? ?? 0,
      typeId: map['type_id'] as int? ?? 0,
      reporterName: map['reporter_name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      evidencePhoto: map['evidence_photo'] as String? ?? '',
      timestamp: map['timestamp'] as String? ?? '',
      aiResult: map['ai_result'] as String? ?? '',
      aiConfidence: (map['ai_confidence'] as num?)?.toDouble() ?? 0.0,
      isSynced: map['isSynced'] as int? ?? 0,
    );
  }
}
