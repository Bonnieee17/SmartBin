import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  Interpreter? _interpreter;
  bool _isLoaded = false;

  // Class labels
  final List<String> _labels = ['non_biodegradable', 'recyclable'];

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/waste_classifier.tflite');
      _isLoaded = true;
      debugPrint("ML Model loaded successfully");
    } catch (e) {
      debugPrint("Error loading ML model: $e");
    }
  }

  Future<String> classifyImage(File imageFile) async {
    if (!_isLoaded || _interpreter == null) {
      await loadModel();
      if (!_isLoaded) return "Model not loaded";
    }

    try {
      // 1. Read and preprocess image
      final imageBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return "Invalid image";

      // Resize to 224x224 as required by the model
      final resizedImage = img.copyResize(originalImage, width: 224, height: 224);
      
      // Convert to input format (Float32 [1, 224, 224, 3])
      var input = List.generate(
        1,
        (i) => List.generate(
          224,
          (j) => List.generate(
            224,
            (k) => List.generate(3, (l) => 0.0),
          ),
        ),
      );

      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixel(x, y);
          // pixel.r, g, b are num (int or double) depending on format
          // MobileNetV2 usually expects [0, 1] or [-1, 1]
          input[0][y][x][0] = pixel.r.toDouble() / 255.0;
          input[0][y][x][1] = pixel.g.toDouble() / 255.0;
          input[0][y][x][2] = pixel.b.toDouble() / 255.0;
        }
      }

      // 2. Run Inference
      // Using a fixed shape list instead of .reshape if extension is missing
      var output = List.generate(1, (_) => List.filled(1, 0.0));
      
      _interpreter!.run(input, output);

      // 3. Process Result (Binary Sigmoid)
      double confidence = output[0][0];
      int classIndex = confidence > 0.5 ? 1 : 0;
      
      return _labels[classIndex];
    } catch (e) {
      debugPrint("Classification error: $e");
      return "Classification failed";
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}
