//
//  BoneSegment.swift
//  C4-Vision
//
//  Created by Sharon Tan on 03/09/26.
//

import SwiftUI
import Vision

// MARK: - Model Ruas Tulang (Bone Segment)
/// Struktur data pembantu untuk mendefinisikan hubungan garis tulang antara dua titik sendi Vision.
/// Digunakan oleh komponen skeleton overlay (`KotakVideo` dan `KotakFoto`) untuk menggambar kerangka tubuh.
struct BoneSegment {
    /// Nama kelompok bagian tubuh (misal: "Right Arm", "Left Arm", "Torso", "Right Leg", "Left Leg", "Head")
    let group: String
    
    /// Titik awal sendi (misal: .neck, .rightShoulder, .rightKnee)
    let start: VNHumanBodyPoseObservation.JointName
    
    /// Titik akhir sendi (misal: .rightElbow, .rightWrist, .rightAnkle)
    let end: VNHumanBodyPoseObservation.JointName
}
