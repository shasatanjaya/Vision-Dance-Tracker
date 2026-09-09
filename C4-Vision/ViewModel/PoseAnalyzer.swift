import SwiftUI
import Vision
import Combine
import AVFoundation
import QuartzCore

// MARK: - View Model Analisis Pose Tarian (PoseAnalyzer)
/// Kelas `PoseAnalyzer` bertindak sebagai pengolah data utama (View Model).
/// Memandu analisis pose statis (2 foto) maupun analisis video bergerak real-time (2 video).
class PoseAnalyzer: ObservableObject {
    
    // MARK: - Published Properties (Status State untuk UI)
    
    /// Menyimpan koordinat sendi-sendi tubuh Coach (0.0 - 1.0)
    @Published var coachJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    
    /// Menyimpan koordinat sendi-sendi tubuh User (0.0 - 1.0)
    @Published var userJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    
    /// Himpunan (Set) berisi nama bagian tubuh User yang posenya salah
    @Published var bagianSalah: Set<String> = []
    
    /// Batas toleransi selisih sudut per bagian tubuh (dalam derajat °).
    /// Dikalibrasi presisi dan ketat untuk tarian langsung mengacu pada Coach.
    @Published var toleransi: [String: Double] = [
        "Right Arm": 18.0,
        "Left Arm": 18.0,
        "Right Shoulder": 18.0,
        "Right Elbow": 18.0,
        "Right Forearm": 18.0,
        "Left Shoulder": 18.0,
        "Left Elbow": 18.0,
        "Left Forearm": 18.0,
        "Right Leg": 22.0,
        "Left Leg": 22.0,
        "Right Thigh": 22.0,
        "Left Thigh": 22.0,
        "Right Knee": 25.0,
        "Left Knee": 25.0,
        "Right Calf": 25.0,
        "Left Calf": 25.0,
        "Torso": 20.0,
        "Head": 22.0
    ]
    
    /// Status message shown in top banner
    @Published var teksStatusPose: String = "Analyzing dual poses..."
    
    /// Background color of status banner
    @Published var warnaStatus: Color = .gray
    
    // MARK: - Auto-Pause & Checkpoint State
    @Published var isPausedOnError: Bool = false
    @Published var pesanSpesifik: String = ""
    @Published var checkpoints: [Checkpoint] = []
    @Published var activeCheckpoint: Checkpoint? = nil
    
    private var lastCheckpointTime: Double = -5.0
    private var lastResumedTime: Double = 0.0
    private var isIgnoringErrorsUntilTime: Double = 0.0
    
    // MARK: - Smart Tolerance & Sustained Error Filter Tracking
    /// Menyimpan jumlah frame berturut-turut di mana suatu bagian tubuh terdeteksi salah
    private var errorFramesCount: [String: Int] = [:]
    /// Ambang batas frame salah berturut-turut sebelum Auto-Pause dipicu (6 frame ~ 0.1 detik)
    private let sustainedFramesThreshold: Int = 6
    /// Durasi masa tenggang setelah resume (Next) dalam detik (0.8 detik)
    private let gracePeriodDuration: Double = 0.8
    
    // MARK: - Pemutar Video Dual (Coach & User)
    @Published var coachPlayer = AVPlayer()
    @Published var userPlayer = AVPlayer()
    
    private var coachOutput: AVPlayerItemVideoOutput?
    private var userOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    private var urlCoach: URL?
    private var urlUser: URL?
    
    // Orientasi Track Video untuk Vision Handlers
    private var coachVideoOrientation: CGImagePropertyOrientation = .up
    private var userVideoOrientation: CGImagePropertyOrientation = .up
    
    // MARK: - 1. Memulai Pemutar Video Dual (Real-Time Video Comparison)
    
