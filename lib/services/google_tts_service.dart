import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

class GoogleTtsService {
  final String apiKey;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSpeaking = false;

  GoogleTtsService({required this.apiKey});

  bool get isSpeaking => _isSpeaking;

  /// Synthesizes text to speech using Google Cloud TTS
  /// voiceName options: 
  /// English: 'en-US-Neural2-A' to 'en-US-Neural2-J' (most natural)
  /// French: 'fr-FR-Neural2-A' to 'fr-FR-Neural2-E' (most natural)
  /// For more languages: https://cloud.google.com/text-to-speech/docs/voices
  Future<void> speak(
    String text, {
    String voiceName = 'en-US-Neural2-C', // Female voice
    double speakingRate = 1.0,
    double pitch = 0.0,
    Function? onStart,
    Function? onComplete,
  }) async {
    try {
      _isSpeaking = true;
      if (onStart != null) onStart();

      // Call Google Cloud Text-to-Speech API
      final response = await http.post(
        Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {
            'languageCode': voiceName.substring(0, 5), // e.g., 'en-US'
            'name': voiceName,
          },
          'audioConfig': {
            'audioEncoding': 'MP3',
            'speakingRate': speakingRate,
            'pitch': pitch,
          },
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final audioContent = jsonResponse['audioContent'] as String;
        final audioBytes = base64Decode(audioContent);

        // Play the audio
        await _audioPlayer.play(BytesSource(audioBytes));

        // Wait for audio to complete
        _audioPlayer.onPlayerComplete.listen((_) {
          _isSpeaking = false;
          if (onComplete != null) onComplete();
        });
      } else {
        _isSpeaking = false;
        throw Exception('Failed to synthesize speech: ${response.body}');
      }
    } catch (e) {
      _isSpeaking = false;
      if (onComplete != null) onComplete();
      rethrow;
    }
  }

  /// Stop the current speech
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isSpeaking = false;
  }

  /// Pause the current speech
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  /// Resume paused speech
  Future<void> resume() async {
    await _audioPlayer.resume();
  }

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
  }

  /// Get available voice options
  static List<Map<String, String>> getAvailableVoices() {
    return [
      // English voices
      {'name': 'en-US-Neural2-A', 'gender': 'Male', 'type': 'Neural2', 'language': 'English'},
      {'name': 'en-US-Neural2-C', 'gender': 'Female', 'type': 'Neural2', 'language': 'English'},
      {'name': 'en-US-Neural2-D', 'gender': 'Male', 'type': 'Neural2', 'language': 'English'},
      {'name': 'en-US-Neural2-E', 'gender': 'Female', 'type': 'Neural2', 'language': 'English'},
      {'name': 'en-US-Neural2-F', 'gender': 'Female', 'type': 'Neural2', 'language': 'English'},
      {'name': 'en-US-Neural2-G', 'gender': 'Female', 'type': 'Neural2', 'language': 'English'},
      {'name': 'en-US-Neural2-H', 'gender': 'Female', 'type': 'Neural2', 'language': 'English'},
      {'name': 'en-US-Neural2-I', 'gender': 'Male', 'type': 'Neural2', 'language': 'English'},
      {'name': 'en-US-Neural2-J', 'gender': 'Male', 'type': 'Neural2', 'language': 'English'},
      // French voices
      {'name': 'fr-FR-Neural2-A', 'gender': 'Female', 'type': 'Neural2', 'language': 'French'},
      {'name': 'fr-FR-Neural2-B', 'gender': 'Male', 'type': 'Neural2', 'language': 'French'},
      {'name': 'fr-FR-Neural2-C', 'gender': 'Female', 'type': 'Neural2', 'language': 'French'},
      {'name': 'fr-FR-Neural2-D', 'gender': 'Male', 'type': 'Neural2', 'language': 'French'},
      {'name': 'fr-FR-Neural2-E', 'gender': 'Female', 'type': 'Neural2', 'language': 'French'},
    ];
  }
}
