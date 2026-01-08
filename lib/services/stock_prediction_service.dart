import 'dart:convert';
import 'package:http/http.dart' as http;

class StockPredictionService {
  static const String baseUrl = 'http://localhost:8000';
  
  Future<Map<String, dynamic>> trainModel({String stockSymbol = 'TATA'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/train_stock_model?stock_symbol=$stockSymbol'),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': 'error',
          'message': 'Failed to train model: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Connection error: $e'
      };
    }
  }
  
  Future<Map<String, dynamic>> predictStock({
    String stockSymbol = 'TATA',
    bool train = false
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict_stock?stock_symbol=$stockSymbol&train=$train'),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': 'error',
          'message': 'Failed to predict: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Connection error: $e'
      };
    }
  }
  
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': 'error',
          'message': 'Health check failed'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Connection error: $e'
      };
    }
  }
}
