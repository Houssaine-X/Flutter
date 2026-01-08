import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/gemini_service.dart';
import 'services/image_service.dart';
import 'services/google_tts_service.dart';

class VocalAssistant extends StatefulWidget {
  const VocalAssistant({super.key});

  static const String routeName = './vocal_assistant';

  @override
  State<VocalAssistant> createState() => _VocalAssistantState();
}

class _VocalAssistantState extends State<VocalAssistant> {
  late stt.SpeechToText _speech;
  late GoogleTtsService _tts;
  late GeminiService _geminiService;
  late ImageService _imageService;

  bool _isProcessing = false;
  bool _isSpeaking = false;
  
  // Conversation histories
  final List<Map<String, String>> _chatHistory = [];
  final List<Map<String, dynamic>> _imageHistory = []; // Changed to dynamic to store images
  
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  bool _isListeningForChat = false;
  bool _isListeningForImage = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    final apiKey = dotenv.env['GOOGLE_CLOUD_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint('Warning: GOOGLE_CLOUD_API_KEY not found in environment variables');
    }
    _tts = GoogleTtsService(apiKey: apiKey);
    _geminiService = GeminiService();
    _imageService = ImageService();

    _requestMicrophonePermission();
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
      }
    }
  }

  Future<void> _speak(String text) async {
    await _tts.speak(
      text,
      voiceName: 'fr-FR-Neural2-A', // French Female voice, change to Neural2-B for male
      speakingRate: 1.0,
      pitch: 0.0,
      onStart: () {
        setState(() {
          _isSpeaking = true;
        });
      },
      onComplete: () {
        setState(() {
          _isSpeaking = false;
        });
      },
    );
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();
    setState(() {
      _isProcessing = true;
      _chatHistory.add({'role': 'user', 'content': text});
    });

    try {
      final response = await _geminiService.generateText(text);
      
      setState(() {
        _chatHistory.add({'role': 'assistant', 'content': response});
        _isProcessing = false;
      });

      await _speak(response);
    } catch (e) {
      final errorMessage = 'Error: ${e.toString()}';
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  Future<void> _startListeningForChat() async {
    bool available = await _speech.initialize();

    if (available) {
      setState(() {
        _isListeningForChat = true;
      });

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _chatController.text = result.recognizedWords;
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _stopListeningForChat() async {
    await _speech.stop();
    setState(() {
      _isListeningForChat = false;
    });

    if (_chatController.text.isNotEmpty) {
      await _sendChatMessage();
    }
  }

  Future<void> _sendImageMessage() async {
    final text = _imageController.text.trim();
    if (text.isEmpty) return;

    _imageController.clear();
    setState(() {
      _isProcessing = true;
      _imageHistory.add({'role': 'user', 'content': text, 'type': 'text'});
    });

    try {
      // Generate the image using the ImageService
      final imageBytes = await _imageService.generateImageFromDetailedPrompt(text);
      
      setState(() {
        _imageHistory.add({
          'role': 'assistant',
          'content': imageBytes,
          'type': 'image',
          'prompt': text,
        });
        _isProcessing = false;
      });

      await _speak('Image generated successfully!');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Image generated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      final errorMessage = 'Error: ${e.toString()}';
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  Future<void> _startListeningForImage() async {
    bool available = await _speech.initialize();

    if (available) {
      setState(() {
        _isListeningForImage = true;
      });

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _imageController.text = result.recognizedWords;
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _stopListeningForImage() async {
    await _speech.stop();
    setState(() {
      _isListeningForImage = false;
    });

    if (_imageController.text.isNotEmpty) {
      await _sendImageMessage();
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _tts.dispose();
    _chatController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text(
            "AI Assistant",
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
          actions: [
            if (_isSpeaking)
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.stop_circle, color: Colors.red),
                  onPressed: _stopSpeaking,
                  tooltip: 'Stop speaking',
                ),
              ),
          ],
          bottom: const TabBar(
            labelColor: Color(0xFF3F51B5),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF3F51B5),
            tabs: [
              Tab(icon: Icon(Icons.chat), text: 'Chat'),
              Tab(icon: Icon(Icons.image), text: 'Image'),
            ],
          ),
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
                top: kToolbarHeight + kTextTabBarHeight + MediaQuery.of(context).padding.top,
              ),
              child: TabBarView(
                children: [
                  _buildChatTab(),
                  _buildImageTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: _chatHistory.isEmpty
              ? const Center(
                  child: Text(
                    'Start a conversation with AI!',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _chatHistory.length,
                  itemBuilder: (context, index) {
                    final message = _chatHistory[index];
                    final isUser = message['role'] == 'user';
                    
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.blue.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                message['content'] ?? '',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            if (!isUser) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.volume_up, size: 20),
                                onPressed: () => _speak(message['content'] ?? ''),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        
        // Chat Input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendChatMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _isListeningForChat ? Icons.stop : Icons.mic,
                  color: _isListeningForChat ? Colors.red : null,
                ),
                onPressed: _isListeningForChat ? _stopListeningForChat : _startListeningForChat,
                tooltip: 'Voice input',
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _isProcessing ? null : _sendChatMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageTab() {
    return Column(
      children: [
        Expanded(
          child: _imageHistory.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      '🎨 AI Image Generator\n\nDescribe an image and I\'ll generate it for you!',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _imageHistory.length,
                  itemBuilder: (context, index) {
                    final message = _imageHistory[index];
                    final isUser = message['role'] == 'user';
                    final type = message['type'] ?? 'text';
                    
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: type == 'image' ? EdgeInsets.zero : const EdgeInsets.all(16),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.85,
                        ),
                        decoration: BoxDecoration(
                          color: type == 'image' ? Colors.transparent : (isUser ? Colors.purple.shade100 : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: type == 'image'
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.memory(
                                      message['content'] as Uint8List,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Text(
                                      '💭 "${message['prompt']}"',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                message['content'] as String,
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    );
                  },
                ),
        ),
        
        // Image Input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _imageController,
                  decoration: InputDecoration(
                    hintText: 'Describe an image to generate...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendImageMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _isListeningForImage ? Icons.stop : Icons.mic,
                  color: _isListeningForImage ? Colors.red : null,
                ),
                onPressed: _isListeningForImage ? _stopListeningForImage : _startListeningForImage,
                tooltip: 'Voice input',
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _isProcessing ? null : _sendImageMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
