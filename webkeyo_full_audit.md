# 🔍 Webkeyo - Complete Codebase Audit & Fix Document

> **Purpose**: This document lists EVERY missing feature, broken implementation, and issue in the current Webkeyo codebase compared to the user's requirements. Give this document to an AI assistant to fix and implement everything.

---

## 📋 Summary of Current State

The app has a **basic skeleton** with ~15 files but is **only ~15-20% complete**. Most features are either **stubs**, **hardcoded**, or **completely missing**. The app currently can:
- ✅ Pick CBZ/ZIP files (partially)
- ✅ Extract CBZ/ZIP archives to temp directory
- ✅ Sort extracted images
- ✅ Has a basic dark theme
- ✅ Has basic FFmpeg video rendering logic (untested, has issues)
- ✅ Has a placeholder TTS service
- ✅ Has a basic OpenRouter API integration (incomplete)

**What does NOT work or is missing**: Almost everything else. See below.

---

## 🚨 CRITICAL ISSUE #1: PDF Support is Completely Missing

### Current State
- [file_service.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/services/file_service.dart) only supports `.cbz` and `.zip` extensions
- [home_screen.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/features/home/home_screen.dart) `_pickFiles()` allows `.cbz`, `.pdf`, `.zip` in the picker BUT there is **zero PDF handling logic**
- No PDF-to-image conversion exists anywhere

### What Needs to Be Done
1. Add `pdf_render` or `pdfx` package to `pubspec.yaml` for PDF rendering
2. Add a `PdfService` or extend `FileService` with:
   - `extractPdfToImages(File pdfFile)` → renders each PDF page as a PNG/JPEG image
   - Save extracted images to temp directory in order
3. In the processing pipeline, detect file extension and route to correct extraction method:
   - `.cbz` / `.zip` → archive extraction (existing)
   - `.pdf` → PDF page rendering to images (NEW)
4. Must work fully offline and be free

---

## 🚨 CRITICAL ISSUE #2: Image Folder Support is Missing

### Current State
- No ability to select a folder of images
- User wants to select a folder containing images (JPG, PNG, etc.) directly

### What Needs to Be Done
1. Add folder picker using `file_picker` package's `getDirectoryPath()` method
2. On the home screen, add a separate button/option for "Select Image Folder"
3. When folder is selected, scan recursively for image files (`.jpg`, `.jpeg`, `.png`, `.webp`)
4. Sort them and treat them exactly like extracted CBZ images
5. The upload card already says "Tap to select CBZ, PDF, or Folder" but folder picking is NOT implemented

---

## 🚨 CRITICAL ISSUE #3: Hindi Script Generation is NOT Implemented

### Current State
- [api_service.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/services/api_service.dart) generates scripts in English
- The system prompt says "generate a recap script" but does NOT specify Hindi
- No language translation is happening
- User explicitly wants: "AI should generate the full script/explanation in Hindi, regardless of source language (English, Japanese, Korean, etc.)"

### What Needs to Be Done
1. Modify the system prompt in `api_service.dart` to explicitly instruct the AI:
   ```
   "You MUST write ALL narration text in Hindi (Devanagari script). 
   Even if the source material is in English, Japanese, Korean, or any other language, 
   your output narration MUST be in Hindi only."
   ```
2. Add a language selection option in settings (default: Hindi)
3. The output JSON schema should remain the same but `narration` field must be in Hindi

---

## 🚨 CRITICAL ISSUE #4: Free TTS (Text-to-Speech) is NOT Working

### Current State
- [tts_service.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/services/tts_service.dart) sends HTTP POST to `http://127.0.0.1:5000/generate-tts` — this is a **local server that doesn't exist**
- There is NO actual TTS engine integrated
- User wants: **Free, unlimited, natural Hindi voice with emotions, minimum 20 minutes audio**
- Settings show "Edge-TTS" and "Piper TTS" radio buttons but they do NOTHING — just local state

### What Needs to Be Done
1. **Primary Free TTS: Edge-TTS** (100% free, unlimited, Microsoft voices)
   - Add `edge_tts` Python dependency OR use the Edge-TTS REST API approach
   - Better approach for Flutter mobile: Use `flutter_tts` package which uses device's built-in TTS engine
   - OR run Edge-TTS via a bundled Python script or use a free Edge-TTS web API
   - **Recommended**: Use `flutter_tts` package (free, works offline, supports Hindi)
     - Voice: `hi-IN` locale with available Hindi voices
     - Alternative: Call Edge-TTS via HTTP to a free public endpoint or self-hosted
   
