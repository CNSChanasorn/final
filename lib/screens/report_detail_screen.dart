import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../helpers/database_helper.dart';
import '../models/incident_report.dart';
import '../services/tflite_service.dart';

class ReportDetailScreen extends StatefulWidget {
  final int reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  IncidentReport? _report;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  bool _classifying = false;
  String _stationName = '';
  String _typeName = '';
  List<StationItem> _stations = [];
  List<TypeItem> _types = [];
  int? _selectedStationId;
  int? _selectedTypeId;
  String _imagePath = '';
  String _aiResult = '';
  double _aiConfidence = 0.0;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _reporterController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    _reporterController.dispose();
    _descriptionController.dispose();
    TFliteService().close();
    super.dispose();
  }

  Future<void> _initializeModel() async {
    try {
      await TFliteService().loadModel();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load AI model: $e')));
      }
    }
  }

  Future<void> _selectImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _imagePath = image.path;
          _aiResult = '';
          _aiConfidence = 0.0;
          _classifying = true;
        });
        _classifyImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _classifyImage() async {
    if (_imagePath.isEmpty) {
      return;
    }
    try {
      final result = await TFliteService().classifyImage(_imagePath);
      if (mounted) {
        final String label = result['label'] as String? ?? 'Unknown';
        final double confidence = (result['confidence'] as num? ?? 0.0)
            .toDouble();
        setState(() {
          if (label != 'Error') {
            _aiResult = label;
            _aiConfidence = confidence.clamp(0.0, 1.0);
          } else {
            _aiResult = 'Classification failed';
            _aiConfidence = 0.0;
          }
          _classifying = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiResult = 'Error';
          _aiConfidence = 0.0;
          _classifying = false;
        });
      }
    }
  }

  Future<void> loadData() async {
    final report = await DatabaseHelper.instance.getReportById(widget.reportId);
    final stationsList = await DatabaseHelper.instance.getPollingStations();
    final typesList = await DatabaseHelper.instance.getViolationTypes();
    if (!mounted) {
      return;
    }
    String stationName = '';
    String typeName = '';
    if (report != null) {
      final station = await DatabaseHelper.instance.getPollingStationById(
        report.stationId,
      );
      final type = await DatabaseHelper.instance.getViolationTypeById(
        report.typeId,
      );
      stationName = station?.stationName ?? '';
      typeName = type?.typeName ?? '';
    }
    setState(() {
      _report = report;
      _stationName = stationName;
      _typeName = typeName;
      _stations = stationsList
          .map((s) => StationItem(id: s.stationId, name: s.stationName))
          .toList();
      _types = typesList
          .map(
            (t) =>
                TypeItem(id: t.typeId, name: t.typeName, severity: t.severity),
          )
          .toList();
      _selectedStationId = report?.stationId;
      _selectedTypeId = report?.typeId;
      _imagePath = report?.evidencePhoto ?? '';
      _aiResult = report?.aiResult ?? '';
      _aiConfidence = report?.aiConfidence ?? 0.0;
      _loading = false;
      _reporterController.text = report?.reporterName ?? '';
      _descriptionController.text = report?.description ?? '';
    });
    _initializeModel();
  }

  Future<void> updateReport(IncidentReport updated) async {
    await DatabaseHelper.instance.updateReport(updated);
    await DatabaseHelper.instance.updateSynced(updated.reportId ?? 0);
  }

  Future<void> _saveChanges() async {
    final report = _report;
    if (report == null) {
      return;
    }
    setState(() {
      _saving = true;
    });
    final updated = report.copyWith(
      reporterName: _reporterController.text.trim(),
      description: _descriptionController.text.trim(),
      evidencePhoto: _imagePath,
      aiResult: _aiResult,
      aiConfidence: _aiConfidence,
      stationId: _selectedStationId ?? report.stationId,
      typeId: _selectedTypeId ?? report.typeId,
      isSynced: 0,
    );
    await updateReport(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _report = updated;
      _editing = false;
    });
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report Detail')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final report = _report;
    if (report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report Detail')),
        body: const Center(child: Text('Report not found')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Detail'),
        actions: [
          if (!_editing)
            TextButton(
              onPressed: () {
                setState(() {
                  _editing = true;
                });
              },
              child: const Text('Edit'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _editing
            ? [
                _row('Report ID', report.reportId?.toString() ?? '-'),
                _row('Timestamp', report.timestamp),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: _selectedStationId,
                  decoration: const InputDecoration(labelText: 'Station'),
                  items: _stations
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStationId = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: _selectedTypeId,
                  decoration: const InputDecoration(
                    labelText: 'Violation Type',
                  ),
                  items: _types
                      .map(
                        (t) => DropdownMenuItem(
                          value: t.id,
                          child: Text('${t.name} (${t.severity})'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTypeId = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reporterController,
                  decoration: const InputDecoration(labelText: 'Reporter Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _selectImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _selectImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_imagePath.isNotEmpty) _buildEditImagePreview(),
                const SizedBox(height: 12),
                if (_classifying)
                  const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Classifying image...'),
                    ],
                  )
                else if (_aiResult.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Classification:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('Result: $_aiResult'),
                        Text(
                          'Confidence: ${(_aiConfidence * 100).toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
              ]
            : [
                _row('Report ID', report.reportId?.toString() ?? '-'),
                _row('Station', _stationName),
                _row('Violation Type', _typeName),
                _row('Timestamp', report.timestamp),
                _row('Reporter', report.reporterName),
                _row('Description', report.description),
                _row('Evidence Photo', report.evidencePhoto),
                const SizedBox(height: 12),
                if (report.evidencePhoto.isNotEmpty)
                  _buildImageSection(report.evidencePhoto),
                const SizedBox(height: 12),
                _row('AI Result', report.aiResult),
                _row('AI Confidence', report.aiConfidence.toStringAsFixed(2)),
              ],
      ),
      bottomNavigationBar: _editing
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _saving ? null : _saveChanges,
                child: Text(_saving ? 'Saving...' : 'Save Changes'),
              ),
            )
          : null,
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  Widget _buildImageSection(String imagePath) {
    final imageFile = File(imagePath);
    if (!imageFile.existsSync()) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('Image not found'),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Evidence Image:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            imageFile,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ],
    );
  }

  Widget _buildEditImagePreview() {
    final imageFile = File(_imagePath);
    if (!imageFile.existsSync()) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: Icon(Icons.broken_image, size: 48)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        imageFile,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}

class StationItem {
  final int id;
  final String name;

  StationItem({required this.id, required this.name});
}

class TypeItem {
  final int id;
  final String name;
  final String severity;

  TypeItem({required this.id, required this.name, required this.severity});
}
