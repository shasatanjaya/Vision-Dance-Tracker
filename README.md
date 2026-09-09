# 🕺 Vision Dance Tracker (MVP)

Dance Movement Detector is an interactive iOS app designed to help users learn and perfect their dance movements through AI-based body posture evaluation. This app acts as a "virtual coach".

## ✨ Core Features
- **Real-time Body Tracking:** Utilizes the Apple Vision Framework to track 19 joint points (Full Body Skeleton) from active video frames.
- **Smart Pose Validation:** Automatically calculates the degree of angles between joints using trigonometry to validate movement accuracy.
- **Coach vs. User Comparison:** A *Split Screen* (50/50) layout that plays a reference video (Coach) side-by-side with the user's video.
- **Instant Visual Feedback:** Reactive UI indicators (e.g., Green = Correct, Red = Incorrect) evaluated instantly based on the detected posture's *margin of error* (angle degree tolerance).

## 🛠 Tech Stack & Architecture
- **SwiftUI:** UI architecture (utilizing the MVVM pattern to separate the *View* and *Analyzer Logic*).
- **Apple Vision:** Uses `VNDetectHumanBodyPoseRequest` for *Machine Learning pose estimation*.
- **AVFoundation:** Extracts real-time video frames via `AVPlayerItemVideoOutput`.
- **QuartzCore:** Precisely synchronizes video frame extraction to match the screen's refresh rate (60 FPS) using `CADisplayLink`.

## 🚀 Progress (10-Day Act Phase - C04)
- [x] **Cycle 1: Core Logic & Static Image Validation** (Successfully extracted joint coordinates & established the absolute math logic for angle tolerance).
- [x] **Cycle 2: Real-time Video Processing** (Successfully extracted frames from AVPlayer to Vision smoothly without lag, and filtered multi-object detection to lock onto the Main Dancer).
- [x] **Cycle 3: Split-Screen Comparison** (Integrated the components into a dual comparison layout for the MVP).
