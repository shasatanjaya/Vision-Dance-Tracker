//
//  SelectedVideoItem.swift
//  C4-Vision
//
//  Created by Sharon Tan on 03/09/26.
//

import SwiftUI

// MARK: - Jenis Sumber Video (Video Source Type)
/// Enum yang merepresentasikan asal muasal video yang dipilih oleh pengguna.
enum VideoSourceType: String {
    /// Video contoh bawaan yang sudah ada di dalam bundle aplikasi (misal: dance_coach2.mp4)
    case preset = "Contoh Bawaan"
    
    /// Video yang dipilih dari galeri foto perangkat pengguna (Photos Picker)
    case photoLibrary = "Galeri Foto"
    
    /// Video yang baru saja direkam langsung menggunakan fitur kamera aplikasi
    case cameraRecord = "Rekaman Kamera"
    
    /// Video yang diimpor dari file dokumen perangkat (Files / iCloud Drive)
    case file = "File Dokumen"
}

// MARK: - Model Data Video Terpilih (Selected Video Item)
/// Model data untuk menampung informasi lengkap mengenai video yang telah dipilih / diunggah.
/// Termasuk URL file, judul video, durasi yang sudah diformat, gambar thumbnail pratinjau, dan tipe sumbernya.
struct SelectedVideoItem: Identifiable, Equatable {
    /// ID unik untuk setiap item video
    let id: UUID = UUID()
    
    /// URL lokasi file video (bisa di Bundle, Temp Directory, atau App Storage)
    let url: URL
    
    /// Nama atau judul video yang ditampilkan ke pengguna
    let title: String
    
    /// Teks durasi video dalam format menit:detik (contoh: "00:30")
    var durationFormatted: String = "00:00"
    
    /// Gambar pratinjau (thumbnail) dari frame awal video
    var thumbnail: UIImage? = nil
    
    /// Jenis sumber asal video (Preset, Galeri, Kamera, atau File)
    let sourceType: VideoSourceType
    
    /// Protokol kesamaan Equatable berdasarkan ID dan URL file
    static func == (lhs: SelectedVideoItem, rhs: SelectedVideoItem) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}
