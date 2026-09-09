//
//  VideoHelper.swift
//  C4-Vision
//
//  Created by Sharon Tan on 02/09/26.
//

import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - Helper Utilitas Pemrosesan Video (VideoHelper)
/// Kumpulan fungsi utilitas statis untuk memproses berkas video:
/// 1. Mengambil gambar thumbnail (poster frame) secara async.
/// 2. Menghitung durasi video dalam format menit:detik.
/// 3. Menyalin video dari PhotosPicker (Galeri) atau File App ke folder sementara (`temporaryDirectory`).
class VideoHelper {
    
    // MARK: - 1. Pembuatan Thumbnail Video
    
    /// Mengambil gambar thumbnail dari frame awal video pada detik ke-0.5
    /// - Parameter url: URL file video lokal
    /// - Returns: `UIImage` pratinjau thumbnail, atau `nil` jika gagal diekstrak
    static func generateThumbnail(for url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            // Fallback: jika frame detik 0.5 gagal, coba ambil at .zero
            do {
                let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                return UIImage(cgImage: cgImage)
            } catch {
                print("Gagal generate thumbnail: \(error.localizedDescription)")
                return nil
            }
        }
    }
    
    // MARK: - 2. Perhitungan Durasi Video
    
    /// Menghitung total durasi video dan mengonversinya ke format string "mm:ss"
    /// - Parameter url: URL file video
    /// - Returns: String durasi terformat (contoh: "01:25")
    static func getDurationString(for url: URL) async -> String {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            if seconds.isNaN || seconds.isInfinite { return "00:00" }
            let mins = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return String(format: "%02d:%02d", mins, secs)
        } catch {
            return "00:00"
        }
    }
    
    // MARK: - 3. Penyimpanan Video dari PhotosPicker ke Temp
    
    /// Menyalin data video dari PhotosPickerItem ke file lokal sementara di direktori temporary
    /// - Parameter item: Objek `PhotosPickerItem` yang dipilih pengguna dari galeri
    /// - Returns: URL file video lokal yang tersimpan di disk
    static func savePhotosPickerItemToTemp(item: PhotosPickerItem) async -> URL? {
        do {
            guard let movieData = try await item.loadTransferable(type: Data.self) else {
                return nil
            }
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "picker_\(UUID().uuidString).mp4"
            let destinationURL = tempDir.appendingPathComponent(fileName)
            
            // Tulis data biner video ke disk
            try movieData.write(to: destinationURL)
            return destinationURL
        } catch {
            print("Gagal menyimpan video dari galeri: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 4. Penyalinan File Dokumen / Kamera ke Temp
    
    /// Menyalin file dari URL dokumen berizin (Security Scoped) ke direktori sementara aplikasi
    /// - Parameters:
    ///   - sourceURL: URL asal file
    ///   - prefix: Awalan nama file baru
    /// - Returns: URL file lokal sementara
    static func copyToTemp(from sourceURL: URL, prefix: String = "video") -> URL? {
        let isSecured = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isSecured {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let ext = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension
        let fileName = "\(prefix)_\(UUID().uuidString).\(ext)"
        let destinationURL = tempDir.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            print("Gagal menyalin file video: \(error.localizedDescription)")
            return sourceURL // Fallback gunakan sourceURL asli jika penyalinan gagal
        }
    }
    
    // MARK: - 5. Factory Method Pembuatan SelectedVideoItem
    
    /// Membuat objek `SelectedVideoItem` lengkap dengan perhitungan durasi dan pembuatan thumbnail otomatis secara asinkron
    /// - Parameters:
    ///   - url: URL file video
    ///   - title: Nama judul video
    ///   - sourceType: Tipe sumber video
    /// - Returns: Objek `SelectedVideoItem` yang siap ditampilkan di UI
    static func createVideoItem(url: URL, title: String, sourceType: VideoSourceType) async -> SelectedVideoItem {
        let thumb = await generateThumbnail(for: url)
        let dur = await getDurationString(for: url)
        return SelectedVideoItem(
            url: url,
            title: title,
            durationFormatted: dur,
            thumbnail: thumb,
            sourceType: sourceType
        )
    }
}
