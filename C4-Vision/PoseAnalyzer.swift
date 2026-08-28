//
//  PoseAnalyzer.swift
//  C4-Vision
//
//  Created by Sharon Tan on 26/08/26.
//

import SwiftUI
import Vision
import Combine

/// Kelas `PoseAnalyzer` bertindak sebagai pengolah data utama (View Model).
/// Tugasnya:
/// 1. Menerima gambar Coach & User.
/// 2. Mendeteksi titik-titik sendi tubuh menggunakan framework Apple Vision (`VNDetectHumanBodyPoseRequest`).
/// 3. Menghitung sudut tiap sendi (Lengan, Bahu, Paha, Lutut, Betis, Torso, Kepala).
/// 4. Membandingkan sudut pose Coach vs User dan menandai bagian tubuh mana yang salah.
class PoseAnalyzer: ObservableObject {
    
    // MARK: - Published Properties (Status State untuk UI)
    
    /// Menyimpan koordinat sendi-sendi tubuh foto Coach (0.0 - 1.0)
    @Published var coachJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    
    /// Menyimpan koordinat sendi-sendi tubuh foto User (0.0 - 1.0)
    @Published var userJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    
    /// Himpunan (Set) berisi nama bagian tubuh User yang posenya salah (misal: "Betis Kiri", "Paha Kiri", "Lengan Kiri").
    /// Properti ini digunakan oleh `ContentView` untuk mewarnai garis kerangka tulang menjadi MERAH.
    @Published var bagianSalah: Set<String> = []
    
    /// Teks pesan status yang ditampilkan pada banner atas UI (misal: "✅ BENAR!" atau "❌ SALAH! Perbaiki: ...")
    @Published var teksStatusPose: String = "Menganalisis dua pose..."
    
    /// Warna background banner status (Hijau jika benar, Merah jika salah, Oranye jika tidak terdeteksi)
    @Published var warnaStatus: Color = .gray
    
    // MARK: - 1. Fungsi Utama Membandingkan 2 Foto
    
    /// Menganalisis foto Coach dan foto User, menghitung selisih sudut sendi, lalu menentukan bagian tubuh yang salah.
    /// - Parameters:
    ///   - coachImage: Gambar pose target (Coach)
    ///   - userImage: Gambar pose tiruan (User)
    func bandingkanDuaFoto(coachImage: UIImage, userImage: UIImage) {
        // Ekstraksi data sendi & sudut dari masing-masing foto
        let dataCoach = prosesSatuFoto(image: coachImage)
        let dataUser = prosesSatuFoto(image: userImage)
        
        // Pembaruan UI dilakukan di Main Thread
        DispatchQueue.main.async {
            self.coachJoints = dataCoach.joints
            self.userJoints = dataUser.joints
            
            var bagianSalahList: [String] = []
            
            /// Batas toleransi selisih sudut (dalam derajat °).
            /// Jika selisih sudut Coach & User > 30.0°, maka dianggap SALAH.
            let toleransi: Double = 30.0
            
            // Loop untuk memeriksa setiap sudut sendi yang berhasil dihitung
            for (namaBagian, sudutCoach) in dataCoach.sudut {
                if let sudutUser = dataUser.sudut[namaBagian] {
                    // Hitung selisih mutlak (absolut) antara sudut Coach dan sudut User
                    let selisih = abs(sudutCoach - sudutUser)
                    
                    // Jika selisih melebihi batas toleransi, tandai bagian tubuh tersebut
                    if selisih > toleransi {
                        // Petakan nama sudut internal ke kategori label UI yang lebih spesifik
                        let kategori: String
                        switch namaBagian {
                        case "Bahu Kanan", "Siku Kanan", "Lengan Kanan":
                            kategori = "Lengan Kanan"
                        case "Bahu Kiri", "Siku Kiri", "Lengan Kiri":
                            kategori = "Lengan Kiri"
                        case "Paha Kanan":
                            kategori = "Paha Kanan"
                        case "Lutut Kanan", "Betis Kanan":
                            kategori = "Betis Kanan"
                        case "Paha Kiri":
                            kategori = "Paha Kiri"
                        case "Lutut Kiri", "Betis Kiri":
                            kategori = "Betis Kiri"
                        default:
                            kategori = namaBagian
                        }
                        
                        // Cegah duplikasi nama kategori dalam daftar kesalahan
                        if !bagianSalahList.contains(kategori) {
                            bagianSalahList.append(kategori)
                        }
                    }
                }
            }
            
            // Simpan daftar bagian salah ke properti @Published agar UI otomatis diperbarui
            self.bagianSalah = Set(bagianSalahList)
            
            // Tentukan status akhir dan warna banner di UI
            if dataCoach.sudut.isEmpty || dataUser.sudut.isEmpty {
                self.teksStatusPose = "⚠️ Pose tubuh tidak terdeteksi jelas."
                self.warnaStatus = .orange
            } else if bagianSalahList.isEmpty {
                self.teksStatusPose = "✅ BENAR! Semua pose akurat."
                self.warnaStatus = .green
            } else {
                // Tampilkan daftar bagian tubuh yang perlu diperbaiki oleh User
                self.teksStatusPose = "❌ SALAH! Perbaiki: \(bagianSalahList.joined(separator: ", "))"
                self.warnaStatus = .red
            }
        }
    }
    
