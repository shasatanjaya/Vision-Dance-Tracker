//
//  PoseAnalyzer.swift
//  C4-Vision
//
//  Created by Sharon Tan on 26/08/26.
//

import SwiftUI
import Vision
import Combine
import AVFoundation //Video
import QuartzCore //Rendering

/// Kelas `PoseAnalyzer` bertanggung jawab untuk mendeteksi pose tubuh manusia dari gambar menggunakan framework Apple Vision (`VNDetectHumanBodyPoseRequest`),
/// menghitung sudut sendi (seperti siku/lengan kanan), serta memberikan umpan balik (feedback) status ke antarmuka pengguna (UI SwiftUI).

/// Menggunakan protokol `ObservableObject` sehingga perubahan pada properti `@Published` akan secara otomatis memicu pembaruan tampilan di UI.
class PoseAnalyzer: ObservableObject {
    
    // MARK: - Published Properties (State UI)
    
    /// Menyimpan koordinat ter-normalisasi (0.0 - 1.0) dari titik-titik sendi tubuh yang berhasil dideteksi.
    /// Kunci: `JointName` (misal: `.rightShoulder`, `.rightElbow`, `.rightWrist`).
    /// Nilai: `CGPoint` posisi sendi pada sistem koordinat Vision.
    @Published var detectedJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    
    /// Teks pesan status yang akan ditampilkan di UI (misal: "✅ BENAR!", "❌ SALAH!", atau "Menganalisis Pose...").
    @Published var teksStatusPose: String = "Menunggu Video..."
    
    /// Warna indikator status untuk UI (misal: `.green` jika sesuai target, `.red` jika di luar toleransi, `.orange` jika tidak terlihat).
    @Published var warnaStatus: Color = .gray
    
