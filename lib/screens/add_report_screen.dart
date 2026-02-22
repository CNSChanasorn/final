import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../helpers/database_helper.dart';
import '../helpers/sync_helper.dart';
import '../models/incident_report.dart';
import '../models/polling_station.dart';
import '../models/violation_type.dart';
import '../services/tflite_service.dart';

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  int? _stationId;
  int? _typeId;
  String _imagePath = '';
  String _aiResult = '';
  double _aiConfidence = 0.0;
  bool _saving = false;
  bool _classifying = false;
  late Future<List<dynamic>> _lookupFuture;

  @override
  void initState() {
    super.initState();
    _lookupFuture = Future.wait([
      DatabaseHelper.instance.getPollingStations(),
      DatabaseHelper.instance.getViolationTypes(),
    ]);
    _initializeModel();
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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    TFliteService().close(); // Fire and forget
    super.dispose();
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
            _aiResult = '';
            _aiConfidence = 0.0;
          }
          _classifying = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _classifying = false;
          _aiResult = '';
          _aiConfidence = 0.0;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Classification error: $e')));
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _selectImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _selectImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveReport() async {
    if (_stationId == null || _typeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select station and type')),
      );
      return;
    }
    if (_nameController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill required fields')),
      );
      return;
    }
    if (_imagePath.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an image')));
      return;
    }
    if (_aiResult.isEmpty || _aiConfidence <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for AI classification to complete'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final report = IncidentReport(
      stationId: _stationId!,
      typeId: _typeId!,
      reporterName: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      evidencePhoto: _imagePath,
      timestamp: DateTime.now().toIso8601String(),
      aiResult: _aiResult,
      aiConfidence: _aiConfidence,
      isSynced: 0,
    );

    await SyncHelper.addReportOfflineFirst(report);

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Report saved')));

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Report')),
      body: FutureBuilder<List<dynamic>>(
        future: _lookupFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load data'));
          }
          final stations = (snapshot.data?[0] as List<PollingStation>?) ?? [];
          final types = (snapshot.data?[1] as List<ViolationType>?) ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<int>(
                value: _stationId,
                decoration: const InputDecoration(labelText: 'Polling Station'),
                items: stations
                    .map(
                      (s) => DropdownMenuItem<int>(
                        value: s.stationId,
                        child: Text(s.stationName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _stationId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _typeId,
                decoration: const InputDecoration(labelText: 'Violation Type'),
                items: types
                    .map(
                      (t) => DropdownMenuItem<int>(
                        value: t.typeId,
                        child: Text('${t.typeName} (${t.severity})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _typeId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Reporter Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Evidence Photo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_imagePath.isEmpty)
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _classifying
                                    ? null
                                    : _showImageSourceDialog,
                                child: const Text('Select Image'),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_imagePath),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _classifying
                                  ? null
                                  : _showImageSourceDialog,
                              child: const Text('Change Image'),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      if (_classifying)
                        const Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Analyzing image...'),
                          ],
                        )
                      else if (_imagePath.isNotEmpty && _aiResult.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            const SizedBox(height: 12),
                            const Text(
                              'AI Classification Results',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Detected: $_aiResult',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Confidence: ${(_aiConfidence * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving || _classifying ? null : _saveReport,
                child: Text(_saving ? 'Saving...' : 'Save Report'),
              ),
            ],
          );
        },
      ),
    );
  }
}
