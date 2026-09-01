# MEAL Voice Setup Guide

## Architecture

```
MICROPHONE
    ↓
ANDROID FOREGROUND SERVICE (MealVoiceService)
    ↓
WAKE WORD ENGINE (Porcupine)
    ↓
"HI MEAL" DETECTED
    ↓
METHODCHANNEL/EVENTCHANNEL BRIDGE (MealVoiceBridge)
    ↓
FLUTTER (MealVoiceService → MealVoiceController → UI)
```

## Wake-Word Engine: Porcupine (Picovoice)

**Why Porcupine:**
- Best custom wake-word support (train "Hi MEAL" directly)
- Lowest CPU/battery footprint (~0.5% battery/day)
- True on-device processing, zero cloud dependency
- Proven Android foreground service support
- Free tier: 3 custom wake words, 1000 runs/day

**Setup:**
1. Go to https://console.picovoice.ai
2. Create free account
3. Go to Porcupine → Create Wake Word
4. Type "Hi MEAL"
5. Download `.ppn` file for Android
6. Place in `android/app/src/main/assets/hi_meal_android.ppn`
7. Get your Access Key from the dashboard
8. Set it in `android/local.properties` or build config

## Android Permissions Added

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
```

## Dependencies Added

| Package | Version | Purpose |
|---------|---------|---------|
| `permission_handler` | `^11.3.0` | Runtime permission requests |
| `kotlinx-coroutines-android` | `1.7.3` | Foreground service async |

## How to Run

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Build and run:
   ```bash
   flutter run
   ```

3. Navigate to Profile → MEAL Voice Assistant

4. Grant microphone permission when prompted

5. Tap "START MEAL" to begin wake-word detection

6. Say "Hi MEAL" to trigger detection

## How to Test

### Test A: Foreground (App Open)
1. Open MEALIN app
2. Go to Profile → MEAL Voice Assistant
3. Tap "START MEAL"
4. Say "Hi MEAL"
5. Expected: "HI MEAL DETECTED" shown

### Test B: Background (App Minimized)
1. Start MEAL voice service
2. Press home button
3. Say "Hi MEAL"
4. Expected: Detection works via foreground service

### Test C: Locked Screen
1. Start MEAL voice service
2. Lock phone
3. Say "Hi MEAL"
4. Expected: May work depending on device/OS

### Test D: App Terminated
1. Force stop MEALIN app
2. Say "Hi MEAL"
3. Expected: NOT WORKING (process dead)

## Foreground Service Behavior

- Runs as Android Foreground Service with `microphone` type
- Shows persistent notification: "MEAL - Listening for 'Hi MEAL'"
- Notification cannot be dismissed while service runs
- Service stops when user taps "STOP MEAL" or app is killed

## Locked-Screen Limitations

- **Android 10-13:** Foreground service continues with notification visible
- **Android 14+:** Requires `FOREGROUND_SERVICE_MICROPHONE` permission + notification
- **Battery optimization:** May kill service after ~1 hour on some devices
- **Solution:** Ask user to disable battery optimization for MEALIN

## Battery Considerations

- Porcupine uses ~0.5% battery per day
- Audio capture at 16kHz mono, 16-bit PCM
- Local processing only, no network upload
- Minimal CPU when idle

## Privacy Considerations

- Microphone audio processed locally on device
- No audio uploaded to any server
- Wake-word detection happens on-device
- Full voice pipeline only activates AFTER wake word
- User sees persistent notification when listening

## Known Limitations

1. **App terminated:** Cannot detect wake word when app is completely killed
2. **Battery optimization:** Service may be killed on aggressive OEM skins
3. **Custom wake word:** Requires Porcupine API key (free tier available)
4. **Android 14+:** Extra permission required for microphone foreground service
5. **Some devices:** Xiaomi, Huawei, OnePlus may kill background services

## Files Created

| File | Purpose |
|------|---------|
| `lib/meal_voice/meal_voice_state.dart` | State enum and events |
| `lib/meal_voice/meal_voice_service.dart` | Flutter-side service |
| `lib/meal_voice/meal_voice_controller.dart` | Provider controller |
| `lib/meal_voice/meal_voice_screen.dart` | Developer test screen |
| `android/.../mealvoice/WakeWordEngine.kt` | Wake-word engine interface |
| `android/.../mealvoice/MealVoiceBridge.kt` | Flutter ↔ Android bridge |
| `android/.../mealvoice/MealVoiceService.kt` | Foreground service |
| `MEAL_VOICE_SETUP.md` | This documentation |

## Files Modified

| File | Change |
|------|--------|
| `AndroidManifest.xml` | Added permissions + service |
| `build.gradle.kts` | Added coroutines dependency |
| `pubspec.yaml` | Added permission_handler |
| `lib/main.dart` | Added MealVoiceController provider |
| `lib/features/.../profile_tab.dart` | Added MEAL Voice test link |

## Next Development Stage (Stage 4)

After wake-word detection works:

1. Integrate Speech-to-Text after wake
2. Add Gemini/MEAL AI for intent detection
3. Connect to MEALIN backend for restaurant search
4. Implement order placement flow
5. Add Text-to-Speech for responses
6. Handle conversation context
