# Webkeyo Full Codebase Audit V2 — April 28, 2026

## Overall Completion: **~35%**

The app has a solid structural skeleton (models, services, screens), but the **majority of features are either broken, half-implemented, or entirely missing**. The pipeline has a **crash-on-launch bug**, the home screen has no project listing/dashboard, settings are non-functional toggles, and critical features like project management, saved scripts, and video playback are absent.

---

## 🔴 CRITICAL BUGS (App-Breaking)

### 1. `PipelineProgressScreen` Calls Non-Existent Method → **CRASH**
[pipeline_progress_screen.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/features/pipeline/screens/pipeline_progress_screen.dart#L50)

```dart
// Line 50: calls _runPipelineMock() which does NOT exist in the class
_runPipelineMock(); // ← Method not defined. App crashes with NoSuchMethodError.
// Should be: _runPipeline();
```

> [!CAUTION]
> This means **the entire pipeline is broken** — it immediately crashes when a user starts processing. The real method `_runPipeline()` exists on line 53 but is never called.

### 2. `pubspec.yaml` Missing `flutter:` Assets Section
[pubspec.yaml](file:///home/abhimanyu/Trikrypta/Webkeyo/pubspec.yaml)

The `pubspec.yaml` has **no `flutter: assets:` declaration**. The `assets/logo.png` and `assets/logo.svg` are not bundled. Any widget trying to load them via `AssetImage` will crash.

```yaml
# MISSING at the bottom of pubspec.yaml:
flutter:
  uses-material-design: true
  assets:
    - assets/
```

### 3. `ApiService` Hardcoded to OpenRouter Only
[api_service.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/services/api_service.dart#L9)

The `ApiService` has `_baseUrl = 'https://openrouter.ai/api/v1'` hardcoded. **It completely ignores** whatever provider/model the user selects in Settings or the HomeScreen selector chips. The `generateScript()` method even hardcodes the model name (`nousresearch/nous-hermes-2-vision-7b` or `meta-llama/llama-3.2-11b-vision-instruct`).

**Impact:** User's provider/model selections in the UI are cosmetic — they do nothing.

### 4. `AudioProvider` Uses Old HTTP TTS Logic
[audio_provider.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/features/processing/audio_provider.dart#L52)

`AudioProvider.processScriptToAudio()` still references `SharedPreferences` for `ttsApiUrl_key` and passes it to `TtsService`. But the new `TtsService` uses `flutter_tts` locally and ignores `ttsApiUrl`. The `AudioProvider` is also **never actually used anywhere** in the pipeline — the `PipelineProgressScreen` creates its own `TtsService()` directly.

---

## 🟠 HIGH SEVERITY BUGS

### 5. Home Screen Has No Project Dashboard
[home_screen.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/features/home/home_screen.dart)

The "Recent Tasks" section uses a local `_tasks` list that's never populated from Hive. **Projects saved to `projectsBox` are invisible on the home screen.** When you restart the app, everything is gone. This violates the user's requirement of a project-based dashboard.

### 6. Model Selection Has No Effect on Pipeline
The HomeScreen stores `_selectedTextModel`, `_selectedVisionModel`, `_selectedTtsModel` as local strings — but these are **never passed** to the `ProjectModel` or `ApiService`. The pipeline always uses OpenRouter with hardcoded models.

### 7. Settings Dark Mode / NSFW Toggles Are Non-Functional
[settings_screen.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/features/settings/settings_screen.dart#L44-L55)

Both `SwitchListTile` widgets in Settings have `// TODO` comments. They don't change any state.

### 8. `VideoProvider` and `AudioProvider` Are Dead Code
Both `VideoProvider` and `AudioProvider` are **never registered** in `main.dart`'s `MultiProvider` and **never referenced** by any screen. They're completely orphaned.

### 9. `firstWhere` Without Proper `orElse` Safety
[pipeline_progress_screen.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/features/pipeline/screens/pipeline_progress_screen.dart#L156)

```dart
var matchingScene = scenes.firstWhere((s) => s['scene_number'] == sceneNum, orElse: () => null);
```
`firstWhere` on a `List<dynamic>` with `orElse: () => null` can throw a type error in strict null-safety contexts because `null` isn't `dynamic`.

### 10. No Permission Request Flow
[AndroidManifest.xml](file:///home/abhimanyu/Trikrypta/Webkeyo/android/app/src/main/AndroidManifest.xml)

Permissions are declared in the manifest, but the app **never calls** `permission_handler` to actually request them at runtime. On Android 13+, `MANAGE_EXTERNAL_STORAGE` and `READ_MEDIA_*` **must** be requested at runtime or the app silently fails to write videos.

### 11. `withOpacity()` Deprecated Usage (~22 occurrences)
`Color.withOpacity()` is deprecated in the latest Flutter. Should use `Color.withValues(alpha: ...)`. This generates **22 deprecation warnings** across 7 files.

### 12. No Error Recovery / No Retry in Pipeline
If any phase fails (network timeout, TTS failure, FFmpeg crash), the pipeline just shows `Error: ...` with no way to retry, go back, or resume. The user is stuck.

### 13. `extractedImagePaths` Unmodifiable Default
[project_model.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/models/project_model.dart#L32)

```dart
this.extractedImagePaths = const [], // ← const = immutable!
```
When pipeline tries `project.extractedImagePaths = images;`, it works because it's replacing the reference. But if any code tries `.add()`, `.sort()` on the default, it crashes.

---

## 🟡 MISSING FEATURES

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 1 | **Project Dashboard on Home Screen** | ❌ Missing | Home shows empty `_tasks` list; projects from Hive never displayed |
| 2 | **Project List/Manager Screen** | ❌ Missing | No way to see all past projects, their status, or resume them |
| 3 | **Saved Scripts Browser** | ❌ Missing | User requested ability to browse/delete/reuse saved scripts |
| 4 | **Dynamic Provider Selection in Pipeline** | ❌ Missing | ApiService ignores user's selected provider & model |
| 5 | **Language Selector Effect** | ⚠️ Partial | Language dropdown exists in UI but only partially applied in TTS |
| 6 | **NSFW Mode Global Toggle** | ❌ Missing | Settings toggle is non-functional |
| 7 | **Dark/Light Theme Toggle** | ❌ Missing | Settings toggle is non-functional (hardcoded `ThemeMode.dark`) |
| 8 | **Video Player / Preview Screen** | ❌ Missing | After video renders, there's no way to preview it in-app |
| 9 | **Share/Export Button** | ❌ Missing | `share_plus` is in pubspec but never used |
| 10 | **Multiple Chapter Support** | ❌ Missing | Can only process one file at a time |
| 11 | **Edge TTS Integration** | ❌ Missing | Listed as provider but no actual implementation |
| 12 | **Piper TTS Integration** | ❌ Missing | Listed as provider but no actual implementation |
| 13 | **ElevenLabs TTS Integration** | ❌ Missing | Listed as provider but no actual implementation |
| 14 | **Runtime Permission Request** | ❌ Missing | `permission_handler` in pubspec but never called |
| 15 | **Project Delete / Cleanup** | ❌ Missing | No way to delete old projects or clean temp files |
| 16 | **Notification Support** | ❌ Missing | `flutter_local_notifications` in pubspec but never used |
| 17 | **Connectivity Check** | ❌ Missing | `connectivity_plus` in pubspec but never used |
| 18 | **Video Resolution Setting** | ❌ Missing | Hardcoded to 1920x1080 with no user control |
| 19 | **Study/Exam Mode AI Prompt Tuning** | ⚠️ Partial | Mode strings exist in prompts but never tested/refined |
| 20 | **Script-to-Audio Direct Screen** | ❌ Missing | User wanted a dedicated screen to directly convert any script to audio |
| 21 | **Folder Picker for Direct Images** | ⚠️ Partial | `FileService.pickFolder()` exists but never called from UI |
| 22 | **Batch Processing Queue** | ❌ Missing | Only first picked file is processed |

---

## 📊 FILE-BY-FILE STATUS

### Models (4 files)
| File | Status | Issues |
|------|--------|--------|
| `ai_model.dart` | ✅ Working | Clean |
| `ai_provider_model.dart` | ✅ Working | Clean |
| `project_model.dart` | ⚠️ Issues | `const` default for mutable list; HiveField annotations won't work without build_runner |
| `task_model.dart` | ⚠️ Unused | Not Hive-persisted, only used transiently on home screen |

### Services (8 files)
| File | Status | Issues |
|------|--------|--------|
| `api_service.dart` | 🔴 Broken | Hardcoded to OpenRouter; ignores user's provider/model selection |
| `conversion_service.dart` | ✅ Working | CBZ→Image, PDF→Image, CBZ→PDF all implemented |
| `dynamic_api_client.dart` | ✅ Working | Dynamically fetches models per provider |
| `face_detection_service.dart` | ✅ Working | ML Kit face detection with proper bounds |
| `ffmpeg_service.dart` | ✅ Working | Ken Burns, portrait/landscape detection, proper cleanup |
| `file_service.dart` | ✅ Working | File picker, archive extraction, PDF extraction |
| `provider_registry.dart` | ✅ Working | 25+ providers, Hive persistence, dynamic model management |
| `tts_service.dart` | ✅ Working | `flutter_tts` local synthesis with duration calculation |

### Screens (8 screens)
| File | Status | Issues |
|------|--------|--------|
| `home_screen.dart` | 🟠 Partial | No dashboard; model selections are cosmetic; no project listing |
| `model_selector_sheet.dart` | ✅ Working | Clean bottom sheet with provider filtering |
| `upload_card.dart` | ✅ Working | Clean widget |
| `settings_screen.dart` | 🟠 Broken | Dark mode & NSFW toggles are TODO stubs |
| `providers_screen.dart` | ✅ Working | Category tabs, provider list |
| `provider_tile.dart` | ✅ Working | API key entry, model fetch, enable/disable |
| `tools_screen.dart` | ✅ Working | CBZ→PDF, PDF→Image, CBZ→Image all functional |
| `pipeline_progress_screen.dart` | 🔴 CRASH | Calls `_runPipelineMock()` which doesn't exist |
| `script_editor_screen.dart` | ✅ Working | Edit script → proceed to audio gen |
| `project_context_screen.dart` | ✅ Working | Character detection, face extraction, context input |
| `character_assignment_screen.dart` | ✅ Working | Face crop display, name/role assignment |

### Providers (Dead Code)
| File | Status | Issues |
|------|--------|--------|
| `audio_provider.dart` | 🔴 Dead | Never registered in MultiProvider, never used |
| `video_provider.dart` | 🔴 Dead | Never registered in MultiProvider, never used |

---

## 🛡️ ANR-PROOFING ASSESSMENT

| Area | ANR-Safe? | Notes |
|------|-----------|-------|
| Image Base64 encoding | ✅ Yes | Uses `compute()` isolate |
| CBZ extraction | ✅ Yes | Uses `compute()` isolate via `FileService` |
| PDF rendering | ⚠️ Risky | `pdfx` renders on main thread in `ConversionService` |
| FFmpeg rendering | ✅ Yes | FFmpegKit runs natively off-thread |
| TTS generation | ⚠️ Risky | `flutter_tts.synthesizeToFile()` may block on some devices |
| Face detection | ✅ Yes | ML Kit processes asynchronously |
| Hive read/write | ✅ Yes | Async operations |
| Network calls | ✅ Yes | Standard async HTTP |

---

## 🎨 UI QUALITY ASSESSMENT

| Area | Rating | Notes |
|------|--------|-------|
| Theme system | ⭐⭐⭐⭐ | Good dark/light theme with Google Fonts, accent colors |
| Home screen | ⭐⭐ | Functional but missing dashboard, feels empty |
| Settings | ⭐⭐ | Minimal — just one link and broken toggles |
| Tools screen | ⭐⭐⭐⭐ | Well-designed cards with animations |
| Pipeline screen | ⭐⭐⭐ | Good phase visualization but crashes on launch |
| Script editor | ⭐⭐⭐ | Clean, functional |
| Character screen | ⭐⭐⭐ | Face crop cards with role dropdowns |
| Animations | ⭐⭐⭐⭐ | `flutter_animate` used consistently |
| Overall Premium Feel | ⭐⭐ | Missing dashboard, polish, project mgmt screens |

---

## 📋 PRIORITIZED FIX PLAN

### Phase 1: Critical Fixes (Must do first)
1. **Fix `_runPipelineMock()` → `_runPipeline()`** (1 line change, crash fix)
2. **Add `flutter: assets:` section to pubspec.yaml**
3. **Add runtime permission requests** (storage, manage_external)
4. **Wire `ApiService` to respect user's selected provider/model** (not hardcode OpenRouter)

### Phase 2: Core Feature Completion
5. **Build a real Project Dashboard** on home screen from Hive `projectsBox`
6. **Pass selected models through `ProjectModel` to `PipelineProgressScreen`**
7. **Implement Dark/Light theme toggle** with persistent state
8. **Add Video Player screen** after render completes
9. **Add Share button** using `share_plus`
10. **Implement runtime permission request** flow on first launch

### Phase 3: Feature Expansion
11. **Saved Scripts browser** screen
12. **Script-to-Audio direct converter** screen
13. **Edge TTS / Piper TTS** real implementations
14. **Folder picker** option on home screen
15. **Batch/queue processing** for multiple files
16. **Project delete/cleanup** feature

### Phase 4: Polish
17. Replace all `withOpacity()` with `withValues(alpha:)`
18. Remove dead code (`AudioProvider`, `VideoProvider`, `logo_generator.dart`)
19. Add connectivity checks before API calls
20. Add notification support for background processing

---

## Summary Table

| Category | Done | Total | % |
|----------|------|-------|---|
| Core Services | 6 | 8 | 75% |
| UI Screens | 5 | 12+ needed | 42% |
| Pipeline Flow | Broken | 6 phases | 0% (crashes) |
| Settings | 1 | 6+ needed | 17% |
| Provider Integration | 1 (OpenRouter) | 25+ | 4% |
| Project Management | 0 | 5+ needed | 0% |
| Error Handling | 0 | 5+ needed | 0% |
| **OVERALL** | — | — | **~35%** |