2. **Alternative: Piper TTS** (free, offline, open source)
   - Would need to bundle Piper binary for Android — complex but doable
   
3. **Implementation**:
   - Replace the current HTTP-based TTS with actual `flutter_tts` integration
   - Add Hindi voice configuration: `await flutterTts.setLanguage("hi-IN")`
   - Add speech rate, pitch controls
   - Save generated audio as WAV/MP3 files
   - Calculate duration for FFmpeg sync

4. **Provider System**: Allow user to switch between:
   - `flutter_tts` (free, built-in, default)
   - Edge-TTS API (free, better quality)
   - ElevenLabs (paid, user provides API key)
   - Custom API endpoint (user-configured)

---

## 🚨 CRITICAL ISSUE #5: Multiple Chapter Support is Missing

### Current State
- Can only pick files but has no concept of "chapters"
- No batch/multi-chapter processing
- User wants: "Ek saat multiple chapter ko analyse karke script generate kar sake"

### What Needs to Be Done
1. Allow picking multiple CBZ/PDF files at once (already partially done with `allowMultiple: true`)
2. Process all files sequentially:
   - Extract images from each file
   - Combine all images in chapter order
   - Generate ONE combined script from all chapters
3. Add chapter ordering UI — drag-to-reorder list
4. Chapter names should appear in the script for clarity
5. Create a `ChapterModel` with: `name`, `filePath`, `order`, `imageCount`

---

## 🚨 CRITICAL ISSUE #6: Conversion Tools (CBZ↔PDF↔Image) are Missing

### Current State
- Only CBZ extraction to images exists
- No CBZ-to-PDF, PDF-to-CBZ, PDF-to-Image standalone conversion tools

### What Needs to Be Done
User wants these as utility features:
1. **CBZ to Images**: ✅ Partially exists (but needs proper UI)
2. **CBZ to PDF**: Convert extracted CBZ images into a single PDF file
   - Use `pdf` package to create PDF from images
3. **PDF to Images**: Extract each PDF page as image
   - Use `pdfx` or `pdf_render` package
4. **PDF to CBZ**: Convert PDF pages to images, then create CBZ (ZIP with images)
5. Add a **Tools/Utilities** screen accessible from home with these conversion options

---

## 🚨 CRITICAL ISSUE #7: Video is NOT Fit-to-Screen

### Current State
- [ffmpeg_service.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/services/ffmpeg_service.dart) uses `scale=1920:1080:force_original_aspect_ratio=decrease` with `pad` — this adds **black bars**
- User explicitly says: "full screen tak aate ye na ki chota ho ya bada fit to screen hona chahiye"
- Manga/manhwa images are typically portrait (tall) — need special handling

### What Needs to Be Done
1. Change FFmpeg filter to **crop and fill** instead of letterbox:
   ```
   scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080
   ```
   This ensures images FILL the entire 1920x1080 frame by cropping excess
2. OR use a **Ken Burns pan** effect on tall images:
   - Start from top, slowly pan down to bottom over the duration
   - This is what professional recap channels do
3. Better approach: **Detect image aspect ratio**:
   - If landscape → scale to fill
   - If portrait/tall → apply slow top-to-bottom pan (zoompan with y-axis movement)
4. The current `zoompan` filter is broken — it only zooms in but doesn't pan, making tall manga images show only the top portion

---

## 🚨 CRITICAL ISSUE #8: Video Export Path is Wrong

### Current State
- [video_provider.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/features/video_generation/video_provider.dart) saves to `getApplicationDocumentsDirectory()` — this is the **app's private internal storage**, not accessible to the user
- User wants: "Movies folder → App Name folder → Video Name folder → video file"

### What Needs to Be Done
1. Save to the device's public **Movies** directory
2. Folder structure: `/storage/emulated/0/Movies/Webkeyo/{VideoName}/{VideoName}_final.mp4`
3. Use `path_provider`'s external storage or request `MANAGE_EXTERNAL_STORAGE` permission
4. Need Android permissions:
   - `WRITE_EXTERNAL_STORAGE`
   - `READ_EXTERNAL_STORAGE`
   - `MANAGE_EXTERNAL_STORAGE` (for Android 11+)
5. Add `permission_handler` package to request runtime permissions

---

