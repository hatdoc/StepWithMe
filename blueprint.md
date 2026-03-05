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

## Git & Workflow Policy

*   All changes are pushed directly to the `master` branch.
*   The `blueprint.md` is updated alongside major logic or feature changes.
