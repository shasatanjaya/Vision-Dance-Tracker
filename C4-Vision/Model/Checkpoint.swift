//
//  Checkpoint.swift
//  C4-Vision
//
//  Created by Sharon Tan on 03/09/26.
//

import SwiftUI
import Vision
import AVFoundation

// MARK: - Model Data Checkpoint (Error Marker)
/// Model data untuk menampung momen kesalahan (Checkpoint) yang terjadi selama perbandingan tarian.
/// Checkpoint disimpan saat gerakan tarian pengguna terdeteksi salah secara beruntun (sustained posture error).
struct Checkpoint: Identifiable, Equatable {
    /// ID unik untuk setiap rekaman checkpoint kesalahan
    let id: UUID = UUID()
    
    /// Waktu pemutaran video dalam format CMTime (digunakan untuk operasi seek video yang presisi)
    let timestamp: CMTime
    
    /// Waktu kesalahan dalam satuan detik murni (Double)
    let timeInSeconds: Double
    
    /// Format string waktu yang rapi dan mudah dibaca (contoh: "00:05")
    let timeFormatted: String
    
    /// Kumpulan nama bagian tubuh pengguna yang posenya tidak sesuai dengan Coach (misal: "Right Arm", "Left Leg")
    let bagianSalah: Set<String>
    
    /// Pesan instruksi evaluasi spesifik untuk memperbaiki postur tubuh pengguna
    let pesan: String
    
    /// Posisi koordinat sendi-sendi tubuh Coach pada detik terjadinya checkpoint ini
    let coachJoints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    
    /// Posisi koordinat sendi-sendi tubuh User pada detik terjadinya checkpoint ini
    let userJoints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    
    /// Protokol kesamaan Equatable
    static func == (lhs: Checkpoint, rhs: Checkpoint) -> Bool {
        return lhs.id == rhs.id
    }
}
