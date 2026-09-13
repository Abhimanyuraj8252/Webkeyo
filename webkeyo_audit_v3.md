# Webkeyo Codebase Audit V3 — 2026-09-13

Audited commit: `ce39a5e` (feat: upgrade TTS pipeline with Edge TTS and Piper TTS support, project-level AI config, and UI improvements)

**Supersedes** `webkeyo_audit_v2.md` and `webkeyo_full_audit.md` — those two files describe the app state from months ago (crash-on-launch bug, missing assets, no video player, etc.) which have since been fixed. They should be deleted or archived; they contradict the current code and contain a developer's local machine paths.

---

## 1. What actually works today ✅

| Area | Status |
|---|---|
| Pipeline core flow | ✅ Extract → Vision script → Script editor → TTS → FFmpeg render, with retry button + error state |
| Video preview & share | ✅ `VideoPreviewScreen` with player, scrubbing, `share_plus` share |
| Project dashboard | ✅ Real Hive-backed project list on Home, status badges, delete, resume-by-status for `created`/`script_ready`/`done` |
| Provider registry | ✅ 30+ providers, API key entry, dynamic `/models` fetch for OpenAI-compatible providers, Hive persistence |
| Dynamic API service | ✅ No more hardcoded OpenRouter — uses project's baseUrl/model |
| Theme system | ✅ Dark/light toggle persisted in Hive, Google Fonts, animations |
| Permissions | ✅ Requested at launch (storage, manage-external, media) |
| FFmpeg strategy | ✅ Per-scene mp4 + concat (mobile-safe), Ken Burns for landscape, Y-pan for portrait manga, cleanup of intermediates |
| Heavy work off main thread | ✅ Base64 encoding and CBZ extraction run in isolates |
| Hive adapters | ✅ Backward-compatible reads for older project records |
| `withOpacity()` deprecations | ✅ 0 remaining (use `withAlpha`/`withValues`) |

**Overall: ~60% of the way to a shippable product.** The skeleton is solid; the gaps below are real, user-visible.

---

## 2. 🔴 CRITICAL BUGS (wrong output or broken UX)

### C1. `image_index` mismatch — wrong pages in the final video (biggest bug)
`lib/services/api_service.dart` → `generateScript()`

- The AI is sent only **10 sampled pages** (`_sampleImages(imagePaths, maxImages: 10)`), labeled `"Image Index 0"` … `"Image Index 9"`.
- The prompt tells the model `image_index` refers to that label.
- But `pipeline_progress_screen.dart` (Phase 4) maps each scene with `project.extractedImagePaths[imageIndex]` — i.e., the index is applied to the **full** image list, not the sample.

**Result:** For any source with >10 pages, most scenes are narrated over the *wrong page*. Small files (<10 pages) work by coincidence.
**Fix:** Keep the sample→original index map and remap `image_index` back to the real path before saving the script (or send the real index labels to the model).

### C2. TTS provider selection is dead — API keys never reach the pipeline
`lib/features/home/home_screen.dart` (`_pickFiles`) and `lib/features/project/screens/project_context_screen.dart` (`_changeProjectModel`)

- HomeScreen saves only `ttsProviderId` to the project — **`ttsModelId`, `ttsApiKey`, `ttsBaseUrl` are never set** (contrast with vision, which copies base URL + key).
- `_changeProjectModel` (project screen) updates only `ttsModelId`/`ttsProviderId`, again not key/base URL.
- Pipeline Phase 4 builds `TtsService(apiKey: project.ttsApiKey, ...)` → always `null` for ElevenLabs/OpenAI TTS → request fails → **silent fallback to local Flutter TTS**.

**Result:** User picks ElevenLabs, sees "Generating Audio", gets robotic local voice. Paid provider is never used.
**Fix:** When a TTS model is chosen, copy the provider's `apiKey`/`customBaseUrl` from `ProviderRegistry` into the project (same pattern as vision in HomeScreen).

### C3. Changing the Vision provider on the project screen breaks it
`project_context_screen.dart` → `_changeProjectModel`

- Updates `visionModelId` but **not** `visionBaseUrl`/`visionApiKey`.
- After switching e.g. Gemini → Groq, the project still holds Gemini's base URL + Gemini key + Groq's model id → guaranteed 401/404.
- Same class of bug as C2.

### C4. Video Resolution & Export Path settings are fake
- Settings screen and the project Video tab both let the user pick **720p/1080p/1440p/4K** and a custom **Export Path** (persisted to SharedPreferences / `ProjectModel.videoResolution` / `customExportPath`).
- `FfmpegService.renderFinalVideo()` **ignores both**: the filter is hardcoded `1920x1080` and the output is hardcoded `/storage/emulated/0/Movies/Webkeyo`.
- The pipeline call also doesn't pass `resolution` or `exportPath` at all.

