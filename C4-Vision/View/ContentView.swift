//
//  ContentView.swift
//  C4-Vision
//
//  Created by Sharon Tan on 26/08/26.
//

import SwiftUI
import Vision
import AVKit

// MARK: - Layar Perbandingan Pose Video (ContentView)
/// Layar pemutaran video berdampingan (Coach vs User) dengan analisis pose AI secara real-time.
///
/// Fitur Utama:
/// 1. **Dual Video Player (Side-by-Side)**: Video Coach di kiri (dengan audio utama) dan video User di kanan (di-mute).
/// 2. **Real-Time Skeleton Tracking**: Menggambar titik sendi dan garis tulang tubuh di atas video secara langsung.
/// 3. **Auto-Pause on Error**: Video otomatis berhenti sesaat jika gerakan pengguna salah selama beberapa frame berturut-turut.
/// 4. **Error Reflection Banner**: Menampilkan pesan evaluasi spesifik tentang bagian tubuh mana yang perlu diperbaiki.
/// 5. **Checkpoint Timeline**: Menampilkan titik-titik bendera kesalahan di timeline yang dapat diklik untuk melompat kembali ke momen kesalahan tersebut.
/// 6. **Control Bar**: Tombol Replay Video dan tombol Continue Dance (Next) untuk melanjutkan latihan setelah jeda kesalahan.
struct ContentView: View {
    /// Instance View Model pengolah data pose tarian
    @StateObject private var analyzer = PoseAnalyzer()
    
    // Parameter URL video yang diteruskan dari layar UploadView
    var coachURL: URL? = nil
    var userURL: URL? = nil
    var labelCoach: String = "Coach (Reference: dance_coach2.mp4)"
    var labelUser: String = "User (Dance: dance_user2.mp4)"
    
    var body: some View {
        ZStack {
            // Latar belakang native iOS
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                
                // MARK: - 1. Banner Evaluasi Kesalahan (Movement Reflection Banner)
                if analyzer.isPausedOnError {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .symbolRenderingMode(.multicolor)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Movement Reflection")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.white)
                            Text(analyzer.pesanSpesifik)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.95))
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color.red.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.red.opacity(0.25), radius: 6, y: 3)
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // MARK: - 2. Dua Pemutar Video Berdampingan (Coach di Kiri, User di Kanan)
                HStack(spacing: 12) {
                    // Video Kiri (Referensi Pelatih / Coach)
                    KotakVideo(
                        player: analyzer.coachPlayer,
                        joints: analyzer.coachJoints,
                        bagianSalah: [],
                        label: labelCoach
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Video Kanan (Latihan Pengguna / User)
                    KotakVideo(
                        player: analyzer.userPlayer,
                        joints: analyzer.userJoints,
                        bagianSalah: analyzer.bagianSalah,
                        label: labelUser
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // MARK: - 3. Baris Timeline Checkpoint Kesalahan
                if !analyzer.checkpoints.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(analyzer.checkpoints) { cp in
                                    Button(action: {
                                        analyzer.lompatKeCheckpoint(cp)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "flag.fill")
                                                .foregroundColor(analyzer.activeCheckpoint == cp ? .white : .red)
                                                .font(.caption2)
                                            Text(cp.timeFormatted)
                                                .fontWeight(.semibold)
                                            Text("(\(Array(cp.bagianSalah).joined(separator: ", ")))")
                                        }
                                        .font(.caption2)
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 10)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(analyzer.activeCheckpoint == cp ? .red : .secondary)
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }
                
                // MARK: - 4. Tombol Kontrol Bawah (Replay & Next)
                HStack(spacing: 12) {
                    // Tombol Putar Ulang (Replay Video)
                    Button(action: {
                        analyzer.replayVideo()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Replay Video")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .controlSize(.regular)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    // Tombol Lanjutkan Tarian (Continue Next) saat video terhenti di error
                    if analyzer.isPausedOnError {
                        Button(action: {
                            analyzer.lanjutkanVideo()
                        }) {
                            HStack(spacing: 8) {
                                Text("Continue Dance (Next)")
                                    .font(.headline)
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title3)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: analyzer.isPausedOnError)
        .navigationTitle("Pose Comparison")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let cURL = coachURL, let uURL = userURL {
                analyzer.mulaiMemutarVideo(urlCoach: cURL, urlUser: uURL)
            } else {
                analyzer.mulaiMemutarVideo(namaCoach: "dance_coach2", namaUser: "dance_user2")
            }
        }
        .onDisappear {
            analyzer.hentikanVideo()
        }
    }
}

#Preview {
    NavigationStack {
        ContentView()
    }
}
