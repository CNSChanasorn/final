import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import 'add_report_screen.dart';
import 'polling_station_list_screen.dart';
import 'report_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _totalReports = 0;
  List<Map<String, dynamic>> _topStations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _loading = true;
    });
    final total = await DatabaseHelper.instance.getTotalOfflineReports();
    final top3 = await DatabaseHelper.instance.getTop3ComplainedStations();
    if (!mounted) {
      return;
    }
    setState(() {
      _totalReports = total;
      _topStations = top3;
      _loading = false;
    });
  }

  Future<void> _navigateToAddReport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddReportScreen()),
    );
    await _loadStatistics();
  }

  Future<void> _navigateToReportList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReportListScreen()),
    );
    await _loadStatistics();
  }

  Future<void> _navigateToPollingStationList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PollingStationListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          const Text(
                            'Total Offline Reports',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_totalReports',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              SizedBox(width: 8),
                              Text(
                                'Top 3 Complained Stations',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_topStations.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No data available'),
                              ),
                            )
                          else
                            ..._topStations.map((station) {
                              final name = station['station_name'] as String;
                              final total = station['total'] as int;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$total reports',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _navigateToAddReport,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Report'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _navigateToReportList,
                    icon: const Icon(Icons.list),
                    label: const Text('View Reports'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _navigateToPollingStationList,
                    icon: const Icon(Icons.location_on),
                    label: const Text('Polling Stations'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
