//
//  KotakUploadHIG.swift
//  C4-Vision
//
//  Created by Sharon Tan on 03/09/26.
//

import SwiftUI

// MARK: - Komponen Kartu Unggah Video HIG (KotakUploadHIG)
/// Komponen kartu pilihan / pratinjau video modern yang mengikuti standar Apple Human Interface Guidelines (HIG).
///
/// Fitur Utama:
/// 1. **Step Badge & Header**: Menunjukkan nomor langkah (Step 1 / Step 2) dan nama slot (Reference / User).
/// 2. **State Locked / Disabled**: Jika video Coach belum dipilih, kartu User otomatis terkunci dengan ikon gembok.
/// 3. **State Loading**: Menampilkan indikator loading saat video sedang diproses dari galeri/file.
/// 4. **State Video Terpilih**: Menampilkan gambar thumbnail, durasi video (mm:ss), badge checklist hijau, dan tombol hapus (X).
/// 5. **State Kosong (Active)**: Menampilkan tombol plus interaktif yang membuka menu opsi sumber video saat diketuk.
/// 6. **Context Menu**: Pengguna bisa menekan lama (long press) pada kartu untuk mengakses menu ganti atau hapus video.
struct KotakUploadHIG<MenuContent: View>: View {
    /// Nomor urut langkah ("1" untuk Coach, "2" untuk User)
    let stepNumber: String
    
    /// Label utama kartu (misal: "REFERENCE" atau "UPLOAD / RECORD")
    let label: String
    
    /// Label sekunder / keterangan (misal: "Coach Video (Reference)" atau "Select Coach First")
    let sublabel: String
    
    /// Nama ikon SF Symbol untuk identitas kartu
    let systemIcon: String
    
    /// Warna aksen kartu (Biru untuk Coach, Ungu untuk User)
    let accentColor: Color
    
    /// Objek data video yang dipilih (nil jika belum ada video yang dipilih)
    let videoItem: SelectedVideoItem?
    
    /// Status apakah video sedang dalam proses loading / kompresi
    let isLoading: Bool
    
    /// Status apakah kartu ini terkunci (disable)
    let isLocked: Bool
    
    /// Callback closure yang dipanggil saat pengguna menekan tombol hapus (X)
    let onRemove: () -> Void
    
    /// Closure ViewBuilder untuk menampilkan isi Menu opsi pemilihan video
    @ViewBuilder let menuContent: () -> MenuContent
    
    var body: some View {
        VStack(spacing: 8) {
            // MARK: - 1. Bagian Header Kartu (Badge Langkah & Label)
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    // Badge Kapsul Langkah (Step Badge)
                    Text("STEP \(stepNumber)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(isLocked ? Color.secondary.opacity(0.15) : accentColor.opacity(0.15))
                        .foregroundColor(isLocked ? .secondary : accentColor)
                        .clipShape(Capsule())
                    
                    // Judul Slot
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(isLocked ? .secondary : .primary)
                }
                
                // Subjudul / Deskripsi Pendek
                Text(sublabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // MARK: - 2. Kontainer Utama Kartu
            ZStack {
                // Latar Belakang Kartu
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .opacity(isLocked ? 0.6 : 1.0)
                
                if isLoading {
                    // Tampilan Saat Loading Video
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.regular)
                        Text("Loading video...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let video = videoItem {
                    // Tampilan Saat Video Sudah Berhasil Dipilih
                    GeometryReader { geo in
                        ZStack(alignment: .topTrailing) {
                            // Gambar Thumbnail Video
                            if let thumb = video.thumbnail {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            } else {
                                // Fallback jika thumbnail tidak tersedia
                                VStack(spacing: 6) {
                                    Image(systemName: "film.fill")
                                        .font(.title)
                                        .foregroundColor(.blue)
                                    Text(video.title)
                                        .font(.caption2)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 4)
                                }
                                .frame(width: geo.size.width, height: geo.size.height)
                            }
                            
                            // Gradien Hitam Halus untuk Kejelasan Teks & Ikon
                            VStack {
                                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                                    .frame(height: 48)
                                Spacer()
                                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                                    .frame(height: 52)
                            }
                            
                            // Badge Durasi & Checklist Hijau di Bawah Kartu
                            VStack {
                                Spacer()
                                HStack {
                                    Label(video.durationFormatted, systemImage: "clock.fill")
                                        .font(.caption2.weight(.bold))
                                        .foregroundColor(.white)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                    
                                    Spacer()
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .symbolRenderingMode(.multicolor)
                                        .font(.subheadline)
                                }
                                .padding(10)
                            }
                            
                            // Tombol Hapus (X) di Pojok Kanan Atas
                            Button(action: onRemove) {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .padding(8)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else if isLocked {
                    // Tampilan Saat Terkunci (Perlu pilih Coach terlebih dahulu)
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.secondary.opacity(0.12))
                                .frame(width: 54, height: 54)
                            
                            Image(systemName: "lock.fill")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 2) {
                            Text("Locked")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.secondary)
                            Text("Select Step 1 first")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Tampilan Kosong & Aktif: Pengguna mengetuk kartu untuk memunculkan Menu Pilihan
                    Menu {
                        menuContent()
                    } label: {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(accentColor.opacity(0.12))
                                    .frame(width: 54, height: 54)
                                
                                Image(systemName: "plus")
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(accentColor)
                            }
                            
                            VStack(spacing: 2) {
                                Text("Select Video")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Text("Tap for options")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                // Garis Pinggir Kartu (Border Garis Putus-putus atau Solid Hijau)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        videoItem != nil ? Color.green.opacity(0.7) : (isLocked ? Color.secondary.opacity(0.3) : Color(uiColor: .separator).opacity(0.6)),
                        style: StrokeStyle(lineWidth: videoItem != nil ? 2 : 1.2, dash: videoItem == nil ? [6, 4] : [])
                    )
            )
            // Context Menu saat kartu ditekan lama (Long Press)
            .contextMenu {
                if !isLocked {
                    menuContent()
                    if videoItem != nil {
                        Divider()
                        Button(role: .destructive, action: onRemove) {
                            Label("Remove Video", systemImage: "trash")
                        }
                    }
                }
            }
            
            // MARK: - 3. Keterangan Nama File & Tombol Ganti Video
            if let video = videoItem {
                VStack(spacing: 2) {
                    Text(video.title)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Menu {
                        menuContent()
                    } label: {
                        Label("Change Video", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption2.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    .tint(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
