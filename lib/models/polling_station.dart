class PollingStation {
  final int stationId;
  final String stationName;
  final String zone;
  final String province;

  const PollingStation({
    required this.stationId,
    required this.stationName,
    required this.zone,
    required this.province,
  });

  Map<String, dynamic> toMap() {
    return {
      'station_id': stationId,
      'station_name': stationName,
      'zone': zone,
      'province': province,
    };
  }

  factory PollingStation.fromMap(Map<String, dynamic> map) {
    return PollingStation(
      stationId: map['station_id'] as int? ?? 0,
      stationName: map['station_name'] as String? ?? '',
      zone: map['zone'] as String? ?? '',
      province: map['province'] as String? ?? '',
    );
  }
}