    // MARK: - 2. Ekstraksi Vision untuk 1 Foto
    
    /// Menggunakan Apple Vision Framework untuk mendeteksi lokasi sendi tubuh dan menghitung berbagai sudut sendi.
    /// - Parameter image: Foto `UIImage` yang akan diekstraksi
    /// - Returns: Tuple berisi (map sendi tubuh, dictionary nilai sudut dalam derajat °)
    private func prosesSatuFoto(image: UIImage) -> (joints: [VNHumanBodyPoseObservation.JointName: CGPoint], sudut: [String: Double]) {
        guard let cgImage = image.cgImage else { return ([:], [:]) }
        
        // 1. Inisialisasi request deteksi pose tubuh milik Apple Vision
        let request = VNDetectHumanBodyPoseRequest()
        
        // 2. Sesuaikan orientasi gambar agar Vision membaca titik kiri-kanan & atas-bawah dengan tepat
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        
        do {
            // Jalankan deteksi Vision
            try handler.perform([request])
            guard let observation = request.results?.first else { return ([:], [:]) }
            
            // Ambil semua titik sendi yang terdeteksi
            let recognizedPoints = try observation.recognizedPoints(.all)
            var extractedJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            
            // Hanya simpan titik sendi yang tingkat kepercayaannya (confidence) di atas 30%
            for (jointName, point) in recognizedPoints where point.confidence > 0.3 {
                extractedJoints[jointName] = point.location
            }
            
            var kumpulanSudut: [String: Double] = [:]
            
            // MARK: - A. Lengan Kanan (Siku & Bahu)
            if let b = extractedJoints[.rightShoulder], let s = extractedJoints[.rightElbow], let p = extractedJoints[.rightWrist] {
                // Sudut Siku Kanan: Tekukan antara Bahu -> Siku -> Pergelangan Tangan
                kumpulanSudut["Siku Kanan"] = hitungSudut(pointA: b, pointB: s, pointC: p)
            }
            if let n = extractedJoints[.neck], let b = extractedJoints[.rightShoulder], let s = extractedJoints[.rightElbow] {
                // Sudut Bahu Kanan: Angkatan lengan relatif terhadap Leher -> Bahu -> Siku
                kumpulanSudut["Bahu Kanan"] = hitungSudut(pointA: n, pointB: b, pointC: s)
            }
            
            // MARK: - B. Lengan Kiri (Siku & Bahu)
            if let b = extractedJoints[.leftShoulder], let s = extractedJoints[.leftElbow], let p = extractedJoints[.leftWrist] {
                // Sudut Siku Kiri: Tekukan antara Bahu -> Siku -> Pergelangan Tangan
                kumpulanSudut["Siku Kiri"] = hitungSudut(pointA: b, pointB: s, pointC: p)
            }
            if let n = extractedJoints[.neck], let b = extractedJoints[.leftShoulder], let s = extractedJoints[.leftElbow] {
                // Sudut Bahu Kiri: Angkatan lengan relatif terhadap Leher -> Bahu -> Siku
                kumpulanSudut["Bahu Kiri"] = hitungSudut(pointA: n, pointB: b, pointC: s)
            }
            
            // MARK: - C. Kaki Kanan (Lutut, Paha, & Betis)
            if let p = extractedJoints[.rightHip], let l = extractedJoints[.rightKnee], let a = extractedJoints[.rightAnkle] {
                // Sudut Lutut Kanan: Tekukan lutut antara Pinggul -> Lutut -> Mata Kaki
                kumpulanSudut["Lutut Kanan"] = hitungSudut(pointA: p, pointB: l, pointC: a)
            }
            if let n = extractedJoints[.neck], let p = extractedJoints[.rightHip], let l = extractedJoints[.rightKnee] {
                // Sudut Paha Kanan: Angkatan paha relatif terhadap Leher -> Pinggul -> Lutut (mendeteksi kaki diangkat)
                kumpulanSudut["Paha Kanan"] = hitungSudut(pointA: n, pointB: p, pointC: l)
            }
            if let n = extractedJoints[.neck], let l = extractedJoints[.rightKnee], let a = extractedJoints[.rightAnkle] {
                // Sudut Betis Kanan: Kemiringan betis relatif terhadap Leher -> Lutut -> Mata Kaki
                kumpulanSudut["Betis Kanan"] = hitungSudut(pointA: n, pointB: l, pointC: a)
            }
            
            // MARK: - D. Kaki Kiri (Lutut, Paha, & Betis)
            if let p = extractedJoints[.leftHip], let l = extractedJoints[.leftKnee], let a = extractedJoints[.leftAnkle] {
                // Sudut Lutut Kiri: Tekukan lutut antara Pinggul -> Lutut -> Mata Kaki
                kumpulanSudut["Lutut Kiri"] = hitungSudut(pointA: p, pointB: l, pointC: a)
            }
            if let n = extractedJoints[.neck], let p = extractedJoints[.leftHip], let l = extractedJoints[.leftKnee] {
                // Sudut Paha Kiri: Angkatan paha relatif terhadap Leher -> Pinggul -> Lutut (mendeteksi kaki diangkat)
                kumpulanSudut["Paha Kiri"] = hitungSudut(pointA: n, pointB: p, pointC: l)
            }
            if let n = extractedJoints[.neck], let l = extractedJoints[.leftKnee], let a = extractedJoints[.leftAnkle] {
                // Sudut Betis Kiri: Kemiringan betis relatif terhadap Leher -> Lutut -> Mata Kaki
                kumpulanSudut["Betis Kiri"] = hitungSudut(pointA: n, pointB: l, pointC: a)
            }
            
            // MARK: - E. Torso & Kepala
            if let l = extractedJoints[.neck], let r = extractedJoints[.root], let p = extractedJoints[.rightHip] {
                // Sudut Torso: Kelurusan badan Leher -> Panggul Tengah -> Pinggul
                kumpulanSudut["Torso"] = hitungSudut(pointA: l, pointB: r, pointC: p)
            }
            if let h = extractedJoints[.nose], let l = extractedJoints[.neck], let r = extractedJoints[.root] {
                // Sudut Kepala: Kemiringan wajah Hidung -> Leher -> Panggul Tengah
                kumpulanSudut["Kepala"] = hitungSudut(pointA: h, pointB: l, pointC: r)
            }
            
            return (extractedJoints, kumpulanSudut)
            
        } catch {
            print("Vision Error: \(error)")
            return ([:], [:])
        }
    }
    
