import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:test_app/services/stock_prediction_service.dart';

class StockPredictionPage extends StatefulWidget {
  const StockPredictionPage({super.key});

  @override
  State<StockPredictionPage> createState() => _StockPredictionPageState();
}

class _StockPredictionPageState extends State<StockPredictionPage> {
  final StockPredictionService _service = StockPredictionService();
  bool _isTraining = false;
  bool _isPredicting = false;
  bool _isModelTrained = false;
  String? _plotImage;
  Map<String, dynamic>? _metrics;
  String _stockSymbol = 'TATA';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
  }

  Future<void> _checkModelStatus() async {
    final health = await _service.checkHealth();
    if (mounted && health['lstm_model_trained'] != null) {
      setState(() {
        _isModelTrained = health['lstm_model_trained'] as bool;
      });
    }
  }

  Future<void> _trainModel() async {
    setState(() {
      _isTraining = true;
      _errorMessage = null;
    });

    final result = await _service.trainModel(stockSymbol: _stockSymbol);

    if (mounted) {
      setState(() {
        _isTraining = false;
        if (result['status'] == 'success') {
          _isModelTrained = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Model trained successfully! Loss: ${result['final_loss']?.toStringAsFixed(4)}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          _errorMessage = result['message'];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Training failed: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  Future<void> _predictStock() async {
    setState(() {
      _isPredicting = true;
      _errorMessage = null;
      _plotImage = null;
    });

    final result = await _service.predictStock(
      stockSymbol: _stockSymbol,
      train: !_isModelTrained,
    );

    if (mounted) {
      setState(() {
        _isPredicting = false;
        if (result['status'] == 'success') {
          _plotImage = result['plot'];
          _metrics = result['metrics'];
          if (!_isModelTrained) {
            _isModelTrained = true;
          }
        } else {
          _errorMessage = result['message'];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Prediction failed: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Stock Price Prediction',
          style: TextStyle(
            fontWeight: FontWeight.w700, 
            letterSpacing: -0.5,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Stack(
        children: [
          // Background Elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3F51B5).withOpacity(0.2),
                    const Color(0xFF7986CB).withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.purpleAccent.withOpacity(0.15),
                    Colors.blueAccent.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: 0,
            right: 0,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          SingleChildScrollView(
            padding: EdgeInsets.only(
              top: kToolbarHeight + MediaQuery.of(context).padding.top + 20,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.trending_up,
                          size: 48,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'LSTM Stock Price Prediction',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Train an LSTM neural network to predict stock prices',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isModelTrained ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isModelTrained ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isModelTrained ? Icons.check_circle : Icons.circle_outlined,
                                color: _isModelTrained ? Colors.green : Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isModelTrained ? 'Model Trained' : 'Model Not Trained',
                                style: TextStyle(
                                  color: _isModelTrained ? Colors.green : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Stock Symbol Selection
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Stock',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _stockSymbol,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.business),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'TATA', child: Text('TATA Global')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _stockSymbol = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isTraining ? null : _trainModel,
                        icon: _isTraining
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.school),
                        label: Text(_isTraining ? 'Training...' : 'Train Model'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isPredicting ? null : _predictStock,
                        icon: _isPredicting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.analytics),
                        label: Text(_isPredicting ? 'Predicting...' : 'Predict'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Error Message
                if (_errorMessage != null)
                  Card(
                    color: Colors.red[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Results
                if (_plotImage != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prediction Results',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E293B),
                                ),
                          ),
                          const SizedBox(height: 16),

                          // Metrics
                          if (_metrics != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMetricCard(
                                  'MSE',
                                  _metrics!['mse']?.toStringAsFixed(2) ?? 'N/A',
                                  Icons.straighten,
                                  Colors.blue,
                                ),
                                _buildMetricCard(
                                  'MAE',
                                  _metrics!['mae']?.toStringAsFixed(2) ?? 'N/A',
                                  Icons.trending_flat,
                                  Colors.orange,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Plot
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                base64Decode(_plotImage!),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'Black line: Actual prices | Green line: Predicted prices',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Info Card
                const SizedBox(height: 24),
                Card(
                  color: Colors.blue[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'About LSTM Model',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Uses 4 LSTM layers with 50 units each\n'
                          '• Trained on historical stock price data\n'
                          '• Predicts future price trends\n'
                          '• MSE: Mean Squared Error (lower is better)\n'
                          '• MAE: Mean Absolute Error (lower is better)',
                          style: TextStyle(color: Colors.blue[900], height: 1.5),
                        ),
                      ],
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

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
