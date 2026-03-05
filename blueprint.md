# StepWithMe Blueprint

## Overview

StepWithMe is a mobile application designed to help users maintain a consistent walking pace by playing step sounds at a customizable speed. The app will feature a simple and modern interface, allowing users to select their preferred step sound and adjust the beats per minute (BPM). A key feature is the ability for the app to continue playing the sounds in the background, ensuring an uninterrupted experience.

## Features

*   **Customizable BPM:** Users can set their desired walking pace in beats per minute using a sleek circular slider.
*   **Clarified Sound Selection:** Step sounds are clearly labeled (e.g., "Heel Strike", "Soft Sneaker") to make their purpose obvious to the user.
*   **Sound Preview:** Selecting a sound automatically plays a short preview, helping users choose the best fit.
*   **Expanded Sound Library:** A variety of step sounds, including "Wood Block," "Mechanical Click," and "Electronic Pulse."
*   **Stable Background Playback:** Refined timer logic ensures the selected sound continues to play at the correct BPM without interruption or unintended resets during app interaction.
*   **Modern UI:** A clean, intuitive interface with support for light and dark modes, utilizing Google Fonts and custom Material 3 themes.

## Implementation Plan

1.  **Dependencies:**
    *   `audioplayers` for audio playback.
    *   `flutter_riverpod` for state management and reactive updates.
    *   `shared_preferences` to persist user settings (BPM, selected sound, user info).
    *   `sleek_circular_slider` for an interactive BPM control.
    *   `google_fonts` for polished typography.

2.  **UI/UX:**
    *   **Home Screen:** Features a large, interactive circular slider for BPM, a prominent Play/Pause button, and a dedicated "Step Sound Effect" card with a labeled dropdown.
    *   **User Info Page:** Collects initial height and weight data to personalize the experience.
    *   **Theme Support:** Seamless switching between light and dark modes.

3.  **Audio & BPM Service:**
    *   **Audio Service:** Manages low-latency playback of selected assets using `audioplayers`.
    *   **BPM Service:** Utilizes high-precision timers to trigger sound events based on the user's BPM setting. Logic is optimized to prevent timer resets on UI rebuilds.

4.  **State Management:**
    *   Riverpod `StateNotifier` manages the global application state (BPM, play/pause, sound selection).
    *   `ref.listen` is used to reactively start/stop services based on state changes, ensuring side effects are handled cleanly.

5.  **Asset Management:**
    *   A curated set of step sounds (`.mp3`) stored in `assets/audio/`.