## 🚨 CRITICAL ISSUE #9: Video Transitions & Effects are Missing

### Current State
- Each scene is just a static image with a basic zoom — no transitions between scenes
- User wants: "video kuch aache transition aur effect bhi ho"

### What Needs to Be Done
1. Add **crossfade transitions** between scenes using FFmpeg `xfade` filter:
   ```
   -filter_complex "[0:v][1:v]xfade=transition=fade:duration=0.5:offset=X"
   ```
2. Available transitions to implement:
   - `fade` (default)
   - `wipeleft`, `wiperight`
   - `slidedown`, `slideup`
   - `dissolve`
3. Add **text overlays** for chapter/scene numbers
4. Add subtle **vignette effect** for cinematic feel
5. Add **background music** option (low volume ambient)
6. Let user choose transition type in settings

---

## 🚨 CRITICAL ISSUE #10: Pre-existing Audio Support is Missing

### Current State
- No option to use user's own audio file
- User says: "user chahiye to agar audio pehle se hai to direct video bankar usi audio ko use kar sakta hai"

### What Needs to Be Done
1. Add a "Use Custom Audio" button on the processing screen
2. Allow picking `.mp3`, `.wav`, `.m4a`, `.aac` audio files
3. When custom audio is provided:
   - Skip the TTS generation step entirely
   - Calculate audio duration
   - Divide images evenly across the audio duration
   - Generate video with provided audio
4. AI should still analyze images and create scene-by-scene mapping with the custom audio

---

## 🚨 CRITICAL ISSUE #11: AI Scene-by-Scene Video Creation is Missing

### Current State
- The script generation creates a flat list of scenes
- No intelligent mapping of specific images to specific narration segments
- User wants: "AI image aur audio ke hisab se scene by scene video bana de"

### What Needs to Be Done
1. AI should map specific images to specific narration segments
2. Script JSON should include image references:
   ```json
   {
     "scenes": [
       {
         "scene_number": 1,
         "image_indices": [0, 1, 2],
         "description": "...",
         "narration": "Hindi narration..."
       }
     ]
   }
   ```
3. Each scene can use multiple images with transitions between them
4. Duration per scene should be based on narration length (auto-calculated from TTS)
5. This is the CORE intelligence of the app — needs proper implementation

---

## 🚨 CRITICAL ISSUE #12: Provider/Settings System is Incomplete

### Current State
- [settings_screen.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/features/settings/settings_screen.dart) has:
  - OpenRouter API key input (not saved/persisted)
  - Custom prompt input (not saved/persisted)
  - NSFW toggle (not saved/persisted)
  - TTS engine radio (not saved/persisted)
- **Nothing is saved to SharedPreferences** — all settings are lost on app restart
- User wants separate provider settings for each function

### What Needs to Be Done
1. **Save all settings to SharedPreferences** — currently NOTHING persists
2. Add separate settings sections for:
   - **Script AI Provider**: OpenRouter, Groq, Custom
   - **Vision AI Provider**: OpenRouter (with vision model), Groq (with vision model)
   - **TTS Provider**: flutter_tts (free), Edge-TTS (free), ElevenLabs (paid), Custom API
   - **Video Settings**: Resolution, FPS, transition type
3. Each provider section should have:
   - Provider dropdown selector
   - API key input field (if needed)
   - Model selector dropdown
   - Base URL field (for custom endpoints)
4. Create a `SettingsService` or `SettingsProvider` to manage all preferences
5. Load settings on app startup via `SharedPreferences`

---

## 🚨 CRITICAL ISSUE #13: Groq API Support is Missing

### Current State
- Only OpenRouter is integrated
- User explicitly mentions: "script ke liye ham OpenRouter ya Groq ka use kar sakte ho, 100% free hota hai"

### What Needs to Be Done
1. Add Groq API integration in `api_service.dart`:
   - Groq API base URL: `https://api.groq.com/openai/v1`
   - Groq is compatible with OpenAI API format
   - Free models available: `llama-3.2-90b-vision-preview`, `llama-3.3-70b-versatile`
2. Add Groq API key field in settings
3. Allow switching between OpenRouter and Groq
4. Both support vision models for image analysis (Groq has `llama-3.2-90b-vision-preview`)

---

## 🚨 CRITICAL ISSUE #14: Vision AI for Manga Text Detection is Broken