    /// Memulai pemutaran video menggunakan URL langsung (dari file lokal, galeri, rekaman kamera, atau bundle)
    func mulaiMemutarVideo(urlCoach: URL, urlUser: URL) {
        self.urlCoach = urlCoach
        self.urlUser = urlUser
        
        // Baca orientasi rotasi track video (preferredTransform) agar skeleton tidak miring pada rekaman iPad/iPhone
        self.muatOrientasiVideo(url: urlCoach) { [weak self] orient in
            self?.coachVideoOrientation = orient
        }
        self.muatOrientasiVideo(url: urlUser) { [weak self] orient in
            self?.userVideoOrientation = orient
        }
        
        let itemCoach = AVPlayerItem(url: urlCoach)
        let itemUser = AVPlayerItem(url: urlUser)
        
        let attributes = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        let outputCoach = AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
        let outputUser = AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
        
        itemCoach.add(outputCoach)
        itemUser.add(outputUser)
        
        self.coachOutput = outputCoach
        self.userOutput = outputUser
        
        self.coachPlayer.pause()
        self.userPlayer.pause()
        self.coachPlayer.replaceCurrentItem(with: itemCoach)
        self.userPlayer.replaceCurrentItem(with: itemUser)
        
        // Mute video User agar audio tidak bertumpuk/echo dengan video Coach
        self.userPlayer.isMuted = true
        self.coachPlayer.isMuted = false
        
        // Reset state
        self.checkpoints = []
        self.activeCheckpoint = nil
        self.isPausedOnError = false
        self.lastCheckpointTime = -5.0
        self.lastResumedTime = 0.0
        self.isIgnoringErrorsUntilTime = 0.0
        self.errorFramesCount.removeAll()
        
        // Setup DisplayLink Metronom (60 FPS)
        self.displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(tangkapFrame))
        link.add(to: .main, forMode: .common)
        self.displayLink = link
        
