import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants.dart';
import '../models/ai_model.dart';
import '../models/ai_provider_model.dart';
import '../models/project_model.dart';

class ProviderRegistry extends ChangeNotifier {
  late Box<AIProviderModel> _providerBox;
  late Box<AIModel> _modelsBox;
  late Box<ProjectModel> _projectsBox;

  // Cached lists
  List<AIProviderModel> _providers = [];
  List<AIModel> _models = [];

  List<AIProviderModel> get providers => _providers;
  List<AIModel> get models => _models;
  Box<ProjectModel> get projectsBox => _projectsBox;

  Future<void> init() async {
    // Register Adapters
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(AIProviderModelAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(AIModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ProviderCategoryAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(ProjectModelAdapter());

    // Open Boxes
    _providerBox = await Hive.openBox<AIProviderModel>(AppConstants.providerBox);
    _modelsBox = await Hive.openBox<AIModel>(AppConstants.modelsBox);
    _projectsBox = await Hive.openBox<ProjectModel>('projects_box');

    _loadProviders();
    _loadModels();

    // If box is empty, initialize with default providers
    if (_providers.isEmpty) {
      await _initializeDefaultProviders();
    }
  }

  void _loadProviders() {
    _providers = _providerBox.values.toList();
    notifyListeners();
  }

  void _loadModels() {
    _models = _modelsBox.values.toList();
    notifyListeners();
  }

  Future<void> updateProvider(AIProviderModel updatedProvider) async {
    await _providerBox.put(updatedProvider.id, updatedProvider);
    _loadProviders();
  }

  Future<void> saveModelsForProvider(String providerId, List<AIModel> fetchedModels) async {
    // First, delete old models for this provider
    final keysToDelete = _modelsBox.keys.where((key) {
      final model = _modelsBox.get(key);
      return model != null && model.providerId == providerId;
    }).toList();
    
    await _modelsBox.deleteAll(keysToDelete);

    // Save new models
    for (var model in fetchedModels) {
      await _modelsBox.put(model.id, model);
    }
    
    _loadModels();
  }

  List<AIProviderModel> getProvidersByCategory(ProviderCategory category) {
    return _providers.where((p) => p.category == category).toList();
  }

  List<AIModel> getModelsByProvider(String providerId) {
    return _models.where((m) => m.providerId == providerId).toList();
  }

  Future<void> _initializeDefaultProviders() async {
    final defaultProviders = [
      // --- TEXT / SCRIPT PROVIDERS ---
      AIProviderModel(id: 'openrouter', name: 'OpenRouter', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://openrouter.ai/api/v1'),
      AIProviderModel(id: 'groq', name: 'Groq', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api.groq.com/openai/v1'),
      AIProviderModel(id: 'openai', name: 'OpenAI', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api.openai.com/v1'),
      AIProviderModel(id: 'anthropic', name: 'Anthropic', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api.anthropic.com/v1'),
      AIProviderModel(id: 'gemini', name: 'Google Gemini', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai'),
      AIProviderModel(id: 'together', name: 'Together AI', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api.together.xyz/v1'),
      AIProviderModel(id: 'deepseek', name: 'DeepSeek', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api.deepseek.com/v1'),
      AIProviderModel(id: 'fireworks', name: 'Fireworks AI', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api.fireworks.ai/inference/v1'),
      
      // --- VISION PROVIDERS (Supports free tiers & high limits) ---
      AIProviderModel(id: 'gemini_vision', name: 'Google Gemini Vision', category: ProviderCategory.vision, requiresApiKey: true, customBaseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai'),
      AIProviderModel(id: 'openrouter_vision', name: 'OpenRouter Vision', category: ProviderCategory.vision, requiresApiKey: true, customBaseUrl: 'https://openrouter.ai/api/v1'),
      AIProviderModel(id: 'anthropic_vision', name: 'Anthropic Vision', category: ProviderCategory.vision, requiresApiKey: true, customBaseUrl: 'https://api.anthropic.com/v1'),
      AIProviderModel(id: 'openai_vision', name: 'OpenAI Vision', category: ProviderCategory.vision, requiresApiKey: true, customBaseUrl: 'https://api.openai.com/v1'),
      AIProviderModel(id: 'together_vision', name: 'Together AI Vision', category: ProviderCategory.vision, requiresApiKey: true, customBaseUrl: 'https://api.together.xyz/v1'),
      AIProviderModel(id: 'novita_vision', name: 'Novita AI Vision', category: ProviderCategory.vision, requiresApiKey: true, customBaseUrl: 'https://api.novita.ai/v3/openai'),
      AIProviderModel(id: 'mistral', name: 'Mistral AI', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api.mistral.ai/v1'),
      AIProviderModel(id: 'cohere', name: 'Cohere', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api.cohere.ai/v1'),
      AIProviderModel(id: 'perplexity', name: 'Perplexity', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api.perplexity.ai'),
      AIProviderModel(id: 'anyscale', name: 'Anyscale', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api.endpoints.anyscale.com/v1'),
      AIProviderModel(id: 'huggingface', name: 'HuggingFace', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api-inference.huggingface.co/models'),
      AIProviderModel(id: 'novita', name: 'Novita AI', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api.novita.ai/v3/openai'),
      AIProviderModel(id: 'nomic', name: 'Nomic AI', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api.nomic.ai/v1'),
      AIProviderModel(id: 'replicate', name: 'Replicate', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api.replicate.com/v1'),
      AIProviderModel(id: 'aws_bedrock', name: 'AWS Bedrock', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: ''),
      AIProviderModel(id: 'azure_openai', name: 'Azure OpenAI', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: ''),
      AIProviderModel(id: 'moonshot', name: 'Moonshot (Kimi)', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api.moonshot.cn/v1'),
      AIProviderModel(id: 'zhipu', name: 'Zhipu AI', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://open.bigmodel.cn/api/paas/v4'),
      AIProviderModel(id: 'mistral_text', name: 'Mistral AI (Text)', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://api.mistral.ai/v1'),
      AIProviderModel(id: 'nvidia_nim', name: 'NVIDIA NIM (Text)', category: ProviderCategory.text, requiresApiKey: true, customBaseUrl: 'https://integrate.api.nvidia.com/v1'),

      // --- VISION / IMAGE PROVIDERS ---
      AIProviderModel(id: 'openai_vision', name: 'OpenAI Vision', category: ProviderCategory.vision, requiresApiKey: true, customBaseUrl: 'https://api.openai.com/v1'),
      AIProviderModel(id: 'google_vision', name: 'Google Gemini Vision', category: ProviderCategory.vision, requiresApiKey: true, customBaseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai'),
      AIProviderModel(id: 'anthropic_vision', name: 'Anthropic Vision', category: ProviderCategory.vision, requiresApiKey: true, customBaseUrl: 'https://api.anthropic.com/v1'),
      AIProviderModel(id: 'openrouter_vision', name: 'OpenRouter Vision', category: ProviderCategory.vision, requiresApiKey: true, customBaseUrl: 'https://openrouter.ai/api/v1'),
      AIProviderModel(id: 'groq_vision', name: 'Groq Vision', category: ProviderCategory.vision, requiresApiKey: true, customBaseUrl: 'https://api.groq.com/openai/v1'),
      AIProviderModel(id: 'mistral_vision', name: 'Mistral AI Vision', category: ProviderCategory.vision, requiresApiKey: true, customBaseUrl: 'https://api.mistral.ai/v1'),
      AIProviderModel(id: 'nvidia_nim_vision', name: 'NVIDIA NIM Vision', category: ProviderCategory.vision, requiresApiKey: true, customBaseUrl: 'https://integrate.api.nvidia.com/v1'),

      // --- TTS / AUDIO PROVIDERS ---
      AIProviderModel(id: 'edge_tts', name: 'Microsoft Edge TTS', category: ProviderCategory.tts, requiresApiKey: false),
      AIProviderModel(id: 'piper_tts', name: 'Piper TTS (Offline)', category: ProviderCategory.tts, requiresApiKey: false),
      AIProviderModel(id: 'elevenlabs', name: 'ElevenLabs', category: ProviderCategory.tts, requiresApiKey: true, customBaseUrl: 'https://api.elevenlabs.io/v1'),
      AIProviderModel(id: 'deepgram', name: 'Deepgram Aura', category: ProviderCategory.tts, requiresApiKey: true, customBaseUrl: 'https://api.deepgram.com/v1'),
      AIProviderModel(id: 'openai_tts', name: 'OpenAI TTS', category: ProviderCategory.tts, requiresApiKey: true, customBaseUrl: 'https://api.openai.com/v1'),
      AIProviderModel(id: 'google_cloud_tts', name: 'Google Cloud TTS', category: ProviderCategory.tts, requiresApiKey: true, customBaseUrl: 'https://texttospeech.googleapis.com/v1'),
      AIProviderModel(id: 'mistral_tts', name: 'Mistral AI TTS', category: ProviderCategory.tts, requiresApiKey: true, customBaseUrl: 'https://api.mistral.ai/v1'),
      AIProviderModel(id: 'nvidia_nim_tts', name: 'NVIDIA NIM TTS', category: ProviderCategory.tts, requiresApiKey: true, customBaseUrl: 'https://integrate.api.nvidia.com/v1'),
    ];

    for (var provider in defaultProviders) {
      await _providerBox.put(provider.id, provider);
    }
    
    _loadProviders();
  }

  /// Notify listeners externally when project data changes.
  void refreshProjects() {
    notifyListeners();
  }
}