    // MARK: - 3. Rumus Trigonometri Sudut (Atan2)
    
    /// Menhitung besar sudut (dalam derajat °) yang dibentuk oleh 3 titik koordinat 2D (A - B - C), dengan titik B sebagai vertex (titik sudut pusat).
    /// - Parameters:
    ///   - pointA: Titik awal (misal: Bahu/Pinggul)
    ///   - pointB: Titik pusat sudut/vertex (misal: Siku/Lutut)
    ///   - pointC: Titik akhir (misal: Pergelangan Tangan/Mata Kaki)
    /// - Returns: Besar sudut dalam rentang 0.0° - 180.0°
    private func hitungSudut(pointA: CGPoint, pointB: CGPoint, pointC: CGPoint) -> Double {
        // Hitung selisih sudut vektor BC dan vektor BA menggunakan fungsi atan2
        let radians = atan2(pointC.y - pointB.y, pointC.x - pointB.x) -
                      atan2(pointA.y - pointB.y, pointA.x - pointB.x)
        
        // Konversi nilai radian ke derajat
        var degrees = radians * 180.0 / .pi
        
        // Normalisasi derajat ke rentang positif 0° - 360°
        if degrees < 0 { degrees += 360.0 }
        
        // Ubah menjadi sudut dalam (interior angle) rentang 0° - 180°
        if degrees > 180.0 { degrees = 360.0 - degrees }
        
        return degrees
    }
}
