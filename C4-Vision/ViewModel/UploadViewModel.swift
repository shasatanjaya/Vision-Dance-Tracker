//
//  UploadViewModel.swift
//  C4-Vision
//
//  Created by Sharon Tan on 03/09/26.
//

import SwiftUI
import PhotosUI
import Combine

// MARK: - View Model Pemilihan & Pengunggahan Video (UploadViewModel)
/// Mengelola seluruh state dan logika alur pemilihan/pengunggahan video:
/// 1. Menyimpan data item video Coach dan User yang dipilih (`SelectedVideoItem`).
/// 2. Menangani pemuatan video dari preset bundle demo, PhotosPicker (Galeri), Dokumen (Files App), dan Rekaman Kamera.
/// 3. Mengontrol status indikator loading saat video diproses di latar belakang.
@MainActor
class UploadViewModel: ObservableObject {
    
    // MARK: - State Video yang Terpilih
    @Published var selectedCoach: SelectedVideoItem? = nil
    @Published var selectedUser: SelectedVideoItem? = nil
    
    // MARK: - State Loading Pemrosesan Video
    @Published var isLoadingCoach: Bool = false
    @Published var isLoadingUser: Bool = false
    
    // MARK: - State PhotosPicker (Galeri Foto)
    @Published var coachPickerItem: PhotosPickerItem? = nil
    @Published var userPickerItem: PhotosPickerItem? = nil
    @Published var showCoachPhotosPicker: Bool = false
    @Published var showUserPhotosPicker: Bool = false
    
    // MARK: - State Perekam Kamera & Peringatan
    @Published var showCameraRecorder: Bool = false
    @Published var showMustSelectCoachAlert: Bool = false
    
    // MARK: - State File Importer (Aplikasi Files / iCloud)
    @Published var showCoachFileImporter: Bool = false
    @Published var showUserFileImporter: Bool = false
    
    // MARK: - State Navigasi
    @Published var navigateToComparison: Bool = false
    
    // MARK: - Computed Properties
    
    /// Memeriksa apakah kedua video (Coach & User) sudah siap untuk memulai perbandingan
    var canStartComparison: Bool {
        selectedCoach != nil && selectedUser != nil
    }
    
    /// Mengindikasikan apakah bagian pemilihan video User masih terkunci (karena belum memilih Coach)
    var isUserSectionLocked: Bool {
        selectedCoach == nil
    }
    
    // MARK: - Reset Actions
    
    /// Menghapus video Coach yang terpilih
    func removeCoach() {
        selectedCoach = nil
        coachPickerItem = nil
    }
    
    /// Menghapus video User yang terpilih
    func removeUser() {
        selectedUser = nil
        userPickerItem = nil
    }
    
    // MARK: - 1. Pemuatan Preset Demo
    
    /// Memuat preset video demo cepat (Coach 2 & User 2)
    func muatPresetDemo() {
        muatVideoBundleCoach(nama: "dance_coach2")
        muatVideoBundleUser(nama: "dance_user2")
    }
    
    /// Memuat preset video demo alternatif (Coach 1 & User 1)
    func muatPresetDemo1() {
        muatVideoBundleCoach(nama: "dance_coach")
        muatVideoBundleUser(nama: "dance_user")
    }
    
    /// Memuat video Coach dari bundle aplikasi berdasarkan nama file
    func muatVideoBundleCoach(nama: String) {
        guard let url = Bundle.main.url(forResource: nama, withExtension: "mp4") else { return }
        isLoadingCoach = true
        Task {
            let item = await VideoHelper.createVideoItem(url: url, title: "\(nama).mp4", sourceType: .preset)
            self.selectedCoach = item
            self.isLoadingCoach = false
            self.coachPickerItem = nil
        }
    }
    
    /// Memuat video User dari bundle aplikasi berdasarkan nama file
    func muatVideoBundleUser(nama: String) {
        guard let url = Bundle.main.url(forResource: nama, withExtension: "mp4") else { return }
        isLoadingUser = true
        Task {
            let item = await VideoHelper.createVideoItem(url: url, title: "\(nama).mp4", sourceType: .preset)
            self.selectedUser = item
            self.isLoadingUser = false
            self.userPickerItem = nil
        }
    }
    
    // MARK: - 2. Pemrosesan PhotosPicker (Galeri)
    
    /// Memproses video Coach yang dipilih dari galeri foto
    func prosesPhotosPickerCoach(item: PhotosPickerItem) {
        isLoadingCoach = true
        Task {
            if let savedURL = await VideoHelper.savePhotosPickerItemToTemp(item: item) {
                let videoItem = await VideoHelper.createVideoItem(url: savedURL, title: "Coach Library", sourceType: .photoLibrary)
                self.selectedCoach = videoItem
                self.isLoadingCoach = false
                self.coachPickerItem = nil
            } else {
                self.isLoadingCoach = false
                self.coachPickerItem = nil
            }
        }
    }
    
    /// Memproses video User yang dipilih dari galeri foto
    func prosesPhotosPickerUser(item: PhotosPickerItem) {
        isLoadingUser = true
        Task {
            if let savedURL = await VideoHelper.savePhotosPickerItemToTemp(item: item) {
                let videoItem = await VideoHelper.createVideoItem(url: savedURL, title: "User Library", sourceType: .photoLibrary)
                self.selectedUser = videoItem
                self.isLoadingUser = false
                self.userPickerItem = nil
            } else {
                self.isLoadingUser = false
                self.userPickerItem = nil
            }
        }
    }
    
    // MARK: - 3. Pemrosesan Rekaman Kamera
    
    /// Memproses video hasil rekaman kamera tarian langsung
    func prosesRekamanKamera(url: URL) {
        isLoadingUser = true
        Task {
            if let localURL = VideoHelper.copyToTemp(from: url, prefix: "camera_record") {
                let videoItem = await VideoHelper.createVideoItem(url: localURL, title: "Camera Recording", sourceType: .cameraRecord)
                self.selectedUser = videoItem
                self.isLoadingUser = false
                self.userPickerItem = nil
            } else {
                self.isLoadingUser = false
                self.userPickerItem = nil
            }
        }
    }
    
    // MARK: - 4. Pemrosesan File Importer (Dokumen / Files)
    
    /// Memproses file video Coach yang diimpor dari Files App
    func prosesFileImporterCoach(result: Result<[URL], Error>) {
        if case .success(let urls) = result, let firstURL = urls.first {
            isLoadingCoach = true
            Task {
                if let localURL = VideoHelper.copyToTemp(from: firstURL, prefix: "coach_file") {
                    let videoItem = await VideoHelper.createVideoItem(url: localURL, title: firstURL.lastPathComponent, sourceType: .file)
                    self.selectedCoach = videoItem
                    self.isLoadingCoach = false
                    self.coachPickerItem = nil
                } else {
                    self.isLoadingCoach = false
                    self.coachPickerItem = nil
                }
            }
        }
    }
    
    /// Memproses file video User yang diimpor dari Files App
    func prosesFileImporterUser(result: Result<[URL], Error>) {
        if case .success(let urls) = result, let firstURL = urls.first {
            isLoadingUser = true
            Task {
                if let localURL = VideoHelper.copyToTemp(from: firstURL, prefix: "user_file") {
                    let videoItem = await VideoHelper.createVideoItem(url: localURL, title: firstURL.lastPathComponent, sourceType: .file)
                    self.selectedUser = videoItem
                    self.isLoadingUser = false
                    self.userPickerItem = nil
                } else {
                    self.isLoadingUser = false
                    self.userPickerItem = nil
                }
            }
        }
    }
}
