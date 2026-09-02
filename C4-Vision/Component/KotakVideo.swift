//
//  KotakVideo.swift
//  C4-Vision
//
//  Created by Sharon Tan on 28/08/26.
//

import SwiftUI
import Vision
import AVKit

// MARK: - Komponen UI Kotak Video & Real-Time Skeleton Overlay

/// Komponen `KotakVideo` menampilkan pemutar video bergerak beserta overlay kerangka tulang (skeleton) real-time di atasnya.
struct KotakVideo: View {
    let player: AVPlayer
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let bagianSalah: Set<String>
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            ZStack {
                // 1. Pemutar Video
                VideoPlayer(player: player)
                    .disabled(true) // Sengaja dimatikan interaksinya agar video tidak di-scrubbing manual
                
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
    
    /// Struktur data pembantu untuk mendefinisikan ruas garis tulang
    struct BoneSegment {
        let group: String
        let start: VNHumanBodyPoseObservation.JointName
        let end: VNHumanBodyPoseObservation.JointName
    }
    
    // MARK: - Fungsi Menggambar Garis Tulang & Titik Sendi Real-Time
    @ViewBuilder
    func drawSkeleton(in size: CGSize, joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> some View {
        let segments: [BoneSegment] = [
            // Lengan Kanan
            BoneSegment(group: "Lengan Kanan", start: .rightShoulder, end: .rightElbow),
            BoneSegment(group: "Lengan Kanan", start: .rightElbow, end: .rightWrist),
            
            // Lengan Kiri
            BoneSegment(group: "Lengan Kiri", start: .leftShoulder, end: .leftElbow),
            BoneSegment(group: "Lengan Kiri", start: .leftElbow, end: .leftWrist),
            
            // Badan (Torso)
            BoneSegment(group: "Torso", start: .neck, end: .rightShoulder),
            BoneSegment(group: "Torso", start: .neck, end: .leftShoulder),
            BoneSegment(group: "Torso", start: .neck, end: .root),
            
            // Kaki Kanan (Paha & Betis)
            BoneSegment(group: "Paha Kanan", start: .root, end: .rightHip),
            BoneSegment(group: "Paha Kanan", start: .rightHip, end: .rightKnee),
            BoneSegment(group: "Betis Kanan", start: .rightKnee, end: .rightAnkle),
            
            // Kaki Kiri (Paha & Betis)
            BoneSegment(group: "Paha Kiri", start: .root, end: .leftHip),
            BoneSegment(group: "Paha Kiri", start: .leftHip, end: .leftKnee),
            BoneSegment(group: "Betis Kiri", start: .leftKnee, end: .leftAnkle),
            
            // Kepala
            BoneSegment(group: "Kepala", start: .nose, end: .neck)
        ]
        
        ZStack {
            // 1. Menggambar Ruas Tulang (Garis Merah jika salah, Hijau jika benar)
            ForEach(0..<segments.count, id: \.self) { index in
                let seg = segments[index]
                if let s = joints[seg.start], let e = joints[seg.end] {
                    let isSalah = bagianSalah.contains(seg.group) ||
                                  (bagianSalah.contains("Kaki Kanan") && seg.group.contains("Kanan")) ||
                                  (bagianSalah.contains("Kaki Kiri") && seg.group.contains("Kiri"))
                    
                    Path { path in
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
