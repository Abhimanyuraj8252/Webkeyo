import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A fully dynamic API service that uses whatever provider base URL and model
/// the user has selected — no more hardcoded OpenRouter.
class ApiService {
  /// Generates a structured JSON script from local images using Vision AI.
  /// Now accepts baseUrl and modelId dynamically from the caller.
  Future<String> generateScript({
    required List<String> imagePaths,
    required bool isUncensored,
    required String language,
    required String apiKey,
    required String baseUrl,
    required String modelId,
    required String customPrompt,
    String? charactersContext,
    String generationMode = 'Manga/Manhwa Recap',
  }) async {
    try {
      // Image Sampling to avoid payload limits
      final List<String> sampledPaths = _sampleImages(imagePaths, maxImages: 10);

      // Heavy Base64 encoding in background isolate
      final List<String> base64Images = await compute(_encodeImagesToBase64, sampledPaths);

      // Constructing Vision Content Array
      final List<Map<String, dynamic>> contentArray = [];

      if (customPrompt.isNotEmpty) {
        contentArray.add({
          "type": "text",
          "text": customPrompt,
        });
      } else {
        contentArray.add({
          "type": "text",
          "text": "Analyze the following manga/manhwa pages and generate a recap script.",
        });
      }

      for (int i = 0; i < base64Images.length; i++) {
        contentArray.add({
          "type": "text",
          "text": "Image Index $i:",
        });
        contentArray.add({
          "type": "image_url",
          "image_url": {
            "url": "data:image/jpeg;base64,${base64Images[i]}",
          },
        });
      }

      // Build system prompt based on mode
      String contextInjection = "";
      if (charactersContext != null && charactersContext.trim().isNotEmpty) {
        contextInjection =
            "\nPROJECT CONTEXT (CHARACTER NAMES & ROLES):\n$charactersContext\nEnsure you use these exact character names and understand their roles when writing the description and narration.";
      }

      String modeInstruction = "";
      if (generationMode == 'Study Explainer') {
        modeInstruction =
            "You are an expert tutor and study assistant.\nYour task is to analyze the provided educational material (notes, books, diagrams).\nExplain every topic clearly, provide real-world examples, and prepare an educational audio script that teaches the student effectively.\nAnticipate and answer potential questions.";
      } else if (generationMode == 'Story/Novel Narration') {
        modeInstruction =
            "You are a master storyteller.\nYour task is to analyze the provided material and write a deep, engaging story narration. Focus on emotions, plot, and character development rather than purely visual descriptions. Create an immersive audiobook experience.";
      } else if (generationMode == 'Poem Reciter') {
        modeInstruction =
            "You are a poetic analyst and reciter.\nYour task is to analyze the provided material, extract any poetic elements, and format the output as a rhythmic, emotional poem recitation. Focus on meter and dramatic pauses.";
      } else {
        modeInstruction =
            "You are an expert manga/manhwa recapper and scriptwriter.\nYour task is to analyze the provided comic pages and output a structured script for a summary video.";
      }

      // Language instruction
      String languageInstruction;
      if (language.toLowerCase().contains('hin') || language.toLowerCase() == 'hinglish') {
        languageInstruction =
            "The `narration` MUST be written entirely in pure Hindi (Devanagari script). It should sound highly engaging, dramatic, and natural.";
      } else if (language.toLowerCase() == 'english') {
        languageInstruction =
            "The `narration` MUST be written entirely in English. It should sound highly engaging, dramatic, and natural.";
      } else {
        languageInstruction =
            "The `narration` MUST be written in $language. It should sound highly engaging, dramatic, and natural.";
      }

      final String systemPrompt = """$modeInstruction$contextInjection
CRITICAL INSTRUCTION: $languageInstruction
The narration should be tailored to the chosen mode ($generationMode).
${isUncensored ? "NSFW Content is permitted. Do not censor descriptions or dialogue." : "Please ensure the content is SFW and appropriate for general audiences."}
Optionally, include emotion tags like [happy], [sad], [angry], [excited] at the start of sentences in the narration if applicable.
IMPORTANT: You MUST output STRICTLY valid JSON. No markdown blocks, no conversational filler.
The output MUST follow this exact schema, where 'image_index' refers to the index provided before the image:
{
  "scenes": [
    {
      "scene_number": 1,
      "image_index": 0,
      "description": "Detailed visual or contextual description of what is happening...",
      "narration": "[excited] Script narration here..."
    }
  ]
}""";

      final Map<String, dynamic> requestBody = {
        "model": modelId,
        "messages": [
          {"role": "system", "content": systemPrompt},
          {"role": "user", "content": contentArray},
        ],
        "response_format": {"type": "json_object"},
      };

      // Determine chat completions endpoint
      final String chatEndpoint = baseUrl.endsWith('/')
          ? '${baseUrl}chat/completions'
          : '$baseUrl/chat/completions';

      final response = await http
          .post(
            Uri.parse(chatEndpoint),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://webkeyo.app',
              'X-Title': 'Webkeyo',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(minutes: 3));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String rawContent = data['choices']?[0]?['message']?['content'] ?? '{}';
        return rawContent;
      } else {
        throw HttpException('API Error: ${response.statusCode} - ${response.body}');
      }
    } on Exception catch (e) {
      debugPrint('Error generating script: $e');
      rethrow;
    }
  }

  /// Automatically detect characters from the first few images.
  Future<String> autoDetectCharacters({
    required List<String> imagePaths,
    required String apiKey,
    required String baseUrl,
    required String modelId,
  }) async {
    try {
      final List<String> sampledPaths = _sampleImages(imagePaths, maxImages: 5);
      final List<String> base64Images = await compute(_encodeImagesToBase64, sampledPaths);

      final List<Map<String, dynamic>> contentArray = [];
      contentArray.add({
        "type": "text",
        "text":
            "Identify all unique characters in these pages. Describe their visual appearance and guess their role if possible.",
      });

      for (String base64Img in base64Images) {
        contentArray.add({
          "type": "image_url",
          "image_url": {"url": "data:image/jpeg;base64,$base64Img"},
        });
      }

      const String systemPrompt =
          """You are an expert visual analyzer. 
Analyze the provided images and return a list of characters detected, with a brief visual description. 
Output plain text formatted as:
Name/Descriptor: [Visual appearance and guessed role]
""";

      final Map<String, dynamic> requestBody = {
        "model": modelId,
        "messages": [
          {"role": "system", "content": systemPrompt},
          {"role": "user", "content": contentArray},
        ],
      };

      final String chatEndpoint = baseUrl.endsWith('/')
          ? '${baseUrl}chat/completions'
          : '$baseUrl/chat/completions';

      final response = await http
          .post(
            Uri.parse(chatEndpoint),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://webkeyo.app',
              'X-Title': 'Webkeyo',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(minutes: 2));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['choices']?[0]?['message']?['content'] ?? 'No characters detected.';
      } else {
        throw HttpException('API Error: ${response.statusCode} - ${response.body}');
      }
    } on Exception catch (e) {
      debugPrint('Error detecting characters: $e');
      rethrow;
    }
  }

  /// Reduces massive arrays of image paths to a manageable sample.
  List<String> _sampleImages(List<String> paths, {int maxImages = 15}) {
    if (paths.length <= maxImages) return paths;
    final List<String> sampled = [];
    final double step = paths.length / maxImages;
    for (int i = 0; i < maxImages; i++) {
      final int index = (i * step).round().clamp(0, paths.length - 1);
      sampled.add(paths[index]);
    }
    return sampled;
  }
}

/// Top-level isolate function for Base64 encoding images off the main thread.
List<String> _encodeImagesToBase64(List<String> paths) {
  final List<String> base64List = [];
  for (String path in paths) {
    try {
      final File file = File(path);
      if (file.existsSync()) {
        final List<int> bytes = file.readAsBytesSync();
        base64List.add(base64Encode(bytes));
      }
    } catch (e) {
      debugPrint('Failed to encode image at $path: $e');
    }
  }
  return base64List;
}
