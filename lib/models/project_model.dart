import 'package:hive/hive.dart';

class ProjectModel extends HiveObject {
  String id;
  @HiveField(1)
  String title;
  @HiveField(2)
  String? sourceFilePath;
  @HiveField(3)
  List<String> extractedImagePaths;
  @HiveField(4)
  String? generatedScript;
  @HiveField(5)
  String? generatedAudioPath;
  @HiveField(6)
  String? finalVideoPath;
  @HiveField(7)
  DateTime createdAt;
  @HiveField(8)
  String language;
  @HiveField(9)
  bool isNsfw;
  @HiveField(10)
  String? charactersContext;
  @HiveField(11)
  String generationMode;
  @HiveField(12)
  String? visionProviderId;
  @HiveField(13)
  String? visionModelId;
  @HiveField(14)
  String? visionBaseUrl;
  @HiveField(15)
  String? visionApiKey;
  @HiveField(16)
  String? textProviderId;
  @HiveField(17)
  String? textModelId;
  @HiveField(18)
  String? ttsProviderId;
  @HiveField(19)
  String status; // 'created', 'extracting', 'scripting', 'audio', 'rendering', 'done', 'error'
  
  // NEW FIELDS
  @HiveField(20)
  String videoResolution;
  @HiveField(21)
  String? customExportPath;
  @HiveField(22)
  List<String> editedImagePaths;
  @HiveField(23)
  String? ttsModelId;
  @HiveField(24)
  String? ttsApiKey;
  @HiveField(25)
  String? ttsBaseUrl;

  ProjectModel({
    required this.id,
    required this.title,
    this.sourceFilePath,
    List<String>? extractedImagePaths,
    this.generatedScript,
    this.generatedAudioPath,
    this.finalVideoPath,
    DateTime? createdAt,
    this.language = 'Hinglish',
    this.isNsfw = false,
    this.charactersContext,
    this.generationMode = 'Manga/Manhwa Recap',
    this.visionProviderId,
    this.visionModelId,
    this.visionBaseUrl,
    this.visionApiKey,
    this.textProviderId,
    this.textModelId,
    this.ttsProviderId,
    this.status = 'created',
    this.videoResolution = '1080p',
    this.customExportPath,
    List<String>? editedImagePaths,
    this.ttsModelId,
    this.ttsApiKey,
    this.ttsBaseUrl,
  })  : extractedImagePaths = extractedImagePaths ?? [],
        editedImagePaths = editedImagePaths ?? [],
        createdAt = createdAt ?? DateTime.now();

  String get statusDisplay {
    switch (status) {
      case 'created':
        return 'Ready';
      case 'extracting':
        return 'Extracting...';
      case 'editing_images':
        return 'Images Editing...';
      case 'scripting':
        return 'Writing Script...';
      case 'script_ready':
        return 'Script Ready';
      case 'audio':
        return 'Generating Audio...';
      case 'rendering':
        return 'Rendering Video...';
      case 'done':
        return 'Completed ✅';
      case 'error':
        return 'Error ❌';
      default:
        return status;
    }
  }

  double get progressValue {
    switch (status) {
      case 'created':
        return 0.0;
      case 'extracting':
        return 0.10;
      case 'editing_images':
        return 0.20;
      case 'scripting':
        return 0.35;
      case 'script_ready':
        return 0.5;
      case 'audio':
        return 0.7;
      case 'rendering':
        return 0.85;
      case 'done':
        return 1.0;
      default:
        return 0.0;
    }
  }

  ProjectModel copyWith({
    String? title,
    String? sourceFilePath,
    List<String>? extractedImagePaths,
    String? generatedScript,
    String? generatedAudioPath,
    String? finalVideoPath,
    String? language,
    bool? isNsfw,
    String? charactersContext,
    String? generationMode,
    String? visionProviderId,
    String? visionModelId,
    String? visionBaseUrl,
    String? visionApiKey,
    String? textProviderId,
    String? textModelId,
    String? ttsProviderId,
    String? status,
    String? videoResolution,
    String? customExportPath,
    List<String>? editedImagePaths,
    String? ttsModelId,
    String? ttsApiKey,
    String? ttsBaseUrl,
  }) {
    return ProjectModel(
      id: id,
      title: title ?? this.title,
      sourceFilePath: sourceFilePath ?? this.sourceFilePath,
      extractedImagePaths: extractedImagePaths ?? this.extractedImagePaths,
      generatedScript: generatedScript ?? this.generatedScript,
      generatedAudioPath: generatedAudioPath ?? this.generatedAudioPath,
      finalVideoPath: finalVideoPath ?? this.finalVideoPath,
      createdAt: createdAt,
      language: language ?? this.language,
      isNsfw: isNsfw ?? this.isNsfw,
      charactersContext: charactersContext ?? this.charactersContext,
      generationMode: generationMode ?? this.generationMode,
      visionProviderId: visionProviderId ?? this.visionProviderId,
      visionModelId: visionModelId ?? this.visionModelId,
      visionBaseUrl: visionBaseUrl ?? this.visionBaseUrl,
      visionApiKey: visionApiKey ?? this.visionApiKey,
      textProviderId: textProviderId ?? this.textProviderId,
      textModelId: textModelId ?? this.textModelId,
      ttsProviderId: ttsProviderId ?? this.ttsProviderId,
      status: status ?? this.status,
      videoResolution: videoResolution ?? this.videoResolution,
      customExportPath: customExportPath ?? this.customExportPath,
      editedImagePaths: editedImagePaths ?? this.editedImagePaths,
      ttsModelId: ttsModelId ?? this.ttsModelId,
      ttsApiKey: ttsApiKey ?? this.ttsApiKey,
      ttsBaseUrl: ttsBaseUrl ?? this.ttsBaseUrl,
    );
  }
}