        self.putarSinkron(dariWaktu: .zero)
    }
    
    /// Overload praktis untuk memutar video berdasarkan nama resource di App Bundle
    func mulaiMemutarVideo(namaCoach: String, namaUser: String) {
        guard let urlCoach = Bundle.main.url(forResource: namaCoach, withExtension: "mp4"),
              let urlUser = Bundle.main.url(forResource: namaUser, withExtension: "mp4") else {
            print("Video tidak ditemukan di bundle")
            return
        }
        mulaiMemutarVideo(urlCoach: urlCoach, urlUser: urlUser)
    }
    
    /// Menghentikan pemutaran video dan membersihkan DisplayLink saat keluar layar
    func hentikanVideo() {
        self.displayLink?.invalidate()
        self.displayLink = nil
        self.coachPlayer.pause()
        self.userPlayer.pause()
        self.coachPlayer.replaceCurrentItem(with: nil)
        self.userPlayer.replaceCurrentItem(with: nil)
        self.coachOutput = nil
        self.userOutput = nil
    }
    
    // MARK: - 2. Navigasi & Control Video (Next, Replay, Jump)
    
    /// Memulai pemutaran kedua video secara sinkron dari frame yang sama persis
    private func putarSinkron(dariWaktu: CMTime) {
        self.coachPlayer.pause()
        self.userPlayer.pause()
        
        let group = DispatchGroup()
        
        group.enter()
        self.coachPlayer.seek(to: dariWaktu, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            group.leave()
        }
        
        group.enter()
        self.userPlayer.seek(to: dariWaktu, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self, !self.isPausedOnError else { return }
            self.coachPlayer.play()
            self.userPlayer.play()
        }
    }
    
    /// Menekan tombol "Next / Lanjutkan Tarian" setelah jeda kesalahan
    func lanjutkanVideo() {
        let currentTime = CMTimeGetSeconds(coachPlayer.currentTime())
        let validTime = currentTime.isNaN ? 0.0 : currentTime
        self.lastResumedTime = validTime
        self.isIgnoringErrorsUntilTime = validTime + gracePeriodDuration // Abaikan error selama masa tenggang
        self.errorFramesCount.removeAll() // Reset akumulasi frame kesalahan
        self.isPausedOnError = false
        self.activeCheckpoint = nil
        self.bagianSalah = []
        self.teksStatusPose = "▶️ Playing dance comparison..."
        self.warnaStatus = .green
        
        let currentCMTime = coachPlayer.currentTime()
        self.putarSinkron(dariWaktu: currentCMTime)
    }
    
    /// Melompat ke checkpoint tertentu saat pengguna menekan marker timeline
    func lompatKeCheckpoint(_ checkpoint: Checkpoint) {
        self.coachPlayer.pause()
        self.userPlayer.pause()
        
        let targetTime = checkpoint.timestamp
        self.coachPlayer.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        self.userPlayer.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        
        self.errorFramesCount.removeAll()
        self.isPausedOnError = true
        self.activeCheckpoint = checkpoint
        self.coachJoints = checkpoint.coachJoints
        self.userJoints = checkpoint.userJoints
        self.bagianSalah = checkpoint.bagianSalah
        self.pesanSpesifik = checkpoint.pesan
        self.teksStatusPose = "🛑 REFLECTION (\(checkpoint.timeFormatted)): Adjust \(Array(checkpoint.bagianSalah).joined(separator: ", "))"
        self.warnaStatus = .red
        
        // Ekstraksi ulang dari frame statis video secara presisi tinggi (Zero-Lag Frame Extraction)
        if let uCoach = self.urlCoach, let uUser = self.urlUser {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let exactCoach = self.ekstraksiPosePresisi(url: uCoach, at: targetTime)
                let exactUser = self.ekstraksiPosePresisi(url: uUser, at: targetTime)
                
                DispatchQueue.main.async {
                    if !exactCoach.isEmpty { self.coachJoints = exactCoach }
                    if !exactUser.isEmpty { self.userJoints = exactUser }
                }
            }
        }
    }
    
    /// Mereset dan memutar ulang kedua video dari awal
    func replayVideo() {
        self.lastResumedTime = 0.0
        self.isIgnoringErrorsUntilTime = 0.0
        self.errorFramesCount.removeAll()
        self.isPausedOnError = false
        self.activeCheckpoint = nil
        self.bagianSalah = []
        self.checkpoints = []
        self.lastCheckpointTime = -5.0
        self.teksStatusPose = "Analyzing dual poses..."
        self.warnaStatus = .gray
        
        self.putarSinkron(dariWaktu: .zero)
    }
    
    // Cache frame terakhir untuk mencegah frame-drop (30 FPS video pada 60 FPS DisplayLink)
    private var lastCoachSudut: [String: Double] = [:]
    private var lastCoachJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    private var lastUserJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    
    // MARK: - 3. Metronom Tangkap Frame 60 FPS & Auto-Pause Logic
    @objc private func tangkapFrame(link: CADisplayLink) {
        guard let cOutput = coachOutput, let cItem = coachPlayer.currentItem,
              let uOutput = userOutput, let uItem = userPlayer.currentItem else { return }
        
        let timeCoach = cOutput.itemTime(forHostTime: CACurrentMediaTime())
        let timeUser = uOutput.itemTime(forHostTime: CACurrentMediaTime())
        let currentTimeSeconds = CMTimeGetSeconds(timeCoach)
        
        // Jika sedang di-pause karena error, jangan re-evaluasi frame baru
        if isPausedOnError { return }
        
        // Koreksi Drift: Jika selisih waktu video User dan Coach > 0.05s, sinkronkan kembali
        let coachSeconds = CMTimeGetSeconds(timeCoach)
        let userSeconds = CMTimeGetSeconds(timeUser)
        if !coachSeconds.isNaN && !userSeconds.isNaN && abs(coachSeconds - userSeconds) > 0.05 {
            self.userPlayer.seek(to: timeCoach, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        
        var hasNewCoachFrame = false
        var hasNewUserFrame = false
        
        if cOutput.hasNewPixelBuffer(forItemTime: timeCoach),
           let cBuffer = cOutput.copyPixelBuffer(forItemTime: timeCoach, itemTimeForDisplay: nil) {
            let result = prosesSatuPixelBuffer(pixelBuffer: cBuffer, orientation: self.coachVideoOrientation)
            if !result.joints.isEmpty {
                self.lastCoachJoints = result.joints
                self.lastCoachSudut = result.sudut
                hasNewCoachFrame = true
            }
        }
        
        if uOutput.hasNewPixelBuffer(forItemTime: timeUser),
           let uBuffer = uOutput.copyPixelBuffer(forItemTime: timeUser, itemTimeForDisplay: nil) {
            let result = prosesSatuPixelBuffer(pixelBuffer: uBuffer, orientation: self.userVideoOrientation)
            if !result.joints.isEmpty {
                self.lastUserJoints = result.joints
                hasNewUserFrame = true
            }
        }
        
        // Jika belum ada frame dari salah satu video, lewati tick ini tanpa merusak state
        guard !lastCoachSudut.isEmpty && !lastUserJoints.isEmpty else { return }
        
        let currentCoachJoints = self.lastCoachJoints
        let currentUserJoints = self.lastUserJoints
        let currentCoachSudut = self.lastCoachSudut
        
        // Jika pengguna baru saja menekan tombol "Lanjutkan", abaikan error selama masa tenggang
        if currentTimeSeconds < isIgnoringErrorsUntilTime {
            self.errorFramesCount.removeAll()
            let smoothedCoach = smoothJoints(current: currentCoachJoints, previous: self.coachJoints, alpha: 0.7)
            let smoothedUser = smoothJoints(current: currentUserJoints, previous: self.userJoints, alpha: 0.7)
            DispatchQueue.main.async {
                self.coachJoints = smoothedCoach
                self.userJoints = smoothedUser
                self.bagianSalah = []
                self.teksStatusPose = "▶️ Playing dance comparison..."
                self.warnaStatus = .green
            }
            return
        }
        
        // Hanya lakukan evaluasi jika ada pembaruan frame baru
        guard hasNewCoachFrame || hasNewUserFrame else { return }
        
        // Evaluasi kesalahan per frame langsung mengacu penuh pada Coach (Direct Anatomical Reference)
        let dataUser = hitungSemuaSudut(extractedJoints: currentUserJoints)
        var frameErrors = Set<String>()
        let toleransiDict = self.toleransi
        let defaultToleransi: Double = 25.0
        
        for (namaBagian, sudutCoach) in currentCoachSudut {
            let kategori = mapToKategori(namaBagian)
            let batasToleransi = toleransiDict[kategori] ?? toleransiDict[namaBagian] ?? defaultToleransi
            
            if let sudutUser = dataUser[namaBagian] {
                let selisih = self.selisihSudut(sudutCoach, sudutUser)
                if selisih > batasToleransi {
                    frameErrors.insert(kategori)
                }
            }
        }
        
        // Pembaruan Time-Based Error Threshold (Sustained Error Tracking)
        for kategori in frameErrors {
            self.errorFramesCount[kategori, default: 0] += 1
        }
        
        // Turunkan akumulasi secara bertahap jika pose kembali akurat
        for kategori in Array(self.errorFramesCount.keys) {
            if !frameErrors.contains(kategori) {
                let current = self.errorFramesCount[kategori, default: 0]
                if current > 0 {
                    self.errorFramesCount[kategori] = max(0, current - 2)
                }
            }
        }
        
        // Ambil daftar bagian tubuh yang salah secara konsisten melebihi ambang batas frame
        var bagianSalahList: [String] = []
        for (kategori, count) in self.errorFramesCount {
            if count >= sustainedFramesThreshold {
                bagianSalahList.append(kategori)
            }
        }
        
        let smoothedCoach = smoothJoints(current: currentCoachJoints, previous: self.coachJoints, alpha: 0.7)
        let smoothedUser = smoothJoints(current: currentUserJoints, previous: self.userJoints, alpha: 0.7)
        
        // Logika Auto-Pause saat kesalahan berulang dan berkelanjutan terdeteksi (Sustained Error)
        if !bagianSalahList.isEmpty && !currentTimeSeconds.isNaN && currentTimeSeconds > 0.5 {
            let pesanUmpanBalik = buatPesanSpesifik(bagianSalah: bagianSalahList)
            
            // Jeda kedua player
            coachPlayer.pause()
            userPlayer.pause()
            
            // Kunci posisi kedua player pada frame timeCoach yang persis sama
            coachPlayer.seek(to: timeCoach, toleranceBefore: .zero, toleranceAfter: .zero)
            userPlayer.seek(to: timeCoach, toleranceBefore: .zero, toleranceAfter: .zero)
            
            // Reset frame error tracking saat pause agar tidak langsung pause berulang saat dilanjutkan
            self.errorFramesCount.removeAll()
            
            // Gunakan pose mentah (current) dari frame saat jeda daripada yang terdistorsi smoothing
            let newCheckpoint = Checkpoint(
                timestamp: timeCoach,
                timeInSeconds: currentTimeSeconds,
                timeFormatted: formatWaktu(seconds: currentTimeSeconds),
                bagianSalah: Set(bagianSalahList),
                pesan: pesanUmpanBalik,
                coachJoints: currentCoachJoints,
                userJoints: currentUserJoints
            )
            var currentCheckpoints = self.checkpoints
            currentCheckpoints.append(newCheckpoint)
            let finalActive = newCheckpoint
            let finalCheckpoints = currentCheckpoints
            let finalBagianSalah = Set(bagianSalahList)
            
            DispatchQueue.main.async {
                self.coachJoints = currentCoachJoints
                self.userJoints = currentUserJoints
                self.bagianSalah = finalBagianSalah
                self.isPausedOnError = true
                self.pesanSpesifik = pesanUmpanBalik
                self.checkpoints = finalCheckpoints
                self.activeCheckpoint = finalActive
                self.teksStatusPose = "🛑 AUTO-PAUSE: Adjust \(bagianSalahList.joined(separator: ", "))"
                self.warnaStatus = .red
            }
            
            // Ekstraksi presisi frame statis di background untuk memastikan 100% piksel akurat
            if let uCoach = self.urlCoach, let uUser = self.urlUser {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self = self else { return }
                    let exactCoach = self.ekstraksiPosePresisi(url: uCoach, at: timeCoach)
                    let exactUser = self.ekstraksiPosePresisi(url: uUser, at: timeCoach)
                    
                    DispatchQueue.main.async {
                        if !exactCoach.isEmpty { self.coachJoints = exactCoach }
                        if !exactUser.isEmpty { self.userJoints = exactUser }
                    }
                }
            }
            return
        }
        
        DispatchQueue.main.async {
            self.coachJoints = smoothedCoach
            self.userJoints = smoothedUser
            self.bagianSalah = Set(bagianSalahList)
            
            if currentCoachSudut.isEmpty || currentUserJoints.isEmpty {
                self.teksStatusPose = "⚠️ Pose tubuh tidak terdeteksi jelas."
                self.warnaStatus = .orange
            } else if bagianSalahList.isEmpty {
                self.teksStatusPose = "✅ BENAR! Gerakan akurat."
                self.warnaStatus = .green
            } else {
                self.teksStatusPose = "❌ SALAH! Perbaiki: \(bagianSalahList.joined(separator: ", "))"
                self.warnaStatus = .red
            }
        }
    }
    
    // MARK: - Helper Pembuatan Umpan Balik & Format Waktu
    private func buatPesanSpesifik(bagianSalah: [String]) -> String {
        guard !bagianSalah.isEmpty else { return "" }
        var saranList: [String] = []
        
        for bagian in bagianSalah {
            switch bagian {
            case "Right Arm":
                saranList.append("Raise your right arm higher or adjust your elbow angle!")
            case "Left Arm":
                saranList.append("Raise your left arm higher or adjust your elbow angle!")
            case "Right Leg":
                saranList.append("Adjust your right leg lift height or knee angle!")
            case "Left Leg":
                saranList.append("Adjust your left leg lift height or knee angle!")
            case "Torso":
                saranList.append("Keep your torso and posture upright!")
            case "Head":
                saranList.append("Adjust your head/neck tilt!")
            default:
                saranList.append("Adjust your \(bagian) position!")
            }
        }
        
        return saranList.joined(separator: " ")
    }
    
    private func formatWaktu(seconds: Double) -> String {
        let sec = Int(seconds) % 60
        let min = Int(seconds) / 60
        return String(format: "%02d:%02d", min, sec)
    }
    
    // MARK: - Helper Smoothing Koordinat Sendi (EMA Low-Pass Filter)
    private func smoothJoints(current: [VNHumanBodyPoseObservation.JointName: CGPoint], previous: [VNHumanBodyPoseObservation.JointName: CGPoint], alpha: CGFloat = 0.7) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        if previous.isEmpty { return current }
        var smoothed = current
        for (joint, newPt) in current {
            if let prevPt = previous[joint] {
                let smoothedX = prevPt.x + alpha * (newPt.x - prevPt.x)
                let smoothedY = prevPt.y + alpha * (newPt.y - prevPt.y)
                smoothed[joint] = CGPoint(x: smoothedX, y: smoothedY)
            }
        }
        return smoothed
    }
    
    // MARK: - Helper Pemetaan Kategori UI
    private func mapToKategori(_ namaBagian: String) -> String {
        switch namaBagian {
        case "Right Shoulder", "Right Elbow", "Right Forearm", "Right Arm", "Bahu Kanan", "Siku Kanan", "Lengan Bawah Kanan", "Lengan Kanan":
            return "Right Arm"
        case "Left Shoulder", "Left Elbow", "Left Forearm", "Left Arm", "Bahu Kiri", "Siku Kiri", "Lengan Bawah Kiri", "Lengan Kiri":
            return "Left Arm"
        case "Right Thigh", "Right Knee", "Right Calf", "Right Leg", "Paha Kanan", "Lutut Kanan", "Betis Kanan", "Kaki Kanan":
            return "Right Leg"
        case "Left Thigh", "Left Knee", "Left Calf", "Left Leg", "Paha Kiri", "Lutut Kiri", "Betis Kiri", "Kaki Kiri":
            return "Left Leg"
        case "Torso":
            return "Torso"
        case "Head", "Kepala":
            return "Head"
        default:
            return namaBagian
        }
    }
    
    // MARK: - 4. Ekstraksi Vision untuk 1 Frame CVPixelBuffer (Video)
    private func prosesSatuPixelBuffer(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation = .up) -> (joints: [VNHumanBodyPoseObservation.JointName: CGPoint], sudut: [String: Double]) {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        
        do {
            try handler.perform([request])
            guard let semuaOrang = request.results, !semuaOrang.isEmpty else { return ([:], [:]) }
            
            guard let observation = cariPenariUtama(semuaOrang: semuaOrang) ?? semuaOrang.first else { return ([:], [:]) }
            let recognizedPoints = try observation.recognizedPoints(.all)
            var extractedJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            
            for (jointName, point) in recognizedPoints where point.confidence > 0.35 {
                extractedJoints[jointName] = point.location
            }
            
            let kumpulanSudut = hitungSemuaSudut(extractedJoints: extractedJoints)
            return (extractedJoints, kumpulanSudut)
            
        } catch {
            print("Vision Error: \(error)")
            return ([:], [:])
        }
    }
    
    // MARK: - Filter Penari Utama (Tengah Frame, Terlengkap, & Confidence Tinggi)
    private func cariPenariUtama(semuaOrang: [VNHumanBodyPoseObservation]) -> VNHumanBodyPoseObservation? {
        var bestObservation: VNHumanBodyPoseObservation? = nil
        var bestScore: CGFloat = -1
        
        for orang in semuaOrang {
            guard let titik = try? orang.recognizedPoints(.all) else { continue }
            let validPoints = titik.values.filter { $0.confidence > 0.35 }
            guard validPoints.count >= 6 else { continue }
            
            let locations = validPoints.map { $0.location }
            let minX = locations.map { $0.x }.min() ?? 0
            let maxX = locations.map { $0.x }.max() ?? 0
            let minY = locations.map { $0.y }.min() ?? 0
            let maxY = locations.map { $0.y }.max() ?? 0
            
            let width = maxX - minX
            let height = maxY - minY
            let area = width * height
            
            // Prioritas penari yang berdiri paling dekat di tengah layar (x = 0.5)
            let centerX = (minX + maxX) / 2.0
            let centerDistance = abs(centerX - 0.5)
            let centerBonus = max(0.2, 1.0 - (centerDistance * 2.0))
            
            // Skor menggabungkan area, jumlah titik sendi terdeteksi, dan posisi tengah
            let score = area * CGFloat(validPoints.count) * centerBonus
            
            if score > bestScore {
                bestScore = score
                bestObservation = orang
            }
        }
        
        return bestObservation
    }
    
    // MARK: - Ekstraksi Pose Presisi dari Frame Video Statis (Zero-Lag Asset Extraction)
    func ekstraksiPosePresisi(url: URL, at time: CMTime) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            let request = VNDetectHumanBodyPoseRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            try handler.perform([request])
            
            guard let semuaOrang = request.results, !semuaOrang.isEmpty else { return [:] }
            guard let observation = cariPenariUtama(semuaOrang: semuaOrang) ?? semuaOrang.first else { return [:] }
            
            let recognizedPoints = try observation.recognizedPoints(.all)
            var extractedJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            
            for (jointName, point) in recognizedPoints where point.confidence > 0.35 {
                extractedJoints[jointName] = point.location
            }
            return extractedJoints
        } catch {
            return [:]
        }
    }
    
    // MARK: - Helper Deteksi Orientasi Track Video (PreferredTransform)
    private func muatOrientasiVideo(url: URL, completion: @escaping (CGImagePropertyOrientation) -> Void) {
        let asset = AVURLAsset(url: url)
        Task {
            do {
                let tracks = try await asset.loadTracks(withMediaType: .video)
                if let track = tracks.first {
                    let transform = try await track.load(.preferredTransform)
                    let orient = self.cgImageOrientation(from: transform)
                    await MainActor.run {
                        completion(orient)
                    }
                    return
                }
            } catch {
                print("Gagal membaca orientasi video: \(error.localizedDescription)")
            }
            await MainActor.run {
                completion(.up)
            }
        }
    }
    
    private func cgImageOrientation(from transform: CGAffineTransform) -> CGImagePropertyOrientation {
        let isMirrored = (transform.a * transform.d - transform.b * transform.c) < 0
        let angle = atan2(transform.b, transform.a)
        var degrees = angle * 180.0 / .pi
        if degrees < 0 { degrees += 360.0 }
        
        if abs(degrees - 90) < 45 {
            return isMirrored ? .leftMirrored : .right
        } else if abs(degrees - 180) < 45 {
            return isMirrored ? .upMirrored : .down
        } else if abs(degrees - 270) < 45 {
            return isMirrored ? .rightMirrored : .left
        } else {
            return isMirrored ? .downMirrored : .up
        }
    }
    
    // MARK: - 5. Analisis Foto Statis (2 Foto)
