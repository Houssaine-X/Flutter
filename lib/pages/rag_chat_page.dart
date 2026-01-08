import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:test_app/services/rag_service.dart';
import 'package:http/http.dart' as http;

class RagChatPage extends StatefulWidget {
  const RagChatPage({super.key});

  @override
  State<RagChatPage> createState() => _RagChatPageState();
}

class _RagChatPageState extends State<RagChatPage> {
  final RagService _ragService = RagService();
  final TextEditingController _questionController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  
  bool _isLoading = false;
  bool _isPdfUploaded = false;
  String _selectedModel = "LLaMA-2";
  double _temperature = 0.7;
  int _maxTokens = 512;

  @override
  void dispose() {
    _questionController.dispose();
    _ragService.deleteSession();
    super.dispose();
  }

  Future<void> _pickAndUploadPdf() async {
    try {
      // Pick PDF files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() => _isLoading = true);

        // Convert to MultipartFile for web compatibility
        List<http.MultipartFile> files = [];
        for (var file in result.files) {
          if (file.bytes != null) {
            files.add(http.MultipartFile.fromBytes(
              'files',
              file.bytes!,
              filename: file.name,
            ));
          }
        }

        // Upload to backend with current settings
        await _ragService.uploadPdfBytes(
          files: files,
          model: _selectedModel,
          maxTokens: _maxTokens,
          temperature: _temperature,
        );

        setState(() {
          _isPdfUploaded = true;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ PDFs uploaded with $_selectedModel model!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearSession() async {
    setState(() {
      _isPdfUploaded = false;
      _messages.clear();
    });
    await _ragService.deleteSession();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session cleared. Upload PDFs to start a new session.'),
        ),
      );
    }
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    if (!_isPdfUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please upload PDF files first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'content': question});
      _isLoading = true;
    });
    _questionController.clear();

    try {
      final response = await _ragService.askQuestion(question);
      
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': response['answer'] ?? 'No answer received'
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Error: ${e.toString()}'
        });
        _isLoading = false;
      });
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RAG Settings'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Model', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedModel,
                isExpanded: true,
                items: ["Hugging Face", "LLaMA-2"].map((model) {
                  return DropdownMenuItem(value: model, child: Text(model));
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => _selectedModel = value!);
                },
              ),
              const SizedBox(height: 16),
              Text('Temperature: ${_temperature.toStringAsFixed(1)}'),
              Slider(
                value: _temperature,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                onChanged: (value) {
                  setDialogState(() => _temperature = value);
                },
              ),
              const SizedBox(height: 8),
              Text('Max Tokens: $_maxTokens'),
              Slider(
                value: _maxTokens.toDouble(),
                min: 128,
                max: 2048,
                divisions: 15,
                onChanged: (value) {
                  setDialogState(() => _maxTokens = value.toInt());
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'RAG Chatbot',
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
          Padding(
            padding: EdgeInsets.only(
              top: kToolbarHeight + MediaQuery.of(context).padding.top,
            ),
            child: Row(
              children: [
                // Settings Sidebar
                Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'Settings',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      
                      // Upload Button
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _pickAndUploadPdf,
                        icon: const Icon(Icons.upload_file),
                        label: Text(_isPdfUploaded ? 'Re-upload PDFs' : 'Upload PDFs'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3F51B5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      
                      // Clear Session Button
                      if (_isPdfUploaded)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton.icon(
                            onPressed: _clearSession,
                            icon: const Icon(Icons.clear_all, size: 18),
                            label: const Text('Clear Session'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      // Model Selection
                      const Text('Model', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          border: Border.all(color: Colors.blue[200]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.computer, color: Colors.blue[700]),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'LLaMA-2 (Local)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Temperature
                      Text('Temperature: ${_temperature.toStringAsFixed(1)}', 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Slider(
                  value: _temperature,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: _temperature.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() => _temperature = value);
                  },
                ),
                Text('0 = Focused, 1 = Creative', 
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                
                const SizedBox(height: 16),
                
                // Max Tokens
                Text('Max Tokens: $_maxTokens', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Slider(
                  value: _maxTokens.toDouble(),
                  min: 128,
                  max: 2048,
                  divisions: 15,
                  label: _maxTokens.toString(),
                  onChanged: (value) {
                    setState(() => _maxTokens = value.toInt());
                  },
                ),
                Text('Response length', 
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                
                const SizedBox(height: 24),
                
                // Model Info
                if (false)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      border: Border.all(color: Colors.orange[200]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.key, size: 16, color: Colors.orange[700]),
                            const SizedBox(width: 6),
                            Text(
                              'API Key Required',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.orange[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Set HUGGINGFACEHUB_API_TOKEN in backend/.env',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Status
                if (_isPdfUploaded)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      border: Border.all(color: Colors.green[200]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            const Text(
                              'Session Active',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Using: $_selectedModel',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Chat Area
          Expanded(
            child: Column(
              children: [
                // Status Banner
                if (!_isPdfUploaded)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.orange[100],
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Upload PDF files to start chatting',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
          
          // Messages List
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload a PDF and ask a question',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['role'] == 'user';
                      
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          constraints: const BoxConstraints(maxWidth: 500),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF3F51B5)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            message['content']!,
                            style: TextStyle(
                              color: isUser ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Loading Indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          
          // Input Field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questionController,
                    decoration: InputDecoration(
                      hintText: 'Ask a question...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _askQuestion(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF3F51B5),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _askQuestion,
                  ),
                ),
              ],
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    ),
        ],
      ),
    );
  }
}
