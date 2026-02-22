import 'dart:io';
import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../models/incident_report.dart';
import '../models/polling_station.dart';
import '../models/violation_type.dart';
import 'report_detail_screen.dart';

class ReportListData {
  final List<IncidentReport> reports;
  final Map<int, String> stationMap;
  final Map<int, String> typeMap;

  const ReportListData({
    required this.reports,
    required this.stationMap,
    required this.typeMap,
  });
}

class ReportListScreen extends StatefulWidget {
  const ReportListScreen({super.key});

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  late Future<ReportListData> _dataFuture;
  late TextEditingController _searchController;
  List<IncidentReport> _filteredResults = [];
  bool _isFiltering = false;
  String _selectedSeverity = 'All';
  Map<int, String> _stationMap = {};
  Map<int, String> _typeMap = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadData();
      _searchController.clear();
      _filteredResults = [];
      _isFiltering = false;
      _selectedSeverity = 'All';
    });
  }

  Future<void> _performSearchAndFilter() async {
    final keyword = _searchController.text;
    final results = await DatabaseHelper.instance.searchAndFilterReports(
      keyword,
      _selectedSeverity,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _filteredResults = results;
      _isFiltering = keyword.isNotEmpty || _selectedSeverity != 'All';
    });
  }

  Future<void> _deleteReport(int reportId) async {
    await DatabaseHelper.instance.deleteReport(reportId);
    _refresh();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    int reportId,
    String reporterName,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Report'),
          content: Text(
            'Are you sure you want to delete report by $reporterName?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (result == true) {
      await _deleteReport(reportId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report deleted successfully')),
        );
      }
    }
  }

  Future<ReportListData> _loadData() async {
    final reports = await DatabaseHelper.instance.getAllReports();
    final stations = await DatabaseHelper.instance.getPollingStations();
    final types = await DatabaseHelper.instance.getViolationTypes();
    final stationMap = <int, String>{
      for (final PollingStation s in stations) s.stationId: s.stationName,
    };
    final typeMap = <int, String>{
      for (final ViolationType t in types) t.typeId: t.typeName,
    };
    return ReportListData(
      reports: reports,
      stationMap: stationMap,
      typeMap: typeMap,
    );
  }

  Future<String> _getSeverity(int typeId) async {
    final type = await DatabaseHelper.instance.getViolationTypeById(typeId);
    return type?.severity ?? 'Unknown';
  }

  Widget _buildReportList(List<IncidentReport> reports) {
    if (reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_isFiltering ? 'No records found' : 'No reports yet'),
        ),
      );
    }
    return ListView.separated(
      itemCount: reports.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final report = reports[index];
        final station = _stationMap[report.stationId] ?? 'Unknown Station';
        final type = _typeMap[report.typeId] ?? 'Unknown Type';
        final reportId = report.reportId;

        Widget thumbnail;
        if (report.evidencePhoto.isNotEmpty) {
          final imageFile = File(report.evidencePhoto);
          if (imageFile.existsSync()) {
            thumbnail = ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                imageFile,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            );
          } else {
            thumbnail = Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.broken_image, size: 30),
            );
          }
        } else {
          thumbnail = Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image, size: 30),
          );
        }

        return FutureBuilder<String>(
          future: _getSeverity(report.typeId),
          builder: (context, snapshot) {
            final severity = snapshot.data ?? 'Unknown';
            Color severityColor = Colors.grey;
            if (severity == 'High') {
              severityColor = Colors.red;
            } else if (severity == 'Medium') {
              severityColor = Colors.orange;
            } else if (severity == 'Low') {
              severityColor = Colors.green;
            }

            return ListTile(
              leading: thumbnail,
              title: Text(report.reporterName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$station | $type'),
                  if (report.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      report.description,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: severityColor, width: 1),
                        ),
                        child: Text(
                          severity,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: severityColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (report.aiResult.isNotEmpty)
                        Expanded(
                          child: Text(
                            'AI: ${report.aiResult} (${(report.aiConfidence * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        report.isSynced == 1
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                        size: 14,
                        color: report.isSynced == 1
                            ? Colors.green
                            : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        report.isSynced == 1 ? 'Synced' : 'Not synced',
                        style: TextStyle(
                          fontSize: 12,
                          color: report.isSynced == 1
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: reportId == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(
                        context,
                        reportId,
                        report.reporterName,
                      ),
                    ),
              onTap: () {
                if (reportId == null) {
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ReportDetailScreen(reportId: reportId),
                  ),
                ).then((_) => _refresh());
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report List'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<ReportListData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load reports'));
          }
          final data = snapshot.data;
          final allReports = data?.reports ?? [];
          _stationMap = data?.stationMap ?? {};
          _typeMap = data?.typeMap ?? {};

          final displayReports = _isFiltering ? _filteredResults : allReports;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) => _performSearchAndFilter(),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedSeverity,
                      decoration: InputDecoration(
                        labelText: 'Severity',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: ['All', 'High', 'Medium', 'Low']
                          .map(
                            (severity) => DropdownMenuItem(
                              value: severity,
                              child: Text(severity),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedSeverity = value;
                          });
                          _performSearchAndFilter();
                        }
                      },
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildReportList(displayReports)),
            ],
          );
        },
      ),
    );
  }
}
