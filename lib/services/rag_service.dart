import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';

class RagService {
  final String baseUrl;
  final String sessionId;

  RagService({
    this.baseUrl = 'http://localhost:8000',
  }) : sessionId = const Uuid().v4();

  /// Upload PDF files to the backend
  Future<Map<String, dynamic>> uploadPdfs({
    required List<String> filePaths,
    String model = "Hugging Face",
    int maxTokens = 512,
    double temperature = 0.7,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-pdf'),
      );

      // Add session parameters
      request.fields['session_id'] = sessionId;
      request.fields['model'] = model;
      request.fields['max_tokens'] = maxTokens.toString();
      request.fields['temperature'] = temperature.toString();

      // Add files
      for (var filePath in filePaths) {
        request.files.add(await http.MultipartFile.fromPath('files', filePath));
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        return json.decode(responseData);
      } else {
        throw Exception('Failed to upload PDFs: $responseData');
      }
    } catch (e) {
      throw Exception('Error uploading PDFs: $e');
    }
  }

  /// Upload PDF files from bytes (for web)
  Future<Map<String, dynamic>> uploadPdfBytes({
    required List<http.MultipartFile> files,
    String model = "Hugging Face",
    int maxTokens = 512,
    double temperature = 0.7,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-pdf'),
      );

      // Add session parameters
      request.fields['session_id'] = sessionId;
      request.fields['model'] = model;
      request.fields['max_tokens'] = maxTokens.toString();
      request.fields['temperature'] = temperature.toString();

      // Add files
      request.files.addAll(files);

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        return json.decode(responseData);
      } else {
        throw Exception('Failed to upload PDFs: $responseData');
      }
    } catch (e) {
      throw Exception('Error uploading PDFs: $e');
    }
  }

  /// Ask a question
  Future<Map<String, dynamic>> askQuestion(String question) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ask'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'session_id': sessionId,
          'question': question,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get answer: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error asking question: $e');
    }
  }

  /// Delete the session
  Future<void> deleteSession() async {
    try {
      await http.delete(Uri.parse('$baseUrl/session/$sessionId'));
    } catch (e) {
      print('Error deleting session: $e');
    }
  }
}
