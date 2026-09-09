//
//  KotakVideo.swift
//  C4-Vision
//
//  Created by Sharon Tan on 28/08/26.
//

import SwiftUI
import Vision
import AVKit

// MARK: - Komponen Pemutar Video dengan Overlay Skeleton Real-Time (KotakVideo)
/// Komponen `KotakVideo` menampilkan pemutar video bergerak berdampingan dengan lapisan kerangka tulang (skeleton) real-time di atasnya.
///
/// Fitur Utama:
/// 1. **Pemutar Video Vertikal (9:16)**: Menjaga rasio aspek tetap konsisten untuk video tarian portrait.
/// 2. **Real-Time Skeleton Overlay**: Menggambar garis tulang tubuh manusia berdasarkan deteksi Apple Vision Framework.
/// 3. **Indikator Warna Error**: Ruas tulang akan otomatis diwarnai **MERAH** jika terdeteksi salah, dan **HIJAU** jika postur benar.
/// 4. **Titik Sendi Putih**: Menampilkan lingkaran putih bersih di setiap titik sendi untuk memudahkan pemantauan sudut gerak.
struct KotakVideo: View {
    /// Instance `AVPlayer` yang memutar video
    let player: AVPlayer
    
    /// Dictionary koordinat sendi-sendi tubuh hasil ekstraksi Vision (nilai normalisasi 0.0 - 1.0)
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    
    /// Himpunan (Set) bagian tubuh yang posenya salah (contoh: "Right Arm", "Left Leg", dll.)
    let bagianSalah: Set<String>
    
    /// Label teks judul di atas video (contoh: "Coach (Reference)" atau "User (Dance)")
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            // Label Teks Judul
            Text(label)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            ZStack {
                // 1. Pemutar Video
                VideoPlayer(player: player)
                    .disabled(true) // Sengaja dinonaktifkan kontrol interaksinya agar video tidak di-scrubbing manual
                
                // 2. Overlay Kerangka Tulang Real-Time
                GeometryReader { geometry in
                    drawSkeleton(in: geometry.size, joints: joints)
                }
            }
            .aspectRatio(9/16, contentMode: .fit) // Kunci rasio video vertikal (Portrait)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Fungsi Menggambar Garis Tulang & Titik Sendi Real-Time
    @ViewBuilder
    func drawSkeleton(in size: CGSize, joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> some View {
        // Daftar pemetaan ruas tulang tubuh menggunakan struct BoneSegment bersama
        let segments: [BoneSegment] = [
            // Lengan Kanan (Right Arm)
            BoneSegment(group: "Right Arm", start: .rightShoulder, end: .rightElbow),
            BoneSegment(group: "Right Arm", start: .rightElbow, end: .rightWrist),
            
            // Lengan Kiri (Left Arm)
            BoneSegment(group: "Left Arm", start: .leftShoulder, end: .leftElbow),
            BoneSegment(group: "Left Arm", start: .leftElbow, end: .leftWrist),
            
            // Badan / Batang Tubuh (Torso)
            BoneSegment(group: "Torso", start: .neck, end: .rightShoulder),
            BoneSegment(group: "Torso", start: .neck, end: .leftShoulder),
            BoneSegment(group: "Torso", start: .neck, end: .root),
            
            // Kaki Kanan (Right Leg)
            BoneSegment(group: "Right Leg", start: .root, end: .rightHip),
            BoneSegment(group: "Right Leg", start: .rightHip, end: .rightKnee),
            BoneSegment(group: "Right Leg", start: .rightKnee, end: .rightAnkle),
            
            // Kaki Kiri (Left Leg)
            BoneSegment(group: "Left Leg", start: .root, end: .leftHip),
            BoneSegment(group: "Left Leg", start: .leftHip, end: .leftKnee),
            BoneSegment(group: "Left Leg", start: .leftKnee, end: .leftAnkle),
            
            // Kepala (Head)
            BoneSegment(group: "Head", start: .nose, end: .neck)
        ]
        
        ZStack {
            // 1. Menggambar Ruas Tulang (Garis Merah jika salah, Hijau jika benar)
            ForEach(0..<segments.count, id: \.self) { index in
                let seg = segments[index]
                if let s = joints[seg.start], let e = joints[seg.end] {
                    let isSalah = bagianSalah.contains(seg.group) ||
                                  (bagianSalah.contains("Lengan Kanan") && seg.group == "Right Arm") ||
                                  (bagianSalah.contains("Lengan Kiri") && seg.group == "Left Arm") ||
                                  (bagianSalah.contains("Paha Kanan") && seg.group == "Right Leg") ||
                                  (bagianSalah.contains("Betis Kanan") && seg.group == "Right Leg") ||
                                  (bagianSalah.contains("Paha Kiri") && seg.group == "Left Leg") ||
                                  (bagianSalah.contains("Betis Kiri") && seg.group == "Left Leg") ||
                                  (bagianSalah.contains("Kepala") && seg.group == "Head")
                    
                    Path { path in
                        // Membalik koordinat Y karena sistem koordinat Vision dimulai dari kiri-bawah (0,0)
                        path.move(to: CGPoint(x: s.x * size.width, y: (1.0 - s.y) * size.height))
                        path.addLine(to: CGPoint(x: e.x * size.width, y: (1.0 - e.y) * size.height))
                    }
                    .stroke(isSalah ? Color.red : Color.green, lineWidth: 4)
                }
            }
            
            // 2. Menggambar Titik Sendi (Lingkaran Putih Bersih)
            ForEach(Array(joints.keys), id: \.self) { jointName in
                if let point = joints[jointName] {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .position(x: point.x * size.width, y: (1.0 - point.y) * size.height)
                }
            }
        }
    }
}