### Current State
- Uses `meta-llama/llama-3.2-11b-vision-instruct` on OpenRouter — this is a PAID model
- Only samples 10 images max — for 100+ page manga this loses too much context
- User says: "AI vision power chahiye taki script sahi se generate kar sake kyunki manhwa mein kuch aise text hote jo OCR bhi nahi find kar pata par AI detect kar leta"

### What Needs to Be Done
1. Use **FREE** vision models:
   - Groq: `llama-3.2-90b-vision-preview` (free)
   - OpenRouter: Filter for free vision models only
2. Increase image sampling intelligently:
   - Sample more images (20-30 per batch)
   - For very long manga, process in batches and combine scripts
   - Compress/resize images before Base64 encoding to reduce payload size
3. Add image preprocessing:
   - Resize to max 1024px width before sending to API
   - Convert to JPEG with 80% quality to reduce size
   - This allows sending more images in one request
4. Process chapters in batches if too many images

---

## 🚨 CRITICAL ISSUE #15: Providers are NOT Registered in main.dart

### Current State
- [main.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/main.dart) explicitly comments out `MultiProvider` saying "crashes if empty"
- `ProcessProvider`, `AudioProvider`, `VideoProvider` exist but are **never registered**
- No state management is active — the app cannot actually process anything

### What Needs to Be Done
1. Add `MultiProvider` in `main.dart` wrapping the `MaterialApp`:
   ```dart
   MultiProvider(
     providers: [
       ChangeNotifierProvider(create: (_) => ProcessProvider()),
       ChangeNotifierProvider(create: (_) => AudioProvider()),
       ChangeNotifierProvider(create: (_) => VideoProvider()),
       ChangeNotifierProvider(create: (_) => SettingsProvider()),
     ],
     child: const GlobalMediaApp(),
   )
   ```
2. Use `context.watch<ProcessProvider>()` in UI screens
3. Wire up the complete pipeline: File Pick → Extract → Script → TTS → Video

---

## 🚨 CRITICAL ISSUE #16: Android Permissions are Missing

### Current State
- AndroidManifest.xml only has `INTERNET` permission
- Missing critical permissions for the app to function

### What Needs to Be Done
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```
Also add `android:requestLegacyExternalStorage="true"` to `<application>` tag.

---

## 🚨 CRITICAL ISSUE #17: No Processing/Pipeline UI Screen

### Current State
- Home screen picks files and adds them to a list but **nothing happens after that**
- No screen showing the pipeline progress (extracting → generating script → TTS → video rendering)
- No way to trigger the actual processing

### What Needs to Be Done
1. Create a **ProcessingScreen** that shows step-by-step progress:
   - Step 1: File Extraction (with progress bar)
   - Step 2: AI Script Generation (with loading animation)
   - Step 3: Script Review/Edit (let user see and edit the generated script)
   - Step 4: Audio Generation (TTS progress)
   - Step 5: Video Rendering (FFmpeg progress with percentage)
   - Step 6: Export Complete (show file path, share button)
2. Each step should show status: Pending → In Progress → Complete → Error
3. User should be able to:
   - Review/edit the generated script before TTS
   - Preview individual audio clips
   - Cancel processing at any stage

---

## 🚨 CRITICAL ISSUE #18: No Error Handling UI

### Current State
- Errors only go to `debugPrint` — user sees nothing
- No snackbar, dialog, or error state in UI
- If API call fails, TTS fails, or FFmpeg fails — app shows nothing

### What Needs to Be Done
1. Add proper error handling with user-visible messages
2. Show `SnackBar` or `Dialog` on errors
3. Add retry buttons for failed operations
4. Add offline detection and appropriate messaging

---

## 🚨 CRITICAL ISSUE #19: Missing Dependencies in pubspec.yaml

### Current State
Missing several critical packages.

### What Needs to Be Done
Add these packages to `pubspec.yaml`:
```yaml
dependencies:
  # Existing
  flutter_tts: ^4.2.0          # Free on-device TTS (CRITICAL)
  permission_handler: ^11.3.0   # Runtime permissions
  pdfx: ^2.6.0                 # PDF rendering to images
  pdf: ^3.11.0                 # PDF creation
  image: ^4.3.0                # Image processing/resizing
  video_player: ^2.9.0         # Video preview
  share_plus: ^10.0.0          # Share exported videos
  uuid: ^4.5.0                 # Unique IDs
  connectivity_plus: ^6.0.0    # Network status checking
  flutter_local_notifications: ^18.0.0  # Processing notifications
