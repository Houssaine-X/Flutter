import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:universal_io/io.dart';

// Conditionally import tflite_flutter only on non-web platforms
import 'package:tflite_flutter/tflite_flutter.dart'
    if (dart.library.html) 'tflite_flutter_stub.dart';

class TFLiteClassifierService {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  // 36 classes - ALPHABETICALLY SORTED (matches training)
  final List<String> _labels = [
    'apple', 'banana', 'beetroot', 'bell pepper', 'cabbage',
    'capsicum', 'carrot', 'cauliflower', 'chilli pepper', 'corn',
    'cucumber', 'eggplant', 'garlic', 'ginger', 'grapes',
    'jalepeno', 'kiwi', 'lemon', 'lettuce', 'mango',
    'onion', 'orange', 'paprika', 'pear', 'peas',
    'pineapple', 'pomegranate', 'potato', 'raddish', 'soy beans',
    'spinach', 'sweetcorn', 'sweetpotato', 'tomato', 'turnip',
    'watermelon'
  ];

  bool get isModelLoaded => _isModelLoaded;

  /// Load the TFLite model from assets
  Future<void> loadModel() async {
    if (kIsWeb) {
      print('⚠️ TFLite not supported on web platform');
      _isModelLoaded = false;
      throw UnsupportedError('TFLite is not supported on web platform');
    }
    
    try {
      print('📦 Loading TFLite model...');
      
      // Load model from assets
      _interpreter = await Interpreter.fromAsset(
        'models/fruit_vegetable_classifier.tflite',
        options: InterpreterOptions()..threads = 4,
      );

      _isModelLoaded = true;
      print('✅ Model loaded successfully');
      print('📊 Input shape: ${_interpreter?.getInputTensor(0).shape}');
      print('📊 Output shape: ${_interpreter?.getOutputTensor(0).shape}');
    } catch (e) {
      print('❌ Error loading model: $e');
      _isModelLoaded = false;
      rethrow;
    }
  }

  /// Preprocess image for MobileNetV2
  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    // Resize to 224x224
    final resizedImage = img.copyResize(image, width: 224, height: 224);

    // Convert to normalized float array
    var input = List.generate(
      1,
      (i) => List.generate(
        224,
        (y) => List.generate(
          224,
          (x) => List.generate(3, (c) {
            final pixel = resizedImage.getPixel(x, y);
            double value;
            if (c == 0) {
              value = pixel.r.toDouble();
            } else if (c == 1) {
              value = pixel.g.toDouble();
            } else {
              value = pixel.b.toDouble();
            }
            // MobileNetV2 preprocessing: (x / 127.5) - 1.0
            return (value / 127.5) - 1.0;
          }),
        ),
      ),
    );

    return input;
  }

  /// Classify image from file path
  Future<Map<String, dynamic>> classifyImage(String imagePath) async {
    if (!_isModelLoaded) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    try {
      // Load and decode image
      final imageBytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      return await _runInference(image);
    } catch (e) {
      print('❌ Classification error: $e');
      rethrow;
    }
  }

  /// Classify image from bytes (for camera frames)
  Future<Map<String, dynamic>> classifyImageBytes(Uint8List imageBytes) async {
    if (!_isModelLoaded) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    try {
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      return await _runInference(image);
    } catch (e) {
      print('❌ Classification error: $e');
      rethrow;
    }
  }

  /// Run inference on preprocessed image
  Future<Map<String, dynamic>> _runInference(img.Image image) async {
    final startTime = DateTime.now();

    // Preprocess image
    final input = _preprocessImage(image);

    // Prepare output buffer
    var output = List.filled(1, List.filled(36, 0.0)).map((e) => e.toList()).toList();

    // Run inference
    _interpreter?.run(input, output);

    final inferenceTime = DateTime.now().difference(startTime).inMilliseconds;

    // Get predictions with confidence scores
    final predictions = <Map<String, dynamic>>[];
    for (int i = 0; i < output[0].length; i++) {
      predictions.add({
        'label': _labels[i],
        'confidence': output[0][i],
      });
    }

    // Sort by confidence
    predictions.sort((a, b) => 
      (b['confidence'] as double).compareTo(a['confidence'] as double)
    );

    return {
      'predictions': predictions.take(5).toList(),
      'topLabel': predictions[0]['label'],
      'topConfidence': predictions[0]['confidence'],
      'inferenceTime': inferenceTime,
    };
  }

  /// Dispose interpreter
  void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
    print('🗑️ Model disposed');
  }
}
