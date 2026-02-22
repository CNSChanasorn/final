class ViolationType {
  final int typeId;
  final String typeName;
  final String severity;

  const ViolationType({
    required this.typeId,
    required this.typeName,
    required this.severity,
  });

  Map<String, dynamic> toMap() {
    return {'type_id': typeId, 'type_name': typeName, 'severity': severity};
  }

  factory ViolationType.fromMap(Map<String, dynamic> map) {
    return ViolationType(
      typeId: map['type_id'] as int? ?? 0,
      typeName: map['type_name'] as String? ?? '',
      severity: map['severity'] as String? ?? '',
    );
  }
}