```

---

## 🚨 CRITICAL ISSUE #20: TaskModel is Too Basic

### Current State
- [task_model.dart](file:///home/abhimanyu/Trikrypta/Webkeyo/lib/models/task_model.dart) only has `fileName`, `status`, `progress`
- Cannot track the full pipeline state

### What Needs to Be Done
Expand `TaskModel` to:
```dart
class TaskModel {
  final String id;
  final String fileName;
  final String filePath;
  final String fileType; // 'cbz', 'pdf', 'folder'
  final List<String> imagePaths;
  final String? scriptJson;
  final String? audioPath;
  final String? videoPath;
  final TaskStatus status;
  final double progress;
  final String? errorMessage;
  final DateTime createdAt;
  // Pipeline step tracking
  final PipelineStep currentStep;
}

enum TaskStatus { queued, processing, completed, failed, cancelled }
enum PipelineStep { extraction, scriptGeneration, ttsGeneration, videoRendering, exporting, done }
```

---

## 🚨 CRITICAL ISSUE #21: App Doesn't Actually DO Anything End-to-End

### Current State
The complete pipeline is **not wired together**. The flow should be:
1. User picks file(s) → ❌ Only picks, doesn't process
2. Extract images → ✅ Code exists but not triggered from UI
3. Send to AI → ✅ Code exists but not triggered
4. Get Hindi script → ❌ Not Hindi
5. Convert script to audio (TTS) → ❌ TTS doesn't work (no real engine)
6. Edit/crop images for video → ❌ Not implemented
7. Render video with transitions → ⚠️ Basic code exists, missing transitions
8. Merge audio with video → ⚠️ Basic code exists
9. Export to Movies folder → ❌ Saves to wrong location
10. Show completion → ❌ No completion UI

### What Needs to Be Done
Wire the ENTIRE pipeline from start to finish. Every step must trigger the next step automatically with progress feedback to the user.

---

## 🚨 CRITICAL ISSUE #22: `flutter_tts` Not Integrated

### Current State
- Uses HTTP-based TTS to a non-existent localhost server
- `just_audio` is in pubspec but only used to measure audio duration

### What Needs to Be Done  
1. Add `flutter_tts` package
2. Implement on-device TTS for Hindi:
```dart
final flutterTts = FlutterTts();
await flutterTts.setLanguage("hi-IN");
await flutterTts.setSpeechRate(0.5);
await flutterTts.setPitch(1.0);
await flutterTts.synthesizeToFile(text, "output.wav");
```
3. This is FREE, unlimited, offline, and supports Hindi with emotions
4. For better quality, implement Edge-TTS via Python subprocess or HTTP API

---

## 🚨 CRITICAL ISSUE #23: `withOpacity` Deprecation Warnings

### Current State
- Multiple files use `.withOpacity()` which is deprecated in newer Flutter versions
- Found in: `upload_card.dart`, `home_screen.dart`, `settings_screen.dart`

### What Needs to Be Done
Replace all `.withOpacity(x)` with `.withValues(alpha: x)` or use `Color.fromARGB`

---

## 📝 MINOR ISSUES

### M1: `logo_generator.dart` uses `image` package not in pubspec
- `import 'package:image/image.dart'` — but `image` package is not in dependencies
- This file will cause build errors if imported

### M2: `cupertino_icons` imported in settings but not used
- `import 'package:flutter/cupertino.dart'` in settings_screen.dart is unused

### M3: No proguard rules for release builds
- FFmpeg Kit requires proguard configuration for Android release builds

### M4: No app icon configuration complete
- `flutter_launcher_icons` is in dev_dependencies but config is minimal

### M5: `ffmpeg_kit_flutter_new` may have compatibility issues
- This is a community fork; verify compatibility with latest Flutter

### M6: `test.dart` file at project root
- There's a `test.dart` file at root level — should be removed or moved to `test/`

---

## 🔧 COMPLETE LIST OF FILES THAT NEED CHANGES

| File | Action | Priority |
|------|--------|----------|
| `pubspec.yaml` | Add ~10 missing packages | 🔴 Critical |
| `android/.../AndroidManifest.xml` | Add storage/permission declarations | 🔴 Critical |
| `lib/main.dart` | Add MultiProvider, wire up state management | 🔴 Critical |
| `lib/services/file_service.dart` | Add PDF extraction, folder support | 🔴 Critical |
| `lib/services/tts_service.dart` | Replace with flutter_tts/Edge-TTS | 🔴 Critical |
| `lib/services/api_service.dart` | Add Hindi prompts, Groq support, fix vision | 🔴 Critical |
| `lib/services/ffmpeg_service.dart` | Fix fit-to-screen, add transitions, fix panning | 🔴 Critical |
| `lib/models/task_model.dart` | Expand to full pipeline model | 🔴 Critical |
| `lib/features/settings/settings_screen.dart` | Add provider system, persist settings | 🔴 Critical |
| `lib/features/home/home_screen.dart` | Wire up processing, add folder support | 🟡 High |
| `lib/features/processing/process_provider.dart` | Complete pipeline orchestration | 🟡 High |
| `lib/features/processing/audio_provider.dart` | Wire to real TTS engine | 🟡 High |
| `lib/features/video_generation/video_provider.dart` | Fix export path, add transitions | 🟡 High |
| `lib/core/theme.dart` | No changes needed | ✅ OK |
| **NEW** `lib/services/pdf_service.dart` | PDF-to-image conversion | 🔴 Critical |
| **NEW** `lib/services/settings_service.dart` | SharedPreferences management | 🔴 Critical |
| **NEW** `lib/features/processing/processing_screen.dart` | Pipeline progress UI | 🔴 Critical |
| **NEW** `lib/features/tools/tools_screen.dart` | Conversion utilities UI | 🟡 High |
| **NEW** `lib/models/chapter_model.dart` | Multi-chapter data model | 🟡 High |
| **NEW** `lib/models/settings_model.dart` | Settings data model | 🟡 High |
| **NEW** `lib/features/processing/script_review_screen.dart` | Script edit before TTS | 🟡 High |

---

## 🎯 IMPLEMENTATION PRIORITY ORDER

1. **Fix `pubspec.yaml`** — Add all missing packages
2. **Fix `AndroidManifest.xml`** — Add all permissions
3. **Create `SettingsService`** — Persist all settings
4. **Fix `api_service.dart`** — Hindi script + Groq + better vision
5. **Fix `tts_service.dart`** — Integrate `flutter_tts` for free Hindi TTS
6. **Fix `file_service.dart`** — Add PDF & folder support
7. **Fix `ffmpeg_service.dart`** — Fit-to-screen + transitions + correct export path
8. **Create `ProcessingScreen`** — Full pipeline UI with step tracking
9. **Wire `main.dart`** — Register all providers
10. **Create Tools screen** — CBZ/PDF/Image conversion utilities
11. **Update all models** — Expanded TaskModel, ChapterModel, SettingsModel
12. **Fix Settings screen** — Full provider system with persistence
13. **Add error handling UI** — SnackBars, dialogs, retry buttons
14. **Test the complete pipeline** — End-to-end: pick → extract → script → TTS → video → export

---

## 💡 RECOMMENDED TECHNOLOGY STACK (All Free)

| Function | Technology | Cost |
|----------|-----------|------|
| **Framework** | Flutter (Dart) | Free |
| **Script AI** | Groq API (llama-3.3-70b) | Free |
| **Vision AI** | Groq API (llama-3.2-90b-vision) | Free |
| **TTS (Default)** | flutter_tts (on-device) | Free |
| **TTS (Better)** | Edge-TTS via HTTP | Free |
| **TTS (Premium)** | ElevenLabs (user's API key) | Paid (optional) |
| **Video Engine** | FFmpeg Kit | Free |
| **PDF Processing** | pdfx package | Free |
| **State Management** | Provider | Free |
| **Local Storage** | SharedPreferences | Free |
| **Permissions** | permission_handler | Free |

---

> **Note to AI Assistant**: When implementing fixes, ensure:
> 1. **Every feature works end-to-end** — no stubs or placeholders
> 2. **All settings persist** via SharedPreferences
> 3. **Hindi is the default language** for all script generation
> 4. **TTS actually produces audio files** — test with real Hindi text
> 5. **Video fills the screen** — no black bars, proper panning for tall manga images
> 6. **Export goes to Movies/Webkeyo/{name}/*** folder
> 7. **Free by default** — no paid APIs required for basic functionality
> 8. **No crashes** — proper null safety, error handling, and permission checks
> 9. **Smooth performance** — heavy work on isolates/background threads
> 10. **The app should work fully on Android** — that's the primary target platform
