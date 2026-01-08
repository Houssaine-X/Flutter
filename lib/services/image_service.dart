import 'dart:typed_data';
import 'package:firebase_vertexai/firebase_vertexai.dart';

class ImageService {
  GenerativeModel? _imageModel;

  GenerativeModel get imageModel {
    _imageModel ??= FirebaseVertexAI.instance.generativeModel(
      model: 'gemini-2.5-flash-image',
    );
    return _imageModel!;
  }

  /// Generate an image from a text description
  Future<Uint8List?> generateImage(String description) async {
    try {
      final response = await imageModel.generateContent([
        Content.text(description)
      ]);

      // Extract image bytes from the response
      if (response.candidates != null && response.candidates!.isNotEmpty) {
        final parts = response.candidates!.first.content.parts;
        for (var part in parts) {
          if (part is InlineDataPart && part.mimeType.startsWith('image/')) {
            return part.bytes;
          }
        }
      }

      throw Exception('No image data returned from model');
    } catch (e) {
      throw Exception('Failed to generate image: $e');
    }
  }

  /// Generate an image with a detailed prompt
  Future<Uint8List?> generateImageFromDetailedPrompt(String description) async {
    try {
      // Create a detailed prompt for better image quality
      final detailedPrompt = '''
$description

Style: Professional, artistic, detailed, high quality
Quality: Full HD, photorealistic
Lighting: Natural, cinematic, well-balanced
Composition: Visually appealing, centered
''';

      final response = await imageModel.generateContent([
        Content.text(detailedPrompt)
      ]);

      // Extract image bytes from the response
      if (response.candidates != null && response.candidates!.isNotEmpty) {
        final parts = response.candidates!.first.content.parts;
        for (var part in parts) {
          if (part is InlineDataPart && part.mimeType.startsWith('image/')) {
            return part.bytes;
          }
        }
      }

      throw Exception('No image data returned from model');
    } catch (e) {
      throw Exception('Failed to generate image: $e');
    }
  }
}