**Result:** 4K selection still renders 1080p; export path selection does nothing.
**Fix:** Add `resolution` + `exportDir` parameters to `renderFinalVideo`, pass `project.videoResolution` / `project.customExportPath ?? default` from the pipeline.

### C5. App killed mid-pipeline → full re-run (AI tokens wasted, script overwritten)
- If the app is backgrounded/killed while status = `extracting|scripting|audio|rendering`, reopening the project from Home pushes `PipelineProgressScreen` with the **default `startPhase: 1`** (HomeScreen never computes the phase from status).
- The pipeline re-extracts, **re-runs the paid Vision API call and overwrites the existing script**, then bounces to the script editor again.
- The `startPhase` param exists and the Project Context screen uses it correctly (1/2/4/5) — HomeScreen just doesn't.

**Fix:** Map status → start phase (`extracting`→1, `scripting`→2, `audio`→4, `rendering`→5, `script_ready`→editor).

### C6. `setState` after `await` without `mounted` guards
`pipeline_progress_screen.dart` Phase 1 & 2:

```dart
await project.save();
setState(() => _currentPhase = 2);   // ← no mounted check
...
await project.save();
setState(() => _currentPhase = 3);   // ← no mounted check
```

If the user swipes back (or the system kills the UI) during the long AI call, this throws an unhandled "called after dispose" error. Other spots in the same file do guard with `mounted` — these two don't.

---

## 3. 🟠 HIGH SEVERITY

### H1. Language support is partial & voice selection is hardcoded
- Home offers **17 languages**, but `TtsService._mapLanguage` only maps ~10. Portuguese, Arabic, Chinese, Italian, Russian, Turkish, Vietnamese, Indonesian, Thai → silently fall back to `en-US`.
- Edge TTS voice: `hi-IN ? hi-IN-MadhurNeural : en-US-AriaNeural` — so Japanese/Korean/Spanish/… narration is read by **an English voice**.
**Fix:** Full language→(locale, neural voice) table per provider (Edge has a voice per language: `ja-JP-NanamiNeural`, `ko-KR-SunHiNeural`, `es-ES-ElviraNeural`, `ar-SA-ZariyahNeural`, …). Add a voice picker.

### H2. TTS providers listed but not implemented → silent local fallback
`TtsService` switch only handles `edge_tts`, `piper_tts`, `openai_tts`, `elevenlabs`, `flutter_tts`. The registry also offers **Deepgram, Google Cloud TTS, Mistral TTS, NVIDIA NIM TTS** — selecting them falls into `default` → local Flutter TTS. User believes a cloud voice was used.
**Fix:** Implement them, or remove/hide them from the TTS category until they work.

### H3. Edge TTS goes through a random third-party public proxy
Default URL `https://edge-tts.vercel.app/api/tts` — the narration text is POSTed to a stranger's Vercel instance (privacy risk) and is down whenever that instance is down.
**Fix:** Speak the Microsoft Edge TTS WebSocket protocol directly (the open-source `edge-tts` approach, no key needed), or require a user-supplied self-hosted URL.

### H4. "Piper TTS (Offline)" is not offline
It's an HTTP POST to a self-hosted server (`baseUrl` required) — no bundled ONNX model. And because `ttsBaseUrl` is never propagated (C2), picking Piper from Home always falls back to local TTS.
**Fix:** Bundle Piper + ONNX voice models and run locally (true offline), or rename to "Piper (self-hosted server)" and make the URL mandatory with validation.

### H5. Multi-file selection silently drops files
`HomeScreen._pickFiles`: `allowMultiple: true` but `break; // Process first file, rest queued` — **no queue exists**. Picking 3 files processes 1 and silently discards 2.
**Fix:** Either disable multi-select, or create projects for every picked file.

### H6. Image Editor "Extra Scenes for Video" is a dead feature
`ImageEditorScreen` crops pages into `project.editedImagePaths` — the pipeline **never reads `editedImagePaths`** (Phase 4 uses only `extractedImagePaths`). There's also no way to map a cropped scene onto a script scene. The UI promise ("Extra Scenes for Video") is never kept.
**Fix:** Add an optional per-scene `image_override` to the script schema and honor it in Phase 4 — or remove the feature.

### H7. "Auto-Character Detection" is unreachable (README advertises it)
`FaceDetectionService`, `CharacterAssignmentScreen`, and `ApiService.autoDetectCharacters()` are **imported/called by nothing**. The whole character-assignment flow is orphaned.
**Fix:** Wire a "Detect characters" action into the project context screen (faces from extracted images + `autoDetectCharacters` for names) — or drop the README claim.

