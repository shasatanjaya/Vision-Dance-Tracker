//
//  ContentView.swift
//  C4-Vision
//
//  Created by Sharon Tan on 26/08/26.
//

import SwiftUI
import Vision
import AVKit

//struct ContentView: View {
//    @StateObject private var analyzer = PoseAnalyzer()
//
//    var body: some View {
//        VStack {
//            Text("Cycle 2: Video Analysis")
//                .font(.title2)
//                .bold()
//                .padding(.top)
//
//            // Kotak Status Validasi di layar
//            Text(analyzer.teksStatusPose)
//                .font(.headline)
//                .foregroundColor(.white)
//                .padding()
//                .frame(maxWidth: .infinity)
//                .background(analyzer.warnaStatus)
//                .cornerRadius(10)
//                .padding(.horizontal)
//
//            // MARK: - Area Pemutar Video & Overlay Skeleton
//            GeometryReader { geometry in
//                ZStack {
//                    // 1. Memutar video menggunakan player dari PoseAnalyzer
//                    VideoPlayer(player: analyzer.player)
//                    // Sengaja dimatikan interaksinya agar user tidak menggeser (scrubbing)
//                    // video secara manual yang bisa mengacaukan sinkronisasi Vision
//                        .disabled(true)
//
//                    // 2. Menggambar kerangka lengan kanan tepat di atas video
//                    drawSkeleton(in: geometry.size)
//                }
//            }
//            // 1. Kunci rasio agar kotak ini 100% pas dengan video vertikal (Portrait)
//            .aspectRatio(9/16, contentMode: .fit)
//            // 2. Batasi tingginya
//            .frame(height: 800)
//            // 3. Taruh kotak yang sudah pas ini ke tengah layar (mengakali area hitam)
//            .frame(maxWidth: .infinity, alignment: .center)
//            .padding()
//
//            // MARK: - Tombol Replay
//            Button(action: {
//                analyzer.replayVideo()
//            }) {
//                HStack {
//                    Image(systemName: "arrow.clockwise")
//                    Text("Putar Ulang Video")
//                }
//                .font(.headline)
//                .foregroundColor(.white)
//                .padding()
//                .frame(maxWidth: .infinity)
//                .background(Color.blue)
//                .cornerRadius(10)
//            }
//            .padding(.horizontal)
//
//            Spacer()
//        }
//        .onAppear {
//            // Saat layar muncul, suruh Otak untuk mencari file "dance.mp4" dan memutarnya
//            analyzer.mulaiMemutarVideo(namaFile: "dance2")
//        }
//    }
//
//    // MARK: - Fungsi Menggambar UI Skeleton
//    @ViewBuilder
//    func drawSkeleton(in size: CGSize) -> some View {
//        ZStack {
//            // Gambar Garis Tulang Full Body
//            Path { path in
//                func drawBone(from startJoint: VNHumanBodyPoseObservation.JointName, to endJoint: VNHumanBodyPoseObservation.JointName) {
//                    if let start = analyzer.detectedJoints[startJoint], let end = analyzer.detectedJoints[endJoint] {
//                        path.move(to: convertPoint(start, size: size))
//                        path.addLine(to: convertPoint(end, size: size))
//                    }
//                }
//
//                // LENGAN KANAN
//                drawBone(from: .rightShoulder, to: .rightElbow)
//                drawBone(from: .rightElbow, to: .rightWrist)
//
//                // LENGAN KIRI
//                drawBone(from: .leftShoulder, to: .leftElbow)
//                drawBone(from: .leftElbow, to: .leftWrist)
//
//                // BADAN (TORSO)
//                drawBone(from: .neck, to: .rightShoulder)
//                drawBone(from: .neck, to: .leftShoulder)
//                drawBone(from: .neck, to: .root) // Root = Panggul tengah
//
//                // KAKI KANAN
//                drawBone(from: .root, to: .rightHip)
//                drawBone(from: .rightHip, to: .rightKnee)
//                drawBone(from: .rightKnee, to: .rightAnkle)
//
//                // KAKI KIRI
//                drawBone(from: .root, to: .leftHip)
//                drawBone(from: .leftHip, to: .leftKnee)
//                drawBone(from: .leftKnee, to: .leftAnkle)
//
//                // WAJAH (Opsional, menghubungkan hidung ke leher)
//                drawBone(from: .nose, to: .neck)
//            }
//            .stroke(Color.green, lineWidth: 3)
//
//            // Gambar Titik Sendi
//            ForEach(Array(analyzer.detectedJoints.keys), id: \.self) { jointName in
//                if let point = analyzer.detectedJoints[jointName] {
//                    Circle()
//                        .fill(Color.red)
//                        .frame(width: 8, height: 8)
//                        .position(convertPoint(point, size: size))
//                }
//            }
//        }
//    }
//
//    // MARK: - Rumus Converter UI
//    func convertPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
//        return CGPoint(x: point.x * size.width, y: (1.0 - point.y) * size.height)
//    }
//}