    @Published var player = AVPlayer()
    private var videoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    
    // MARK: - Setup Video (CYCLE 2)
    func mulaiMemutarVideo(namaFile: String) {
        guard let url = Bundle.main.url(forResource: namaFile, withExtension: "mp4") else {
            print("Video tidak ditemukan")
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        
        // 1. Setup Sang Penjepret (AVPlayerItemVideoOutput)
        // Kita atur format gambarnya menjadi BGRA agar mudah dibaca Vision
        let attributes = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
        playerItem.add(output)
        self.videoOutput = output
        
        self.player.replaceCurrentItem(with: playerItem)
        
        // 2. Setup Sang Metronom (CADisplayLink)
        self.displayLink = CADisplayLink(target: self, selector: #selector(tangkapFrame))
        self.displayLink?.add(to: .main, forMode: .common)
        
        self.player.play()
    }
    
    // MARK: - Replay Video
    func replayVideo() {
        player.seek(to: .zero)
        player.play()
    }
    
    // Fungsi ini akan dipanggil 60 kali per detik oleh Metronom
    @objc private func tangkapFrame(link: CADisplayLink) {
        guard let output = videoOutput, let item = player.currentItem else { return }
        
        // Cek waktu video saat ini
        let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
        
        // Jika ada frame gambar baru di waktu tersebut
        if output.hasNewPixelBuffer(forItemTime: itemTime) {
            // Ambil gambar mentahnya (disebut CVPixelBuffer)
            if let pixelBuffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
                
                // INI ADALAH JEMBATANNYA!
                // Kita kirim gambar mentah dari video ke fungsi Vision yang sudah kamu buat
                prosesFrameDenganVision(pixelBuffer: pixelBuffer)
            }
        }
    }
    
    // MARK: - Rumus Sudut Matematika
    
    /// Menghitung sudut dalam derajat (°) antara tiga titik lokasi sendi (`pointA`, `pointB`, `pointC`),
    /// dengan `pointB` sebagai vertex/titik pusat sudut (misal: Siku sebagai pusat antara Bahu dan Pergelangan Tangan).
    ///
    /// - Parameters:
    ///   - pointA: Titik ujung pertama (misal: Bahu).
    ///   - pointB: Titik vertex / sudut pusat (misal: Siku).
    ///   - pointC: Titik ujung kedua (misal: Pergelangan Tangan).
    /// - Returns: Besar sudut dalam satuan derajat (0.0° hingga 180.0°).
    func hitungSudut(pointA: CGPoint, pointB: CGPoint, pointC: CGPoint) -> Double {
        // Hitung sudut atan2 dari dua vektor relatif terhadap titik pusat (pointB)
        let radians = atan2(pointC.y - pointB.y, pointC.x - pointB.x) -
        atan2(pointA.y - pointB.y, pointA.x - pointB.x)
        
        // Konversi dari Radian ke Derajat
        var degrees = radians * 180.0 / .pi
        
        // Normalisasi agar nilai derajat selalu positif (0 - 360)
        if degrees < 0 { degrees += 360.0 }
        
        // Mengubah sudut menjadi rentang sudut dalam (0 - 180 derajat)
        if degrees > 180.0 { degrees = 360.0 - degrees }
        
        return degrees
    }
    
    // MARK: - Logika Apple Vision & Validasi Pose
    
    /// Memproses `UIImage` untuk mendeteksi pose tubuh manusia, mengukur sudut lengan kanan,
    /// dan membandingkan hasil pengukuran dengan target pose yang ditentukan.
    ///
    /// - Parameter image: Gambar `UIImage` yang akan dianalisis.
    // MARK: - Logika Apple Vision (CYCLE 2 & FULL BODY)
    func prosesFrameDenganVision(pixelBuffer: CVPixelBuffer) {
        let request = VNDetectHumanBodyPoseRequest()
        
        // Orientasi .up karena videomu tegak lurus (berdasarkan temuan sebelumnya)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        do {
            
            try handler.perform([request])
            
            // 1. Ambil semua orang yang terdeteksi
            guard let semuaOrang = request.results, !semuaOrang.isEmpty else { return }
            
            // 2. Variabel untuk menyimpan "Si Penari Utama"
            var mainObservation: VNHumanBodyPoseObservation? = nil
            var ukuranTerbesar: CGFloat = 0
            
            // 3. Looping untuk mengukur siapa yang paling besar di layar
            for orang in semuaOrang {
                let titik = try? orang.recognizedPoints(.all)
                // Ambil koordinat titik yang valid saja
                let lokasi = titik?.values.compactMap { $0.confidence > 0.3 ? $0.location : nil } ?? []
                
                if !lokasi.isEmpty {
                    // Cari batas kiri-kanan dan atas-bawah dari titik-titik orang ini
                    let minX = lokasi.map { $0.x }.min() ?? 0
                    let maxX = lokasi.map { $0.x }.max() ?? 0
                    let minY = lokasi.map { $0.y }.min() ?? 0
                    let maxY = lokasi.map { $0.y }.max() ?? 0
                    
                    // Hitung luas area kerangkanya (Lebar x Tinggi)
                    let area = (maxX - minX) * (maxY - minY)
                    
                    // Jika area orang ini lebih besar dari yang sebelumnya, jadikan dia Penari Utama
                    if area > ukuranTerbesar {
                        ukuranTerbesar = area
                        mainObservation = orang
                    }
                }
            }
            
            // 4. Lanjutkan kode yang lama, HANYA menggunakan Si Penari Utama
            guard let observation = mainObservation else { return }
            let recognizedPoints = try observation.recognizedPoints(.all)

            var tempJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            
            // LOOPING: Simpan semua titik tubuh (Kepala sampai kaki)
            for (jointName, point) in recognizedPoints {
                // Hanya ambil titik yang AI yakin di atas 30%
                if point.confidence > 0.3 {
                    tempJoints[jointName] = point.location
                }
            }
            
            // 2. Hitung Sudut Siku Kanan (Untuk Validasi MVP)
            var teksBaru = "Lengan Kanan Tidak Terlihat"
            var warnaBaru = Color.gray
            
            // Cek apakah bahu, siku, dan pergelangan kanan berhasil ditemukan di frame ini
            if let bahu = tempJoints[.rightShoulder],
               let siku = tempJoints[.rightElbow],
               let pergelangan = tempJoints[.rightWrist] {
                
                // Panggil fungsi hitung trigonometri
                let sudut = hitungSudut(pointA: bahu, pointB: siku, pointC: pergelangan)
                
                // Logika Benar/Salah (Target: 90 derajat, Toleransi: 30 derajat)
                if abs(sudut - 90.0) <= 30.0 {
                    teksBaru = "✅ BENAR! Sudut: \(Int(sudut))°"
                    warnaBaru = .green
                } else {
                    teksBaru = "❌ SALAH! Sudut: \(Int(sudut))°"
                    warnaBaru = .red
                }
            }
            
            // 3. Lempar Semua Hasil ke UI di Main Thread
            DispatchQueue.main.async {
                self.detectedJoints = tempJoints // Kirim data full body untuk digambar
                self.teksStatusPose = teksBaru   // Update teks Benar/Salah
                self.warnaStatus = warnaBaru     // Update warna background teks
            }
            
        } catch {
            print("Gagal memproses Vision: \(error.localizedDescription)")
        }
    }
}

// MARK: - Helper Konversi Orientasi
/// Ekstensi untuk mengonversi `UIImage.Orientation` milik UIKit
/// menjadi `CGImagePropertyOrientation` yang dibutuhkan oleh Vision Framework.
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

