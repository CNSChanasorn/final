import 'dart:io';
import 'dart:developer' as dev;
import 'package:flutter_tflite/flutter_tflite.dart';

class TFliteService {
  static final TFliteService _instance = TFliteService._internal();
  bool _isModelLoaded = false;

  factory TFliteService() {
    return _instance;
  }

  TFliteService._internal();

  Future<void> loadModel() async {
    try {
      print('Loading TFLite model...');
      String? res = await Tflite.loadModel(
        model: "assets/model_unquant.tflite",
        labels: "assets/labels.txt",
        numThreads: 1,
        isAsset: true,
        useGpuDelegate: false,
      );
      dev.log("Model Loaded: $res");
      _isModelLoaded = true;
      print('TFLite model loaded successfully');
    } catch (e) {
      dev.log("Error loading model: $e");
      print('Failed to load model: $e');
      _isModelLoaded = false;
    }
  }

  Future<Map<String, dynamic>> classifyImage(String imagePath) async {
    if (!_isModelLoaded) {
      await loadModel();
      if (!_isModelLoaded) {
        return {'label': 'Error', 'confidence': 0.0};
      }
    }

    try {
      final file = File(imagePath);
      if (!file.existsSync()) {
        return {'label': 'Unknown', 'confidence': 0.0};
      }

      print('Classifying image: $imagePath');

      var output = await Tflite.runModelOnImage(
        path: imagePath,
        numResults: 3,
        threshold: 0.1,
        imageMean: 127.5,
        imageStd: 127.5,
      );

      print('Classification output: $output');

      if (output == null || output.isEmpty) {
        return {'label': 'Unknown', 'confidence': 0.0};
      }

      final result = output[0];
      final String label = result["label"]?.toString() ?? 'Unknown';
      final double confidence =
          (result["confidence"] as num?)?.toDouble() ?? 0.0;

      print('Top result: $label with confidence $confidence');

      return {
        'label': label,
        'confidence': confidence.clamp(0.0, 1.0),
        'topResults': output,
      };
    } catch (e) {
      dev.log("Error during classification: $e");
      print('Error during classification: $e');
      return {'label': 'Error', 'confidence': 0.0};
    }
  }

  Future<void> close() async {
    try {
      await Tflite.close();
      _isModelLoaded = false;
      print('Model closed');
    } catch (e) {
      dev.log("Error closing model: $e");
    }
  }

  bool get isModelLoaded => _isModelLoaded;
}