class ProjectModelAdapter extends TypeAdapter<ProjectModel> {
  @override
  final int typeId = 4;

  @override
  ProjectModel read(BinaryReader reader) {
    final id = reader.readString();
    final title = reader.readString();
    final sourceFilePath = reader.read() as String?;
    final extractedImagePaths = (reader.readList()).cast<String>();
    final generatedScript = reader.read() as String?;
    final generatedAudioPath = reader.read() as String?;
    final finalVideoPath = reader.read() as String?;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());

    String language = 'Hinglish';
    bool isNsfw = false;
    String? charactersContext;
    String generationMode = 'Manga/Manhwa Recap';
    String? visionProviderId;
    String? visionModelId;
    String? visionBaseUrl;
    String? visionApiKey;
    String? textProviderId;
    String? textModelId;
    String? ttsProviderId;
    String status = 'created';
    
    // Default values for new fields to avoid breaking old database items
    String videoResolution = '1080p';
    String? customExportPath;
    List<String> editedImagePaths = [];
    String? ttsModelId;
    String? ttsApiKey;
    String? ttsBaseUrl;

    try {
      if (reader.availableBytes > 0) {
        language = reader.readString();
        isNsfw = reader.readBool();
      }
      if (reader.availableBytes > 0) {
        charactersContext = reader.read() as String?;
      }
      if (reader.availableBytes > 0) {
        generationMode = reader.readString();
      }
      if (reader.availableBytes > 0) {
        visionProviderId = reader.read() as String?;
        visionModelId = reader.read() as String?;
        visionBaseUrl = reader.read() as String?;
        visionApiKey = reader.read() as String?;
        textProviderId = reader.read() as String?;
        textModelId = reader.read() as String?;
        ttsProviderId = reader.read() as String?;
        status = reader.readString();
      }
      if (reader.availableBytes > 0) {
        videoResolution = reader.readString();
        customExportPath = reader.read() as String?;
        editedImagePaths = (reader.readList()).cast<String>();
      }
      if (reader.availableBytes > 0) {
        ttsModelId = reader.read() as String?;
      }
      if (reader.availableBytes > 0) {
        ttsApiKey = reader.read() as String?;
      }
      if (reader.availableBytes > 0) {
        ttsBaseUrl = reader.read() as String?;
      }
    } catch (e) {
      // Backward compatibility: older versions don't have these fields
    }

    return ProjectModel(
      id: id,
      title: title,
      sourceFilePath: sourceFilePath,
      extractedImagePaths: extractedImagePaths,
      generatedScript: generatedScript,
      generatedAudioPath: generatedAudioPath,
      finalVideoPath: finalVideoPath,
      createdAt: createdAt,
      language: language,
      isNsfw: isNsfw,
      charactersContext: charactersContext,
      generationMode: generationMode,
      visionProviderId: visionProviderId,
      visionModelId: visionModelId,
      visionBaseUrl: visionBaseUrl,
      visionApiKey: visionApiKey,
      textProviderId: textProviderId,
      textModelId: textModelId,
      ttsProviderId: ttsProviderId,
      status: status,
      videoResolution: videoResolution,
      customExportPath: customExportPath,
      editedImagePaths: editedImagePaths,
      ttsModelId: ttsModelId,
      ttsApiKey: ttsApiKey,
      ttsBaseUrl: ttsBaseUrl,
    );
  }

  @override
  void write(BinaryWriter writer, ProjectModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.write(obj.sourceFilePath);
    writer.writeList(obj.extractedImagePaths);
    writer.write(obj.generatedScript);
    writer.write(obj.generatedAudioPath);
    writer.write(obj.finalVideoPath);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeString(obj.language);
    writer.writeBool(obj.isNsfw);
    writer.write(obj.charactersContext);
    writer.writeString(obj.generationMode);
    writer.write(obj.visionProviderId);
    writer.write(obj.visionModelId);
    writer.write(obj.visionBaseUrl);
    writer.write(obj.visionApiKey);
    writer.write(obj.textProviderId);
    writer.write(obj.textModelId);
    writer.write(obj.ttsProviderId);
    writer.writeString(obj.status);
    writer.writeString(obj.videoResolution);
    writer.write(obj.customExportPath);
    writer.writeList(obj.editedImagePaths);
    writer.write(obj.ttsModelId);
    writer.write(obj.ttsApiKey);
    writer.write(obj.ttsBaseUrl);
  }
}
