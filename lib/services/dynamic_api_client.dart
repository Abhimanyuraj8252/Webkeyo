import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_model.dart';
import '../models/ai_provider_model.dart';

class DynamicApiClient {
  /// Fetches models from a generic provider that follows the OpenAI `/models` endpoint structure.
  /// E.g., OpenRouter, Groq, Together, OpenAI, Fireworks.
  static Future<List<AIModel>> fetchModels(AIProviderModel provider) async {
    final apiKey = provider.apiKey;
    final baseUrl = provider.customBaseUrl;

    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('Base URL is not configured for provider: ${provider.name}');
    }

    if (provider.requiresApiKey && (apiKey == null || apiKey.isEmpty)) {
      throw Exception('API Key is missing for provider: ${provider.name}');
    }

    final uri = Uri.parse('$baseUrl/models');

    try {
      final response = await http.get(
        uri,
        headers: {
          if (provider.requiresApiKey) 'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          // Optional headers required by specific providers like OpenRouter
          if (provider.id == 'openrouter') 'HTTP-Referer': 'https://webkeyo.app',
          if (provider.id == 'openrouter') 'X-Title': 'Webkeyo',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('data') && data['data'] is List) {
          final List<dynamic> modelsJson = data['data'];
          return modelsJson
              .map((json) => AIModel.fromJson(json as Map<String, dynamic>, provider.id))
              .toList();
        } else {
          throw Exception('Unexpected JSON structure: Missing "data" array.');
        }
      } else {
        throw Exception('Failed to fetch models. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching models for ${provider.name}: $e');
    }
  }
}
