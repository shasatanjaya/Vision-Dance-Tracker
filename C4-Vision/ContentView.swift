//
//  ContentView.swift
//  C4-Vision
//
//  Created by Sharon Tan on 26/08/26.
//

import SwiftUI
import Vision
import AVKit

struct ContentView: View {
    @StateObject private var analyzer = PoseAnalyzer()
    
    var body: some View {
        VStack {
            Text("Cycle 2: Video Analysis")
                .font(.title2)
                .bold()
                .padding(.top)
            
            // Kotak Status Validasi di layar
            Text(analyzer.teksStatusPose)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(analyzer.warnaStatus)
                .cornerRadius(10)
                .padding(.horizontal)
            
            // MARK: - Area Pemutar Video & Overlay Skeleton
            GeometryReader { geometry in
                ZStack {
                    // 1. Memutar video menggunakan player dari PoseAnalyzer
                    VideoPlayer(player: analyzer.player)
                    // Sengaja dimatikan interaksinya agar user tidak menggeser (scrubbing)
                    // video secara manual yang bisa mengacaukan sinkronisasi Vision
                        .disabled(true)
                    
                    // 2. Menggambar kerangka lengan kanan tepat di atas video
                    drawSkeleton(in: geometry.size)
                }
            }
            // 1. Kunci rasio agar kotak ini 100% pas dengan video vertikal (Portrait)
            .aspectRatio(9/16, contentMode: .fit)
            // 2. Batasi tingginya
            .frame(height: 800)
            // 3. Taruh kotak yang sudah pas ini ke tengah layar (mengakali area hitam)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
            
            // MARK: - Tombol Replay
            Button(action: {
                analyzer.replayVideo()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Putar Ulang Video")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .onAppear {
            // Saat layar muncul, suruh Otak untuk mencari file "dance.mp4" dan memutarnya
            analyzer.mulaiMemutarVideo(namaFile: "dance2")
        }
    }
    
    // MARK: - Fungsi Menggambar UI Skeleton
    @ViewBuilder
    func drawSkeleton(in size: CGSize) -> some View {
        ZStack {
            // Gambar Garis Tulang Full Body
            Path { path in
                func drawBone(from startJoint: VNHumanBodyPoseObservation.JointName, to endJoint: VNHumanBodyPoseObservation.JointName) {
                    if let start = analyzer.detectedJoints[startJoint], let end = analyzer.detectedJoints[endJoint] {
                        path.move(to: convertPoint(start, size: size))
                        path.addLine(to: convertPoint(end, size: size))
                    }
                }
                
                // LENGAN KANAN
                drawBone(from: .rightShoulder, to: .rightElbow)
                drawBone(from: .rightElbow, to: .rightWrist)
                
                // LENGAN KIRI
                drawBone(from: .leftShoulder, to: .leftElbow)
                drawBone(from: .leftElbow, to: .leftWrist)
                
                // BADAN (TORSO)
                drawBone(from: .neck, to: .rightShoulder)
                drawBone(from: .neck, to: .leftShoulder)
                drawBone(from: .neck, to: .root) // Root = Panggul tengah
                
                // KAKI KANAN
                drawBone(from: .root, to: .rightHip)
                drawBone(from: .rightHip, to: .rightKnee)
                drawBone(from: .rightKnee, to: .rightAnkle)
                
                // KAKI KIRI
                drawBone(from: .root, to: .leftHip)
                drawBone(from: .leftHip, to: .leftKnee)
                drawBone(from: .leftKnee, to: .leftAnkle)
                
                // WAJAH (Opsional, menghubungkan hidung ke leher)
                drawBone(from: .nose, to: .neck)
            }
            .stroke(Color.green, lineWidth: 3)
            
            // Gambar Titik Sendi
            ForEach(Array(analyzer.detectedJoints.keys), id: \.self) { jointName in
                if let point = analyzer.detectedJoints[jointName] {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .position(convertPoint(point, size: size))
                }
            }
        }
    }
    
    // MARK: - Rumus Converter UI
    func convertPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
        return CGPoint(x: point.x * size.width, y: (1.0 - point.y) * size.height)
    }
}

#Preview {
    ContentView()
}
