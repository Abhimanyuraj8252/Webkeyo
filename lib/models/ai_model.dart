import 'package:hive/hive.dart';

class AIModel {
  final String id;
  final String name;
  final String description;
  final String providerId;

  AIModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.providerId,
  });

  factory AIModel.fromJson(Map<String, dynamic> json, String providerId) {
    return AIModel(
      id: json['id'] ?? '',
      name: json['name'] ?? json['id'] ?? '',
      description: json['description'] ?? '',
      providerId: providerId,
    );
  }
}

class AIModelAdapter extends TypeAdapter<AIModel> {
  @override
  final int typeId = 1;

  @override
  AIModel read(BinaryReader reader) {
    return AIModel(
      id: reader.readString(),
      name: reader.readString(),
      description: reader.readString(),
      providerId: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, AIModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.description);
    writer.writeString(obj.providerId);
  }
}