struct ContentView: View {
    /// Inisialisasi pengolah data pose (PoseAnalyzer)
    @StateObject private var analyzer = PoseAnalyzer()
    
    var body: some View {
        VStack {
            Text("Cycle 2: Static Pose Comparison")
                .font(.title2).bold().padding()
            
            // Banner Teks Status Hasil Analisis Pose
            Text(analyzer.teksStatusPose)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(analyzer.warnaStatus)
                .cornerRadius(10)
                .padding(.horizontal)
            
            // Area Perbandingan Dua Foto Samping-sampingan
            HStack(spacing: 16) {
                // FOTO KIRI (COACH) - Tidak memiliki bagianSalah (dikirim himpunan kosong [])
                if let coachImg = UIImage(named: "pose1") {
                    KotakFoto(image: coachImg, joints: analyzer.coachJoints, bagianSalah: [], label: "Coach")
                }
                
                // FOTO KANAN (USER) - Memiliki daftar bagianSalah yang akan diwarnai MERAH
                if let userImg = UIImage(named: "pose1-2") {
                    KotakFoto(image: userImg, joints: analyzer.userJoints, bagianSalah: analyzer.bagianSalah, label: "User")
                }
            }
            .padding()
            Spacer()
        }
        .onAppear {
            // Saat tampilan muncul, langsung jalankan analisis perbandingan 2 foto
            if let coachImg = UIImage(named: "pose1"), let userImg = UIImage(named: "pose1-2") {
                analyzer.bandingkanDuaFoto(coachImage: coachImg, userImage: userImg)
            }
        }
    }
}

// MARK: - Komponen UI Kotak Foto & Skeleton Overlay

/// Komponen `KotakFoto` menampilkan gambar pose beserta overlay garis kerangka tulang (skeleton) di atasnya.
struct KotakFoto: View {
    let image: UIImage
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let bagianSalah: Set<String>
    let label: String
    
    var body: some View {
        VStack {
            Text(label).font(.subheadline).bold()
            
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
    
    /// Struktur data pembantu untuk mendefinisikan ruas garis tulang
    struct BoneSegment {
        let group: String // Nama kelompok bagian tubuh (misal: "Betis Kiri", "Paha Kanan")
        let start: VNHumanBodyPoseObservation.JointName // Titik awal sendi
        let end: VNHumanBodyPoseObservation.JointName // Titik akhir sendi
    }
    
    // MARK: - Fungsi Menggambar Garis Tulang & Titik Sendi
    @ViewBuilder
    func drawSkeleton(in size: CGSize, joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> some View {
        // Pemetaan ruas garis tulang berdasarkan kelompok bagian tubuh
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
                        // Oleh karena itu kita membalik koordinat Y dengan rumus: (1.0 - y) * height
                        path.move(to: CGPoint(x: s.x * size.width, y: (1.0 - s.y) * size.height))
                        path.addLine(to: CGPoint(x: e.x * size.width, y: (1.0 - e.y) * size.height))
                    }
                    // Jika salah: diwarnai MERAH. Jika benar: diwarnai HIJAU.
                    .stroke(isSalah ? Color.red : Color.green, lineWidth: 4)
                }
            }
            
            // 2. Menggambar Titik Sendi (Lingkaran Kuning) pada Setiap Sendi
            ForEach(Array(joints.keys), id: \.self) { jointName in
                if let point = joints[jointName] {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 8)
                        .position(x: point.x * size.width, y: (1.0 - point.y) * size.height)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
