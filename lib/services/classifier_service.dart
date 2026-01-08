import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ClassifierService {
  bool _isLoaded = false;
  // Use 192.168.1.4 (your PC's IP) so mobile can reach the backend
  // Change this to your PC's actual IP if different
  final String _backendUrl = 'http://192.168.1.4:8000';

  Future<void> loadModel() async {
    try {
      // Check if backend is available
      final response = await http.get(Uri.parse('$_backendUrl/health')).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Backend not available');
        },
      );
      
      if (response.statusCode == 200) {
        _isLoaded = true;
        print('Classifier backend connected');
      } else {
        throw Exception('Backend returned status ${response.statusCode}');
      }
    } catch (e) {
      print('Warning: Backend not available, using fallback: $e');
      // Still mark as loaded to allow operation with fallback
      _isLoaded = true;
    }
  }

  Future<Map<String, double>> classifyImage(Uint8List imageBytes) async {
    if (!_isLoaded) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    try {
      // Try to use backend API for classification
      final response = await http.post(
        Uri.parse('$_backendUrl/classify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image': base64Encode(imageBytes),
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Classification request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, double>.from(data['predictions'] ?? {});
      } else {
        throw Exception('Classification failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error using backend, using fallback: $e');
      return _fallbackClassification(imageBytes);
    }
  }

  Future<Map<String, double>> _fallbackClassification(Uint8List imageBytes) async {
    // Fallback when backend is not available
    // Return message indicating backend is needed
    return {
      'Error: Backend Required': 1.0,
      'Start backend server': 0.9,
      'Run: python backend/rag_api.py': 0.8,
    };
  }

  void dispose() {
    // Clean up resources if needed
  }
}