//    func bandingkanDuaFoto(coachImage: UIImage, userImage: UIImage) {
//        let dataCoach = prosesSatuFoto(image: coachImage)
//        let dataUser = prosesSatuFoto(image: userImage)
//        
//        DispatchQueue.main.async {
//            self.coachJoints = dataCoach.joints
//            self.userJoints = dataUser.joints
//            
//            var bagianSalahList: [String] = []
//            let toleransiDict = self.toleransi
//            let defaultToleransi: Double = 25.0
//            
//            for (namaBagian, sudutCoach) in dataCoach.sudut {
//                let kategori = self.mapToKategori(namaBagian)
//                let batasToleransi = toleransiDict[kategori] ?? toleransiDict[namaBagian] ?? defaultToleransi
//                
//                if let sudutUser = dataUser.sudut[namaBagian] {
//                    let selisih = self.selisihSudut(sudutCoach, sudutUser)
//                    if selisih > batasToleransi {
//                        if !bagianSalahList.contains(kategori) {
//                            bagianSalahList.append(kategori)
//                        }
//                    }
//                }
//            }
//            
//            self.bagianSalah = Set(bagianSalahList)
//            
//            if dataCoach.sudut.isEmpty || dataUser.joints.isEmpty {
//                self.teksStatusPose = "⚠️ Pose tubuh tidak terdeteksi jelas."
//                self.warnaStatus = .orange
//            } else if bagianSalahList.isEmpty {
//                self.teksStatusPose = "✅ BENAR! Semua pose akurat."
//                self.warnaStatus = .green
//            } else {
//                self.teksStatusPose = "❌ SALAH! Perbaiki: \(bagianSalahList.joined(separator: ", "))"
//                self.warnaStatus = .red
//            }
//        }
//    }
//    
//    // MARK: - 6. Ekstraksi Vision untuk 1 Foto Statis
//    private func prosesSatuFoto(image: UIImage) -> (joints: [VNHumanBodyPoseObservation.JointName: CGPoint], sudut: [String: Double]) {
//        guard let cgImage = image.cgImage else { return ([:], [:]) }
//        
//        let request = VNDetectHumanBodyPoseRequest()
//        let orientation = CGImagePropertyOrientation(image.imageOrientation)
//        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
//        
//        do {
//            try handler.perform([request])
//            guard let observation = request.results?.first else { return ([:], [:]) }
//            
//            let recognizedPoints = try observation.recognizedPoints(.all)
//            var extractedJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
//            
//            for (jointName, point) in recognizedPoints where point.confidence > 0.2 {
//                extractedJoints[jointName] = point.location
//            }
//            
//            let kumpulanSudut = hitungSemuaSudut(extractedJoints: extractedJoints)
//            return (extractedJoints, kumpulanSudut)
//            
//        } catch {
//            print("Vision Error: \(error)")
//            return ([:], [:])
//        }
//    }
    
    // MARK: - 7. Helper Ekstraksi Arah Segmen & Sudut Sendi Tubuh
    private func hitungSemuaSudut(extractedJoints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> [String: Double] {
        var kumpulanSudut: [String: Double] = [:]
        
        // Lengan Kanan (Arah Lengan Atas, Arah Lengan Bawah, Tekukan Siku)
        if let s = extractedJoints[.rightShoulder], let e = extractedJoints[.rightElbow] {
            kumpulanSudut["Bahu Kanan"] = hitungArahSegmen(dari: s, ke: e)
        }
        if let e = extractedJoints[.rightElbow], let w = extractedJoints[.rightWrist] {
            kumpulanSudut["Lengan Bawah Kanan"] = hitungArahSegmen(dari: e, ke: w)
        }
        if let s = extractedJoints[.rightShoulder], let e = extractedJoints[.rightElbow], let w = extractedJoints[.rightWrist] {
            kumpulanSudut["Siku Kanan"] = hitungSudutSendi(pointA: s, pointB: e, pointC: w)
        }
        
        // Lengan Kiri (Arah Lengan Atas, Arah Lengan Bawah, Tekukan Siku)
        if let s = extractedJoints[.leftShoulder], let e = extractedJoints[.leftElbow] {
            kumpulanSudut["Bahu Kiri"] = hitungArahSegmen(dari: s, ke: e)
        }
        if let e = extractedJoints[.leftElbow], let w = extractedJoints[.leftWrist] {
            kumpulanSudut["Lengan Bawah Kiri"] = hitungArahSegmen(dari: e, ke: w)
        }
        if let s = extractedJoints[.leftShoulder], let e = extractedJoints[.leftElbow], let w = extractedJoints[.leftWrist] {
            kumpulanSudut["Siku Kiri"] = hitungSudutSendi(pointA: s, pointB: e, pointC: w)
        }
        
        // Kaki Kanan (Arah Paha, Arah Betis, Tekukan Lutut)
        if let h = extractedJoints[.rightHip], let k = extractedJoints[.rightKnee] {
            kumpulanSudut["Paha Kanan"] = hitungArahSegmen(dari: h, ke: k)
        }
        if let k = extractedJoints[.rightKnee], let a = extractedJoints[.rightAnkle] {
            kumpulanSudut["Betis Kanan"] = hitungArahSegmen(dari: k, ke: a)
        }
        if let h = extractedJoints[.rightHip], let k = extractedJoints[.rightKnee], let a = extractedJoints[.rightAnkle] {
            kumpulanSudut["Lutut Kanan"] = hitungSudutSendi(pointA: h, pointB: k, pointC: a)
        }
        
        // Kaki Kiri (Arah Paha, Arah Betis, Tekukan Lutut)
        if let h = extractedJoints[.leftHip], let k = extractedJoints[.leftKnee] {
            kumpulanSudut["Paha Kiri"] = hitungArahSegmen(dari: h, ke: k)
        }
        if let k = extractedJoints[.leftKnee], let a = extractedJoints[.leftAnkle] {
            kumpulanSudut["Betis Kiri"] = hitungArahSegmen(dari: k, ke: a)
        }
        if let h = extractedJoints[.leftHip], let k = extractedJoints[.leftKnee], let a = extractedJoints[.leftAnkle] {
            kumpulanSudut["Lutut Kiri"] = hitungSudutSendi(pointA: h, pointB: k, pointC: a)
        }
        
        // Torso & Kepala
        if let r = extractedJoints[.root], let n = extractedJoints[.neck] {
            kumpulanSudut["Torso"] = hitungArahSegmen(dari: r, ke: n)
        }
        if let n = extractedJoints[.neck], let h = extractedJoints[.nose] {
            kumpulanSudut["Kepala"] = hitungArahSegmen(dari: n, ke: h)
        }
        
        return kumpulanSudut
    }
    
    // MARK: - 8. Rumus Trigonometri Vektor 2D
    
    /// Menghitung arah orientasi sudut (0.0° - 360.0°) dari titik awal ke titik akhir segmen
    private func hitungArahSegmen(dari p1: CGPoint, ke p2: CGPoint) -> Double {
        let dx = Double(p2.x - p1.x)
        let dy = Double(p2.y - p1.y)
        let radians = atan2(dy, dx)
        var degrees = radians * 180.0 / .pi
        if degrees < 0 { degrees += 360.0 }
        return degrees
    }
    
    /// Menghitung sudut tekukan sendi anatomis (0.0° - 180.0°) antara segmen BA dan BC
    private func hitungSudutSendi(pointA: CGPoint, pointB: CGPoint, pointC: CGPoint) -> Double {
        let v1x = Double(pointA.x - pointB.x)
        let v1y = Double(pointA.y - pointB.y)
        
        let v2x = Double(pointC.x - pointB.x)
        let v2y = Double(pointC.y - pointB.y)
        
        let dot = (v1x * v2x) + (v1y * v2y)
        let mag1 = sqrt(v1x * v1x + v1y * v1y)
        let mag2 = sqrt(v2x * v2x + v2y * v2y)
        
        guard mag1 > 0.0001 && mag2 > 0.0001 else { return 0.0 }
        
        let cosTheta = max(-1.0, min(1.0, dot / (mag1 * mag2)))
        let radians = acos(cosTheta)
        let degrees = radians * 180.0 / .pi
        
        return degrees
    }
    
    /// Menghitung jarak selisih sudut terpendek (0.0° - 180.0°) antara dua sudut di ruang 360°
    func selisihSudut(_ a1: Double, _ a2: Double) -> Double {
        let diff = abs(a1 - a2).truncatingRemainder(dividingBy: 360.0)
        return diff > 180.0 ? (360.0 - diff) : diff
    }
}

// MARK: - Helper Konversi Orientasi Gambar
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
