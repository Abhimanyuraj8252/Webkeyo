import 'package:hive/hive.dart';

enum ProviderCategory { text, vision, tts, video }

class ProviderCategoryAdapter extends TypeAdapter<ProviderCategory> {
  @override
  final int typeId = 2;

  @override
  ProviderCategory read(BinaryReader reader) {
    return ProviderCategory.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, ProviderCategory obj) {
    writer.writeByte(obj.index);
  }
}

class AIProviderModel {
  final String id;
  final String name;
  final ProviderCategory category;
  final bool requiresApiKey;
  String? apiKey;
  bool isEnabled;
  String? customBaseUrl;

  AIProviderModel({
    required this.id,
    required this.name,
    required this.category,
    this.requiresApiKey = true,
    this.apiKey,
    this.isEnabled = false,
    this.customBaseUrl,
  });

  AIProviderModel copyWith({
    String? id,
    String? name,
    ProviderCategory? category,
    bool? requiresApiKey,
    String? apiKey,
    bool? isEnabled,
    String? customBaseUrl,
  }) {
    return AIProviderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      requiresApiKey: requiresApiKey ?? this.requiresApiKey,
      apiKey: apiKey ?? this.apiKey,
      isEnabled: isEnabled ?? this.isEnabled,
      customBaseUrl: customBaseUrl ?? this.customBaseUrl,
    );
  }
}

class AIProviderModelAdapter extends TypeAdapter<AIProviderModel> {
  @override
  final int typeId = 0;

  @override
  AIProviderModel read(BinaryReader reader) {
    return AIProviderModel(
      id: reader.readString(),
      name: reader.readString(),
      category: reader.read(),
      requiresApiKey: reader.readBool(),
      apiKey: reader.readString(),
      isEnabled: reader.readBool(),
      customBaseUrl: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, AIProviderModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.write(obj.category);
    writer.writeBool(obj.requiresApiKey);
    writer.writeString(obj.apiKey ?? '');
    writer.writeBool(obj.isEnabled);
    writer.writeString(obj.customBaseUrl ?? '');
  }
}
