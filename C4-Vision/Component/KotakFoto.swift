//
//  KotakFoto.swift
//  C4-Vision
//
//  Created by Sharon Tan on 28/08/26.
//

import SwiftUI
import Vision

// MARK: - Komponen UI Kotak Foto & Skeleton Overlay (KotakFoto)
/// Komponen `KotakFoto` menampilkan gambar pose statis beserta overlay garis kerangka tulang (skeleton) di atasnya.
/// Digunakan untuk perbandingan pose statis atau evaluasi foto checkpoint.
struct KotakFoto: View {
    /// Gambar foto pose
    let image: UIImage
    
    /// Koordinat sendi-sendi tubuh hasil analisis Apple Vision
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    
    /// Himpunan bagian tubuh yang posenya salah
    let bagianSalah: Set<String>
    
    /// Label judul foto
    let label: String
    
    var body: some View {
        VStack {
            Text(label)
                .font(.subheadline)
                .bold()
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .overlay(
                    // GeometryReader digunakan untuk mendapatkan ukuran aktual gambar di layar
                    GeometryReader { geometry in
                        drawSkeleton(in: geometry.size, joints: joints)
                    }
                )
                .cornerRadius(8)
        }
    }
    
    // MARK: - Fungsi Menggambar Garis Tulang & Titik Sendi
    @ViewBuilder
    func drawSkeleton(in size: CGSize, joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> some View {
        // Pemetaan ruas garis tulang berdasarkan kelompok bagian tubuh menggunakan struct BoneSegment bersama
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
            
            // Kaki Kanan (Paha Kanan & Betis Kanan)
            BoneSegment(group: "Paha Kanan", start: .root, end: .rightHip),
            BoneSegment(group: "Paha Kanan", start: .rightHip, end: .rightKnee),
            BoneSegment(group: "Betis Kanan", start: .rightKnee, end: .rightAnkle),
            
            // Kaki Kiri (Paha Kiri & Betis Kiri)
            BoneSegment(group: "Paha Kiri", start: .root, end: .leftHip),
            BoneSegment(group: "Paha Kiri", start: .leftHip, end: .leftKnee),
            BoneSegment(group: "Betis Kiri", start: .leftKnee, end: .leftAnkle),
            
            // Kepala
            BoneSegment(group: "Kepala", start: .nose, end: .neck)
        ]
        
        ZStack {
            // 1. Menggambar Setiap Ruas Tulang secara Individual
            ForEach(0..<segments.count, id: \.self) { index in
                let seg = segments[index]
                if let s = joints[seg.start], let e = joints[seg.end] {
                    // Cek apakah kelompok ruas tulang ini termasuk dalam daftar bagianSalah
                    let isSalah = bagianSalah.contains(seg.group) ||
                                  (bagianSalah.contains("Kaki Kanan") && seg.group.contains("Kanan")) ||
                                  (bagianSalah.contains("Kaki Kiri") && seg.group.contains("Kiri"))
                    
                    Path { path in
                        // Catatan: Koordinat Y milik Vision dimulai dari bawah (0.0 di bawah, 1.0 di atas).
                        // Oleh karena itu kita membalik koordinat Y dengan rumus: (1.0 - s.y) * size.height
                        path.move(to: CGPoint(x: s.x * size.width, y: (1.0 - s.y) * size.height))
                        path.addLine(to: CGPoint(x: e.x * size.width, y: (1.0 - e.y) * size.height))
                    }
                    // Jika salah: diwarnai MERAH. Jika benar: diwarnai HIJAU.
                    .stroke(isSalah ? Color.red : Color.green, lineWidth: 4)
                }
            }
            
            // 2. Menggambar Titik Sendi (Lingkaran Putih Bersih) pada Setiap Sendi
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
