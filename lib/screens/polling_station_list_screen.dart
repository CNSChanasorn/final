import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../models/polling_station.dart';

class PollingStationListScreen extends StatefulWidget {
  const PollingStationListScreen({super.key});

  @override
  State<PollingStationListScreen> createState() =>
      _PollingStationListScreenState();
}

class _PollingStationListScreenState extends State<PollingStationListScreen> {
  late Future<List<PollingStation>> _stationsFuture;

  @override
  void initState() {
    super.initState();
    _stationsFuture = DatabaseHelper.instance.getPollingStations();
  }

  void _refresh() {
    setState(() {
      _stationsFuture = DatabaseHelper.instance.getPollingStations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Polling Stations'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: FutureBuilder<List<PollingStation>>(
        future: _stationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final stations = snapshot.data ?? [];

          if (stations.isEmpty) {
            return const Center(child: Text('ไม่มีข้อมูลหน่วยเลือกตั้ง'));
          }

          return ListView.separated(
            itemCount: stations.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final station = stations[index];
              return ListTile(
                leading: CircleAvatar(child: Text('${station.stationId}')),
                title: Text(station.stationName),
                subtitle: Text('${station.zone} | ${station.province}'),
              );
            },
          );
        },
      ),
    );
  }
}
