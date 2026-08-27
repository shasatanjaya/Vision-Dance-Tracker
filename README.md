# 🕺 Vision Dance Tracker (MVP)

Dance Movement Detector adalah aplikasi iOS interaktif yang dirancang untuk membantu pengguna mempelajari dan menyempurnakan gerakan tari dengan evaluasi postur tubuh berbasis AI. Aplikasi ini bertindak sebagai "pelatih virtual" layaknya sistem *Video Review* (VAR).

## ✨ Core Features
- **Real-time Body Tracking:** Memanfaatkan Apple Vision Framework untuk melacak 19 titik sendi (Full Body Skeleton) dari frame video yang sedang berjalan.
- **Smart Pose Validation:** Melakukan kalkulasi derajat sudut antar sendi secara otomatis menggunakan trigonometri untuk memvalidasi akurasi gerakan.
- **Coach vs. User Comparison:** Tampilan *Split Screen* (50/50) yang memutar video referensi (Coach) secara berdampingan dengan video pengguna.
- **Instant Visual Feedback:** Indikator UI yang reaktif (misal: Hijau = Benar, Merah = Salah) dievaluasi secara instan berdasarkan *margin of error* (toleransi derajat sudut) postur yang dideteksi.

## 🛠 Tech Stack & Architecture
- **SwiftUI:** Arsitektur UI (memanfaatkan pola MVVM untuk memisahkan *View* dan *Analyzer Logic*).
- **Apple Vision:** Menggunakan `VNDetectHumanBodyPoseRequest` untuk *Machine Learning pose estimation*.
- **AVFoundation:** Menarik frame video secara *real-time* via `AVPlayerItemVideoOutput`.
- **QuartzCore:** Sinkronisasi ekstraksi *frame* video secara presisi mengikuti *refresh rate* layar (60 FPS) menggunakan `CADisplayLink`.

## 🚀 Progres (10-Day Act Phase - C04)
- [x] **Cycle 1: Core Logic & Static Image Validation** (Berhasil melakukan ekstraksi koordinat sendi & logika matematika abs untuk toleransi sudut).
- [x] **Cycle 2: Real-time Video Processing** (Berhasil menarik *frame* dari AVPlayer ke Vision secara mulus tanpa *lag* serta memfilter deteksi multi-objek untuk mencari Penari Utama).
- [x] **Cycle 3: Split-Screen Comparison** (Menyatukan komponen menjadi *layout* komparasi ganda untuk MVP).
