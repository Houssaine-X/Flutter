import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static String get _apiKey => dotenv.env['GOOGLE_CLOUD_API_KEY'] ?? '';
  late final GenerativeModel _model;

  GeminiService() {
    if (_apiKey.isEmpty) {
      throw Exception('GOOGLE_CLOUD_API_KEY not found in environment variables');
    }
    // Use gemini-1.5-flash for all tasks - it's fast and reliable
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
    );
  }

  Future<String> generateText(String prompt) async {
    final enhancedPrompt = '''
$prompt

Important: Your response will be read aloud by text-to-speech. Do NOT use markdown formatting like ** ** for bold, * * for italics, or any other markdown symbols. Write in plain text only.
''';
    final response = await _model.generateContent([Content.text(enhancedPrompt)]);
    return response.text ?? 'No response generated';
  }

  Future<String> chat(List<Map<String, String>> messages) async {
    final chat = _model.startChat(
      history: messages
          .take(messages.length - 1)
          .map((m) => Content(
                m['role'] == 'user' ? 'user' : 'model',
                [TextPart(m['content'] ?? '')],
              ))
          .toList(),
    );
    final lastMessage = messages.last['content'] ?? '';
    final response = await chat.sendMessage(Content.text(lastMessage));
    return response.text ?? 'No response generated';
  }

  Future<String> processVoiceInput(String transcribedText) async {
    try {
      final prompt = '''
You are a friendly and helpful voice assistant. Respond to the user's voice input in a natural, conversational way.
Keep your responses concise and clear since they will be spoken aloud.

IMPORTANT: Do NOT use markdown formatting like ** ** for bold, * * for italics, or any other markdown symbols. Write in plain text only since this will be read by text-to-speech.

User said: "$transcribedText"
Provide a helpful and natural response:
''';
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? 'No response generated';
    } catch (e) {
      throw Exception('Failed to process voice input: $e');
    }
  }

  Future<String> createImagePrompt(String description) async {
    try {
      final prompt = '''
Create a detailed, artistic image generation prompt based on this description: "$description"
The prompt should include:
- Visual style and artistic medium
- Lighting and atmosphere
- Color palette
- Composition and perspective
- Any important details
Format it as a single, cohesive prompt suitable for an AI image generator like DALL-E or Midjourney.
''';
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? 'No prompt generated';
    } catch (e) {
      throw Exception('Failed to create image prompt: $e');
    }
  }
}