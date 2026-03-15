# StepWithMe Blueprint

## Overview

StepWithMe is a fitness-focused mobile and web application designed to optimize walking and running for weight loss. Unlike traditional metronomes, it uses scientific cadence logic based on a user's BMI and age to recommend the most effective "steps per minute" (SPM) for fat burning and cardio health.

## Features

*   **Scientific Cadence Logic:** Dynamically calculates target steps per minute based on the CADENCE-Adults research study and BMI-adjusted metabolic intensity.
*   **BMI & Fitness Analytics:**
    *   Automatic BMI calculation and categorization.
    *   Target Fat Loss Heart Rate Zone (60-70% of Max HR) display.
    *   Estimated Calorie Burn per hour based on current cadence and weight.
*   **Dynamic Activity Modes:** Quick-select buttons for Light, Fat Burn, Jogging, and Running that adapt their suggested speeds to the user's specific profile.
*   **Realistic Audio Environments:** High-quality walking sounds (Grass, Forest, Gravel, Wood, etc.) that sync perfectly with the target cadence.
*   **Web-Optimized Playback:** Specialized audio handling to bypass browser autoplay restrictions and ensure low-latency rhythmic precision.
*   **Modern UI:** Clean Material 3 interface with support for Light and Dark modes.

## Implementation Details

1.  **Cadence Formula:**
    *   Base cadence is determined by age-specific metabolic thresholds.
    *   Cadence is adjusted downward for higher body mass (since moving more mass requires more energy at lower speeds).
    *   Formula: `Target = Base(Age) - Adjustment(Excess Weight)`.

2.  **Audio Engine:**
    *   Uses `audioplayers` with a "Stop-and-Play" strategy for rhythmic precision.
    *   Immediate user-triggered audio context priming for web compatibility.

3.  **State Management:**
    *   `flutter_riverpod` manages the global state, ensuring that changing user profile data (height/weight/age) triggers an immediate recalculation of all recommended targets.

## Recent Improvements (March 15, 2026)

### iOS Support & Deployment
*   **iOS Project Initialization:** Generated the `ios` directory and necessary configuration files using `flutter create --platforms=ios .`.
*   **Background Audio Support:** Configured `ios/Runner/Info.plist` with `UIBackgroundModes` set to `audio` to allow the cadence sounds to continue playing when the app is in the background or the screen is locked.
*   **App Branding:** Updated `CFBundleDisplayName` and `CFBundleName` in `Info.plist` to "StepWithMe".
*   **Dependency Update:** Updated `audioplayers` to `^6.6.0` to ensure compatibility with the latest iOS audio context requirements.

### Bug Fixes & Stabilization
*   **Audio Context Compatibility:** Resolved `audioplayers` v6.6.0 compilation errors by removing invalid `const` constructors for `AudioContext` and `AudioContextIOS`. Fixed parameter misalignment for `AudioContextAndroid`.
*   **Asset Management:** Simplified `pubspec.yaml` asset declaration by including the entire `assets/audio/` directory. Removed references to missing placeholder files like `step1.mp3`.
*   **Default State:** Updated `StateService` to use a valid default sound file (`walk_on_grass.mp3`) that matches the provided high-quality audio assets.
*   **Deprecated API Updates:** Refactored `withOpacity` to `withValues(alpha: ...)` to align with the latest Flutter 3.27+ standards and avoid precision loss.

### UI/UX & Code Quality
*   **Code Cleanup:** Removed unused helper methods (`_buildDropdownItem`) and resolved all linter warnings.
*   **Robust Initialization:** Improved `InitialPage` logic for consistent user profile checking.
*   **Sound Selection:** Enhanced the sound selector to dynamically map friendly labels to the new high-quality audio files.

## Git & Workflow Policy

*   All changes are pushed directly to the `master` branch.
*   The `blueprint.md` is updated alongside major logic or feature changes.
