//
//  VideoHelper.swift
//  C4-Vision
//
//  Created by Sharon Tan on 02/09/26.
//

import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - Sumber Video
enum VideoSourceType: String {
    case preset = "Contoh Bawaan"
    case photoLibrary = "Galeri Foto"
    case cameraRecord = "Rekaman Kamera"
    case file = "File Dokumen"
}

// MARK: - Model Data Video Terpilih
struct SelectedVideoItem: Identifiable, Equatable {
    let id: UUID = UUID()
    let url: URL
    let title: String
    var durationFormatted: String = "00:00"
    var thumbnail: UIImage? = nil
    let sourceType: VideoSourceType
    
    static func == (lhs: SelectedVideoItem, rhs: SelectedVideoItem) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}

// MARK: - Helper Utilitas Video
class VideoHelper {
    
    /// Mengambil thumbnail frame pertama dari file video URL
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
            // Coba ambil at .zero jika detik 0.5 gagal
            do {
                let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                return UIImage(cgImage: cgImage)
            } catch {
                print("Gagal generate thumbnail: \(error.localizedDescription)")
                return nil
            }
        }
    }
    
    /// Menghitung durasi video dalam format mm:ss
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
    
    /// Menyalin file video dari PhotosPickerItem ke file lokal sementara di temporaryDirectory
    static func savePhotosPickerItemToTemp(item: PhotosPickerItem) async -> URL? {
        do {
            // Load file sebagai Data atau file transfer
            guard let movieData = try await item.loadTransferable(type: Data.self) else {
                return nil
            }
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "picker_\(UUID().uuidString).mp4"
            let destinationURL = tempDir.appendingPathComponent(fileName)
            
            // Tulis data ke file lokal sementara
            try movieData.write(to: destinationURL)
            return destinationURL
        } catch {
            print("Gagal menyimpan video dari galeri: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Menyalin URL dari file dokumen / rekaman kamera ke temporary directory
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
            return sourceURL // Fallback gunakan sourceURL asli jika copy gagal
        }
    }
    
    /// Membuat instance `SelectedVideoItem` lengkap dengan thumbnail dan durasi secara async
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
