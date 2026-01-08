import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:test_app/services/tflite_classifier_service.dart';
import 'dart:async';

class RealtimeCameraClassifier extends StatefulWidget {
  const RealtimeCameraClassifier({super.key});

  @override
  State<RealtimeCameraClassifier> createState() => _RealtimeCameraClassifierState();
}

class _RealtimeCameraClassifierState extends State<RealtimeCameraClassifier> {
  CameraController? _cameraController;
  final TFLiteClassifierService _classifier = TFLiteClassifierService();
  
  bool _isInitialized = false;
  bool _isClassifying = false;
  bool _isProcessing = false;
  Timer? _classificationTimer;
  
  String _topLabel = '';
  double _topConfidence = 0.0;
  List<Map<String, dynamic>> _predictions = [];
  int _inferenceTime = 0;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera classification is not available on web. Please use mobile or desktop app.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    
    try {
      // Load TFLite model
      await _classifier.loadModel();

      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      // Use back camera (index 0) or front if not available
      final camera = cameras.first;

      // Initialize camera controller
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('❌ Camera initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startClassification() async {
    if (!_isInitialized || _isClassifying) return;

    setState(() {
      _isClassifying = true;
    });

    // Start continuous classification
    _classificationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!_isClassifying) {
        return;
      }

      if (_isProcessing) {
        return;
      }

      _isProcessing = true;

      try {
        // Capture image
        final image = await _cameraController!.takePicture();
        final imageBytes = await image.readAsBytes();

        // Classify
        final result = await _classifier.classifyImageBytes(imageBytes);

        if (mounted && _isClassifying) {
          setState(() {
            _topLabel = result['topLabel'];
            _topConfidence = result['topConfidence'];
            _predictions = result['predictions'];
            _inferenceTime = result['inferenceTime'];
          });
        }
      } catch (e) {
        print('⚠️ Classification error: $e');
      }

      _isProcessing = false;
    });
  }

  void _stopClassification() {
    _classificationTimer?.cancel();
    _classificationTimer = null;
    setState(() {
      _isClassifying = false;
      _isProcessing = false;
    });
  }

  @override
  void dispose() {
    _classificationTimer?.cancel();
    _cameraController?.dispose();
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Classification'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: !_isInitialized
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing camera...'),
                ],
              ),
            )
          : Column(
              children: [
                // Camera Preview
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Camera feed
                      CameraPreview(_cameraController!),

                      // Classification overlay
                      if (_isClassifying && _topLabel.isNotEmpty)
                        Positioned(
                          top: 20,
                          left: 20,
                          right: 20,
                          child: Card(
                            color: Colors.black87,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top prediction
                                  Row(
                                    children: [
                                      Text(
                                        _getEmoji(_topLabel),
                                        style: const TextStyle(fontSize: 32),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _topLabel.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${(_topConfidence * 100).toStringAsFixed(1)}% confident',
                                              style: TextStyle(
                                                color: Colors.green[300],
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: Colors.white24, height: 24),
                                  
                                  // Top 3 predictions
                                  ..._predictions.take(3).map((pred) {
                                    final label = pred['label'] as String;
                                    final confidence = pred['confidence'] as double;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              label,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: LinearProgressIndicator(
                                              value: confidence,
                                              backgroundColor: Colors.white24,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                _getConfidenceColor(confidence),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${(confidence * 100).toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),

                                  // Inference time
                                  const SizedBox(height: 8),
                                  Text(
                                    '⚡ ${_inferenceTime}ms',
                                    style: TextStyle(
                                      color: Colors.blue[300],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Status indicator
                      Positioned(
                        bottom: 100,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _isClassifying ? Colors.green : Colors.grey,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isClassifying ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isClassifying ? 'Classifying...' : 'Tap to start',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Control buttons
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.black87,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Start button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isClassifying ? null : _startClassification,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Stop button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isClassifying ? _stopClassification : null,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _getEmoji(String label) {
    const emojiMap = {
      'apple': '🍎',
      'banana': '🍌',
      'grapes': '🍇',
      'orange': '🍊',
      'lemon': '🍋',
      'watermelon': '🍉',
      'strawberry': '🍓',
      'mango': '🥭',
      'pineapple': '🍍',
      'kiwi': '🥝',
      'pear': '🍐',
      'carrot': '🥕',
      'tomato': '🍅',
      'corn': '🌽',
      'potato': '🥔',
      'eggplant': '🍆',
      'cucumber': '🥒',
      'bell pepper': '🫑',
      'chilli pepper': '🌶️',
      'garlic': '🧄',
      'onion': '🧅',
      'ginger': '🫚',
    };
    return emojiMap[label.toLowerCase()] ?? '🥗';
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.7) return Colors.green;
    if (confidence > 0.4) return Colors.orange;
    return Colors.red;
  }
}
