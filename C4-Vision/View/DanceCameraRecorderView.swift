//
//  DanceCameraRecorderView.swift
//  C4-Vision
//
//  Created by Sharon Tan on 02/09/26.
//

import SwiftUI
import AVFoundation
import AVKit
import Combine

// MARK: - View Perekam Tarian Kamera (DanceCameraRecorderView)
/// Layar perekaman tarian kamera penuh (Full-Screen Camera Recorder) yang dilengkapi dengan:
/// 1. **Live Camera Feed**: Feed visual kamera depan / belakang dengan orientasi otomatis.
/// 2. **Audio & Video Coach Sinkron**: Memutar musik dan video panduan Coach secara bersamaan saat perekaman dimulai.
/// 3. **Resizable & Draggable Coach PiP Overlay**: Video coach mengambang yang ukurannya bisa diubah (S, M, L, XL, atau drag pinch handle) dan bisa digeser ke posisi mana pun di layar.
/// 4. **Countdown Timer (3.. 2.. 1..)**: Memberikan jeda waktu persiapan sebelum musik dan kamera mulai merekam.
/// 5. **Layar Pratinjau & Review**: Memungkinkan pengguna melihat ulang hasil tarian (Review) sebelum memutuskan untuk menggunakan video (Use Video) atau mengulang rekaman (Retake).
struct DanceCameraRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    
    /// URL video Coach yang menjadi acuan musik & gerakan tarian
    let coachURL: URL
    
    /// Callback saat video pengguna selesai direkam dan dikonfirmasi
    var onVideoRecorded: (URL) -> Void
    
    /// Manager pengontrol AVCaptureSession kamera
    @StateObject private var camera = CameraManager()
    
    /// Pemutar audio/video referensi Coach
    @State private var coachPlayer: AVPlayer? = nil
    
    // MARK: - State Tampilan & Hitung Mundur
    @State private var countdown: Int = 0
    @State private var isCountingDown: Bool = false
    @State private var showCoachOverlay: Bool = true
    @State private var recordedVideoURL: URL? = nil
    @State private var isReviewingVideo: Bool = false
    @State private var previewPlayer: AVPlayer? = nil
    
    // MARK: - State Overlay Video Coach (Resizable & Draggable PiP)
    @State private var coachOverlayWidth: CGFloat = 160.0
    @State private var lastOverlayWidth: CGFloat = 160.0
    @State private var overlayPosition: CGSize = .zero
    @State private var dragTranslation: CGSize = .zero
    
    // MARK: - Timer Durasi Perekaman
    @State private var timer: Timer? = nil
    @State private var recordingDuration: Double = 0.0
    @State private var totalCoachDuration: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isReviewingVideo, let url = recordedVideoURL, let player = previewPlayer {
                // MARK: - Layar 1: Pratinjau Hasil Rekaman (Review Screen)
                tampilanReviewHasilRekaman(player: player)
            } else {
                // MARK: - Layar 2: Perekaman Kamera Live & Panduan Coach (Live Recording)
                tampilanPerekamanKameraUtama
            }
        }
        .onAppear {
            setupCoachPlayer()
            camera.checkPermissionsAndStart()
        }
        .onDisappear {
            stopCoachPlayer()
            camera.stopSession()
            timer?.invalidate()
        }
    }
    
    // MARK: - Subview: Layar Review Video
    @ViewBuilder
    private func tampilanReviewHasilRekaman(player: AVPlayer) -> some View {
        ZStack {
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .onAppear {
                    player.play()
                }
            
            VStack {
                // Header Bar (Retake vs Use Video)
                HStack {
                    // Tombol Ulangi Rekaman (Retake)
                    Button(action: resetToRecordAgain) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Retake")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Tombol Konfirmasi Pakai Video (Use Video)
                    Button(action: konfirmasiVideo) {
                        HStack(spacing: 4) {
                            Text("Use Video")
                            Image(systemName: "checkmark")
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.blue)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Subview: Layar Live Kamera & PiP
    @ViewBuilder
    private var tampilanPerekamanKameraUtama: some View {
        ZStack {
            // 1. Feed Kamera Live Native
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()
            
            // 2. Layar Hitung Mundur Persiapan (3.. 2.. 1..)
            if isCountingDown {
                Color.black.opacity(0.4).ignoresSafeArea()
                
                Text("\(countdown)")
                    .font(.system(size: 110, weight: .heavy, design: .rounded))
                    .foregroundColor(.yellow)
                    .shadow(color: .black.opacity(0.8), radius: 10)
                    .scaleEffect(isCountingDown ? 1.0 : 0.4)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: countdown)
            }
            
            // 3. Mini Video Overlay Coach (Resizable & Draggable PiP Guide)
            if showCoachOverlay, let cPlayer = coachPlayer {
                resizableCoachOverlay(player: cPlayer)
            }
            
            // 4. Tombol Kontrol Kamera & Status Header
            VStack {
                // Top Header Bar
                HStack {
                    // Tombol Tutup / Kembali
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.9), .black.opacity(0.3))
                    }
                    
                    Spacer()
                    
                    // Indikator Durasi Perekaman (Merah)
                    if camera.isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                            
                            Text("\(formatWaktu(recordingDuration)) / \(formatWaktu(totalCoachDuration))")
                                .font(.subheadline.monospacedDigit().weight(.bold))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Tombol Munculkan Kembali PiP jika sedang disembunyikan
                    if !showCoachOverlay {
                        Button(action: { withAnimation { showCoachOverlay = true } }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pip.enter")
                                Text("Show Coach")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                    }
                    
                    // Tombol Ganti Kamera Depan / Belakang
                    Button(action: { camera.switchCamera() }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .disabled(camera.isRecording || isCountingDown)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Bottom Action Controls: Tombol Rekam Utama
                HStack {
                    Spacer()
                    
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 78, height: 78)
                            
                            if camera.isRecording {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red)
                                    .frame(width: 32, height: 32)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 66, height: 66)
                            }
                        }
                    }
                    .disabled(isCountingDown)
                    
                    Spacer()
                }
                .padding(.bottom, 36)
            }
        }
    }
    
    // MARK: - Komponen Resizable & Draggable Coach Overlay (PiP)
    @ViewBuilder
    private func resizableCoachOverlay(player: AVPlayer) -> some View {
        let height = coachOverlayWidth * (16.0 / 9.0)
        
        VStack(alignment: .trailing, spacing: 4) {
            // Header Mini Bar: Preset Ukuran Cepat & Tombol Sembunyikan
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    ukuranButton(label: "S", width: 120)
                    ukuranButton(label: "M", width: 170)
                    ukuranButton(label: "L", width: 240)
                    ukuranButton(label: "XL", width: 320)
                }
                .padding(2)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                
                Spacer()
                
                // Tombol Sembunyikan PiP
                Button(action: { withAnimation { showCoachOverlay = false } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .frame(width: coachOverlayWidth)
            
            // Kontainer Video Coach dengan Handle Resize
            ZStack(alignment: .bottomLeading) {
                VideoPlayer(player: player)
                    .disabled(true)
                    .frame(width: coachOverlayWidth, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.85), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
                
                // Badge Label Status "Reference Video"
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(camera.isRecording ? Color.red : Color.green)
                                .frame(width: 6, height: 6)
                            Text("Reference Video")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(6)
                    }
                    Spacer()
                }
                .frame(width: coachOverlayWidth, height: height)
                
                // Tombol Handle Resize (Dapat diketuk atau di-drag)
                Button(action: cycleCoachSize) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.85))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.4), radius: 4)
                        
                        Image(systemName: coachOverlayWidth > 260 ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(10)
                .highPriorityGesture(
                    DragGesture()
                        .onChanged { val in
                            let delta = -val.translation.width
                            let targetWidth = lastOverlayWidth + delta
                            coachOverlayWidth = min(max(targetWidth, 120), 380)
                        }
                        .onEnded { _ in
                            lastOverlayWidth = coachOverlayWidth
                        }
                )
            }
        }
        // Posisi yang dapat digeser bebas ke mana saja di layar (Draggable)
        .offset(
            x: overlayPosition.width + dragTranslation.width,
            y: overlayPosition.height + dragTranslation.height
        )
        .gesture(
            DragGesture()
                .onChanged { val in
                    dragTranslation = val.translation
                }
                .onEnded { val in
                    overlayPosition.width += val.translation.width
                    overlayPosition.height += val.translation.height
                    dragTranslation = .zero
                }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.trailing, 20)
        .padding(.top, 64)
    }
    
    // MARK: - Logika Resize & Preset Ukuran PiP
    
    /// Mengubah siklus ukuran PiP saat tombol handle pembesar diketuk
    private func cycleCoachSize() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            if coachOverlayWidth < 150 {
                coachOverlayWidth = 220
            } else if coachOverlayWidth < 250 {
                coachOverlayWidth = 300
            } else if coachOverlayWidth < 340 {
                coachOverlayWidth = 370
            } else {
                coachOverlayWidth = 130
            }
            lastOverlayWidth = coachOverlayWidth
        }
    }
    
    @ViewBuilder
    private func ukuranButton(label: String, width: CGFloat) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                coachOverlayWidth = width
                lastOverlayWidth = width
            }
        }) {
            Text(label)
                .font(.system(size: 9, weight: abs(coachOverlayWidth - width) < 15 ? .heavy : .medium))
                .foregroundColor(abs(coachOverlayWidth - width) < 15 ? .yellow : .white)
                .padding(.vertical, 2)
                .padding(.horizontal, 5)
                .background(abs(coachOverlayWidth - width) < 15 ? Color.white.opacity(0.25) : Color.clear)
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Setup Player Audio/Video Coach
    
    private func setupCoachPlayer() {
        let player = AVPlayer(url: coachURL)
        player.isMuted = false
        self.coachPlayer = player
        
        Task {
            let asset = AVURLAsset(url: coachURL)
            if let dur = try? await asset.load(.duration) {
                let sec = CMTimeGetSeconds(dur)
                await MainActor.run {
                    self.totalCoachDuration = sec.isNaN ? 0 : sec
                }
            }
        }
        
        // Setup Audio Session agar musik Coach berbunyi kencang di speaker saat merekam
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Gagal setting AVAudioSession: \(error.localizedDescription)")
        }
        
        // Auto-stop saat video coach selesai diputar
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            if self.camera.isRecording {
                self.stopRecording()
            }
        }
    }
    
    private func stopCoachPlayer() {
        coachPlayer?.pause()
        coachPlayer = nil
    }
    
    // MARK: - Logika Countdown & Recording
    
    private func toggleRecording() {
        if camera.isRecording {
            stopRecording()
        } else {
            startCountdownAndRecord()
        }
    }
    
    private func startCountdownAndRecord() {
        isCountingDown = true
        countdown = 3
        
        // Hitung mundur 3.. 2.. 1..
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { cdTimer in
            if self.countdown > 1 {
                self.countdown -= 1
            } else {
                cdTimer.invalidate()
                self.isCountingDown = false
                self.startRecordingNow()
            }
        }
    }
    
    private func startRecordingNow() {
        // Mulai putar video & musik coach dari awal
        coachPlayer?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        coachPlayer?.play()
        
        // Mulai rekam kamera
        camera.startRecording { outputURL in
            DispatchQueue.main.async {
                if let url = outputURL {
                    self.recordedVideoURL = url
                    self.previewPlayer = AVPlayer(url: url)
                    self.isReviewingVideo = true
                }
            }
        }
        
        // Timer durasi rekaman
        recordingDuration = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.recordingDuration += 0.1
        }
    }
    
    private func stopRecording() {
        coachPlayer?.pause()
        timer?.invalidate()
        camera.stopRecording()
    }
    
    private func resetToRecordAgain() {
        previewPlayer?.pause()
        previewPlayer = nil
        recordedVideoURL = nil
        isReviewingVideo = false
        recordingDuration = 0
        coachPlayer?.seek(to: .zero)
    }
    
    private func konfirmasiVideo() {
        previewPlayer?.pause()
        if let url = recordedVideoURL {
            onVideoRecorded(url)
        }
        dismiss()
    }
    
    private func formatWaktu(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