### H8. Messy/duplicated default provider list
`ProviderRegistry._initializeDefaultProviders`:
- `openai_vision`, `anthropic_vision`, `openrouter_vision` are each **defined twice** (Hive dedupes by id, but the code is wrong).
- "Google Gemini Vision" appears twice (`gemini_vision` + `google_vision`), "Mistral AI" twice, "Novita" twice → duplicate entries in the UI.
- `aws_bedrock` and `azure_openai` ship with **empty base URLs** → `Uri.parse('/chat/completions')` throws at runtime with a confusing error; HuggingFace's base URL isn't a chat-completions endpoint at all.
**Fix:** Dedupe, remove providers the app can't actually talk to (the client is strictly OpenAI-compatible `/chat/completions` + `/models`), and validate `baseUrl` before any request with a friendly error.

### H9. No JSON validation in the script editor
A user edit that breaks the JSON only fails in Phase 4 ("Invalid script JSON"). The editor should validate live (it's already the "interactive script editor") and show line-level errors.

### H10. Retry re-does entire phases
TTS failure → all scenes re-generated (no per-scene skip of already-generated files). Render failure → all scenes re-rendered. At minimum, skip scenes whose audio file already exists.

### H11. Quick Tools are Android-only
`ToolsScreen` writes every output to hardcoded `/storage/emulated/0/...` paths → **crashes/fails on iOS** (and on Android without All-Files access).
**Fix:** Use `path_provider` (Movies directory) + MediaStore, or `file_picker` save dialog.

### H12. Permissions approach is Play-Store risky
`main.dart` requests `MANAGE_EXTERNAL_STORAGE` (opens the "All files access" special-access screen) plus the deprecated `Permission.storage` on Android 13+. Combined with a `web` folder that can never build (heavy `dart:io`/FFmpegKit usage), this is the kind of thing that gets apps rejected.
**Fix:** Scope to what's needed (read picked files, write to app-owned Movies dir / MediaStore), document the All-Files rationale, and remove the `web/` scaffold or mark it unsupported.

---

## 4. 🟡 MISSING FEATURES (what the app still needs)

| # | Feature | Why it matters |
|---|---|---|
| M1 | **Resume from saved phase** (see C5) | Core UX for a multi-minute pipeline |
| M2 | **Per-scene audio preview** before render | `just_audio` is already a dep; user should be able to listen to a scene and regen just that one |
| M3 | **SRT/subtitle generation** | Recap channels always need captions; the script JSON has everything required |
| M4 | **Background music / SFX** | "Cinematic" is in the tagline; zero audio mixing of any kind |
| M5 | **Batch/queue processing** (see H5) | Natural for multi-chapter manga |
| M6 | **Saved scripts browser / history** | Browse, reuse, delete old scripts |
| M7 | **TTS voice picker** | Only 2 voices exist today, both hardcoded (H1) |
| M8 | **Connectivity check before API calls** | `connectivity_plus` in pubspec, never used — users get 3-minute timeouts on WiFi→mobile drops |
| M9 | **Notifications for long jobs** | `flutter_local_notifications` in pubspec, never used — render can take minutes |
| M10 | **App lifecycle handling** | Pipeline state should pause/resume or at least be documented; currently a backgrounded phone kills the Dart isolate mid-job |
| M11 | **i18n** | UI is English-only; the app's primary market (Hindi/Hinglish) would benefit from a Hindi UI |
| M12 | **Onboarding / first-run** | API-key setup is the #1 friction point; needs a guided flow |
| M13 | **Project export/import (JSON)** | Move projects between phones |
| M14 | **Thumbnail/frame export & video trim** | Basic post-processing |
| M15 | **Usage/cost tracking** | Show API tokens/credits spent per project |

---

## 5. 🧹 REPO HYGIENE

| Issue | Detail |
|---|---|
| **No LICENSE file** | README claims MIT; `LICENSE` does not exist |
| **Stale audit files committed** | `webkeyo_audit_v2.md`, `webkeyo_full_audit.md` — contradict current code, contain local machine paths (`/home/abhimanyu/Trikrypta/...`) |
| **README false claims** | "Production Ready" badge, "4K Cinematic Video" (renders fixed 1080p), "Piper TTS (Offline)", "Auto-Character Detection" (unreachable), "25+ providers" (only OpenAI-compatible ones actually work), "15+ languages" (TTS covers ~8) |
| **Dead code** | `lib/features/processing/process_provider.dart`, `lib/services/file_service.dart` (duplicated by `ConversionService`), `lib/logo_generator.dart` — none imported anywhere |
| **Unused deps** | `flutter_local_notifications`, `connectivity_plus`, `flutter_svg` (in pubspec, zero imports) |
| **Zero tests** | No `test/` directory at all |
| **No CI** | No `.github/workflows` — no `flutter analyze` / build gate |
| **No crash reporting / logging** | `debugPrint` everywhere, no Sentry/Crashlytics, no `FlutterError.onError` |
| **`web/` folder** | App uses `dart:io` + FFmpegKit → `flutter build web` can never work; remove or document |
| **`.metadata`** | Contains stale machine/device info from a previous machine (harmless, but noise) |
| **Provider keys stored in plain Hive** | API keys (vision + TTS) are stored unencrypted on device; acceptable for a personal tool, but worth a settings note / consider `flutter_secure_storage` |

---

## 6. ⏱️ PRIORITIZED FIX PLAN

**Phase 1 — Correctness (do first, small diffs)**
1. C1: remap sampled `image_index` → real image path
2. C2/C3: propagate provider `apiKey`/`baseUrl` into the project on model selection (TTS + vision)
3. C5: HomeScreen → compute `startPhase` from project status
4. C6: add `mounted` guards in pipeline Phase 1–2

**Phase 2 — Make settings real**
5. C4: pass `videoResolution` + `customExportPath` into `FfmpegService` (parametrize the 1920x1080 filter and output dir)
6. H1: full language→voice map + voice picker
7. H5: fix multi-file (queue or single-select)
8. H11: Android-only paths in ToolsScreen

**Phase 3 — Feature completion**
9. H7: wire character detection into project context (or cut the claim)
10. H6: scene→image overrides, or remove Image Editor promise
11. M2/M3/M4: scene audio preview, SRT export, background music
12. H3/H4: real Edge TTS protocol; true offline Piper or re-label
13. M8/M9: connectivity checks + job notifications

**Phase 4 — Hygiene & quality**
14. H8: clean provider list; validate baseUrl
15. Add tests (unit: sampling remap, TtsService language map, ProjectModelAdapter round-trip; widget: home dashboard)
16. CI: `flutter analyze` + `flutter build apk --debug` on push
17. Add `LICENSE`; fix README claims; delete stale audit files; remove dead code + unused deps
18. Crash reporting + global error handler

---

## 7. File-by-file status (current code)

| File | Status |
|---|---|
| `lib/main.dart` | ✅ Works; H12 (permission scope) |
| `lib/core/theme.dart`, `constants.dart` | ✅ Clean |
| `lib/models/ai_model.dart`, `ai_provider_model.dart` | ✅ Clean |
| `lib/models/project_model.dart` | ✅ Backward-compatible adapter; fields for resolution/export path exist but unused downstream (C4) |
| `lib/services/api_service.dart` | 🟠 C1 (index mismatch); `autoDetectCharacters` orphaned (H7) |
| `lib/services/tts_service.dart` | 🟠 C2, H1, H2, H3, H4 |
| `lib/services/ffmpeg_service.dart` | 🟠 C4 (hardcoded resolution + path); otherwise solid |
| `lib/services/provider_registry.dart` | 🟠 H8 (dupes, unusable providers) |
| `lib/services/conversion_service.dart` | ✅ Works (PDF render still on main thread — watch for big PDFs) |
| `lib/services/dynamic_api_client.dart` | ✅ Works for OpenAI-compatible APIs |
| `lib/services/face_detection_service.dart` | ⚠️ Orphaned (H7) |
| `lib/services/file_service.dart` | ⚠️ Dead code |
| `lib/features/processing/process_provider.dart` | ⚠️ Dead code |
| `lib/logo_generator.dart` | ⚠️ Dead code |
| `lib/features/home/home_screen.dart` | 🟠 C2 (TTS wiring), C5 (no resume), H5 (multi-file drop) |
| `lib/features/home/model_selector_sheet.dart` | ✅ Works; minor: `_selectedProvider ??=` mutation inside `build` |
| `lib/features/pipeline/screens/pipeline_progress_screen.dart` | 🟠 C6 (mounted guards), H10 (retry granularity) |
| `lib/features/pipeline/screens/script_editor_screen.dart` | 🟡 H9 (no JSON validation) |
| `lib/features/pipeline/screens/video_preview_screen.dart` | ✅ Works; minor: ternary side-effect inside `setState` |
| `lib/features/project/screens/project_context_screen.dart` | 🟠 C3 (vision re-select), otherwise the best screen in the app |
| `lib/features/project/screens/image_editor_screen.dart` | 🟠 H6 (output never used by pipeline) |
| `lib/features/project/screens/character_assignment_screen.dart` | ⚠️ Orphaned (H7) |
| `lib/features/settings/settings_screen.dart` | 🟠 C4 (settings not wired to renderer); theme toggle ✅ |
| `lib/features/settings/providers_screen.dart`, `provider_tile.dart` | ✅ Works |
| `lib/features/tools/tools_screen.dart` | 🟠 H11 (Android-only output paths) |
