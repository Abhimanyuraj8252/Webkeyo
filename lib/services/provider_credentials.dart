/// Extra per-provider credentials that do not fit the single API-key
/// field on [AIProviderModel] (Polly needs a Secret Access Key + region,
/// Azure needs a region, Speechify needs a model choice).
///
/// Stored in SharedPreferences under `webkeyo_cred_<provider>_<field>`.
/// Keys are never hardcoded and never leave the device. Pure storage —
/// no network, no server.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Extra credentials for one provider. All fields are optional —
/// only the ones a provider needs are shown in Settings.
class ProviderExtra {
  final String secret; // e.g. AWS Secret Access Key
  final String region; // e.g. ap-south-1 / centralindia
  final String model; // e.g. simba-3.5

  const ProviderExtra({
    this.secret = '',
    this.region = '',
    this.model = '',
  });

  bool get hasSecret => secret.isNotEmpty;
  bool get hasRegion => region.isNotEmpty;
  bool get hasModel => model.isNotEmpty;
}

class ProviderCredentials {
  static String _key(String providerId, String field) =>
      'webkeyo_cred_${providerId}_$field';

  static Future<ProviderExtra> load(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderExtra(
      secret: prefs.getString(_key(providerId, 'secret')) ?? '',
      region: prefs.getString(_key(providerId, 'region')) ?? '',
      model: prefs.getString(_key(providerId, 'model')) ?? '',
    );
  }

  static Future<void> save(String providerId, ProviderExtra extra) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(providerId, 'secret'), extra.secret);
    await prefs.setString(_key(providerId, 'region'), extra.region);
    await prefs.setString(_key(providerId, 'model'), extra.model);
  }

  static Future<void> saveField(
      String providerId, String field, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(providerId, field), value);
  }
}

/// Which extra fields a provider needs in Settings. The tile shows
/// only these — every other provider keeps the plain API-key field.
class ProviderExtraFields {
  final bool needsSecret;
  final bool needsRegion;
  final List<String> modelChoices; // empty = no model dropdown

  const ProviderExtraFields({
    this.needsSecret = false,
    this.needsRegion = false,
    this.modelChoices = const [],
  });
}

/// Extra fields per provider id. Regions have safe defaults applied by
/// the caller when the stored value is empty.
const Map<String, ProviderExtraFields> providerExtraFields = {
  'amazon_polly': ProviderExtraFields(
    needsSecret: true,
    needsRegion: true,
  ),
  'azure_speech': ProviderExtraFields(
    needsRegion: true,
  ),
  'speechify': ProviderExtraFields(
    modelChoices: ['simba-3.5', 'simba-3.2'],
  ),
};

/// Default region per provider when the user has not typed one.
String defaultRegionFor(String providerId) {
  switch (providerId) {
    case 'amazon_polly':
      return 'ap-south-1'; // Mumbai — closest to the user (India)
    case 'azure_speech':
      return 'centralindia'; // Pune — closest Azure Speech region
    default:
      return '';
  }
}

/// The TTS provider the user picked in onboarding (or in Settings).
/// Prompt-to-video prefers this provider when it is enabled; otherwise
/// it falls back to the first enabled TTS provider.
class DefaultTtsProvider {
  static const String _key = 'webkeyo_default_tts_provider';

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> save(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, providerId);
  }
}
