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
    /// Inisialisasi pengolah data pose (PoseAnalyzer)
    @StateObject private var analyzer = PoseAnalyzer()
    
    var body: some View {
        VStack(spacing: 12) {
            // Banner Teks Status Hasil Analisis Pose Real-Time
            Text(analyzer.teksStatusPose)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(analyzer.warnaStatus)
                .cornerRadius(10)
                .padding(.horizontal)
            
            // Pop-Up Umpan Balik Refleksi Spesifik Saat Video Terhenti (Auto-Pause)
            if analyzer.isPausedOnError {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Momen Refleksi Kesalahan")
                            .font(.headline)
                            .bold()
                        Spacer()
                    }
                    Text(analyzer.pesanSpesifik)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.red.opacity(0.9))
                .cornerRadius(12)
                .shadow(radius: 6)
                .padding(.horizontal)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Area Perbandingan Dua Video Bergerak Berdampingan
            HStack(spacing: 16) {
                // VIDEO KIRI (COACH: dance_coach2.mp4)
                KotakVideo(
                    player: analyzer.coachPlayer,
                    joints: analyzer.coachJoints,
                    bagianSalah: [],
                    label: "Coach (Acuan: dance_coach2.mp4)"
                )
                
                // VIDEO KANAN (USER: dance_user.mp4)
                KotakVideo(
                    player: analyzer.userPlayer,
                    joints: analyzer.userJoints,
                    bagianSalah: analyzer.bagianSalah,
                    label: "User (Tarian: dance_user2.mp4)"
                )
            }
            .padding(.horizontal)
            
            // Bar Checkpoints Kesalahan (Timeline Bullets)
            if !analyzer.checkpoints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("📌 Titik Checkpoint Kesalahan:")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(analyzer.checkpoints) { cp in
                                Button(action: {
                                    analyzer.lompatKeCheckpoint(cp)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "flag.fill")
                                            .foregroundColor(.red)
                                        Text(cp.timeFormatted)
                                            .bold()
                                        Text("(\(Array(cp.bagianSalah).joined(separator: ", ")))")
                                    }
                                    .font(.caption)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(analyzer.activeCheckpoint == cp ? Color.red : Color.gray.opacity(0.2))
                                    .foregroundColor(analyzer.activeCheckpoint == cp ? .white : .primary)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(analyzer.activeCheckpoint == cp ? Color.red : Color.clear, lineWidth: 2)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            // Tombol Navigasi "Next / Lanjutkan Tarian" saat terhenti pada kesalahan
            if analyzer.isPausedOnError {
                Button(action: {
                    analyzer.lanjutkanVideo()
                }) {
                    HStack {
                        Text("Lanjutkan Tarian (Next)")
                            .font(.headline)
                            .bold()
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title3)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                }
                .padding(.horizontal)
            }
            
            // Tombol Putar Ulang Kedua Video (Replay All)
            Button(action: {
                analyzer.replayVideo()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Putar Ulang Kedua Video")
                }
                .font(.subheadline)
                .bold()
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .animation(.easeInOut, value: analyzer.isPausedOnError)
        .onAppear {
            // Mulai memutar dan mengontrol perbandingan real-time 2 video
            analyzer.mulaiMemutarVideo(namaCoach: "dance_coach2", namaUser: "dance_user2")
        }
    }
}

#Preview {
    ContentView()
}
