//
//  UploadView.swift
//  C4-Vision
//
//  Created by Sharon Tan on 02/09/26.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Halaman Upload & Pemilihan Video (Native Menu & Context Menu HIG)
struct UploadView: View {
    // MARK: - State Video Terpilih
    @State private var selectedCoach: SelectedVideoItem? = nil
    @State private var selectedUser: SelectedVideoItem? = nil
    
    // State Loading
    @State private var isLoadingCoach: Bool = false
    @State private var isLoadingUser: Bool = false
    
    // PhotosPicker States
    @State private var coachPickerItem: PhotosPickerItem? = nil
    @State private var userPickerItem: PhotosPickerItem? = nil
    @State private var showCoachPhotosPicker: Bool = false
    @State private var showUserPhotosPicker: Bool = false
    
    // Camera Recorder State
    @State private var showCameraRecorder: Bool = false
    
    // File Importer States
    @State private var showCoachFileImporter: Bool = false
    @State private var showUserFileImporter: Bool = false
    
    // Navigation State
    @State private var navigateToComparison: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background Native iOS Inset Grouped
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // MARK: - 1. Dua Kotak Upload Berdampingan dengan Menu & Context Menu
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PILIH SUMBER VIDEO")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                            
                            HStack(alignment: .top, spacing: 14) {
                                // KOTAK 1: REFERENCE (COACH)
                                KotakUploadHIG(
                                    label: "REFERENCE",
                                    sublabel: "Video Acuan (Coach)",
                                    systemIcon: "person.badge.shield.checkmark.fill",
                                    accentColor: .blue,
                                    videoItem: selectedCoach,
                                    isLoading: isLoadingCoach,
                                    onRemove: {
                                        selectedCoach = nil
                                        coachPickerItem = nil
                                    }
                                ) {
                                    menuOpsiCoach
                                }
                                
                                // KOTAK 2: UPLOAD / RECORD (USER)
                                KotakUploadHIG(
                                    label: "UPLOAD / RECORD",
                                    sublabel: "Video Latihan (User)",
                                    systemIcon: "video.fill.badge.plus",
                                    accentColor: .purple,
                                    videoItem: selectedUser,
                                    isLoading: isLoadingUser,
                                    onRemove: {
                                        selectedUser = nil
                                        userPickerItem = nil
                                    }
                                ) {
                                    menuOpsiUser
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        
                        // MARK: - 2. Quick Demo Shortcut
                        Button(action: muatPresetDemo) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.yellow, .blue)
                                Text("Muat Contoh Preset Cepat (Coach 2 & User 2)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 12))
                        .tint(.primary)
                        .padding(.horizontal, 16)
                        
                        // MARK: - 3. Kartu Informasi Panduan (Native HIG Callout Card)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb.max.fill")
                                    .foregroundColor(.orange)
                                    .font(.subheadline)
                                Text("Panduan Deteksi Pose")
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                PetunjukItemHIG(icon: "figure.walk", teks: "Pastikan seluruh tubuh penari (kepala sampai kaki) berada di dalam frame.")
                                PetunjukItemHIG(icon: "sun.max.fill", teks: "Gunakan pencahayaan yang cukup agar titik sendi mudah terdeteksi.")
                                PetunjukItemHIG(icon: "iphone.gen3", teks: "Posisi rekaman vertikal (Portrait 9:16) direkomendasikan.")
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 16)
                        
                        // MARK: - 4. Tombol Utama (Primary Prominent Action HIG)
                        Button(action: {
                            if selectedCoach != nil && selectedUser != nil {
                                navigateToComparison = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                                Text("Mulai Perbandingan Video")
                                    .font(.headline)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .tint(.blue)
                        .disabled(selectedCoach == nil || selectedUser == nil)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 24)
                    }
                    .frame(maxWidth: 920)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Upload Video")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("Preset Cepat") {
                            Button(action: muatPresetDemo) {
                                Label("Coach 2 & User 2 (Rekomendasi)", systemImage: "bolt.fill")
                            }
                            Button(action: muatPresetDemo1) {
                                Label("Coach 1 & User 1", systemImage: "figure.dance")
                            }
                        }
                    } label: {
                        Label("Preset", systemImage: "sparkles")
                    }
                }
            }
            
            // MARK: - Navigation Destination ke ContentView
            .navigationDestination(isPresented: $navigateToComparison) {
                if let coach = selectedCoach, let user = selectedUser {
                    ContentView(
                        coachURL: coach.url,
                        userURL: user.url,
                        labelCoach: "Coach: \(coach.title)",
                        labelUser: "User: \(user.title)"
                    )
                }
            }
            
            // MARK: - Photos Picker Sheets
            .photosPicker(isPresented: $showCoachPhotosPicker, selection: $coachPickerItem, matching: .videos)
            .onChange(of: coachPickerItem) { _, newItem in
                if let item = newItem {
                    prosesPhotosPickerCoach(item: item)
                }
            }
            .photosPicker(isPresented: $showUserPhotosPicker, selection: $userPickerItem, matching: .videos)
            .onChange(of: userPickerItem) { _, newItem in
                if let item = newItem {
                    prosesPhotosPickerUser(item: item)
                }
            }
            
            // MARK: - Camera Recorder FullScreen
            .fullScreenCover(isPresented: $showCameraRecorder) {
                CameraVideoRecorder { recordedURL in
                    prosesRekamanKamera(url: recordedURL)
                }
                .ignoresSafeArea()
            }
            
            // MARK: - File Importers
            .fileImporter(
                isPresented: $showCoachFileImporter,
                allowedContentTypes: [.movie, .quickTimeMovie, .mpeg4Movie],
                allowsMultipleSelection: false
            ) { result in
                prosesFileImporterCoach(result: result)
            }
            .fileImporter(
                isPresented: $showUserFileImporter,
                allowedContentTypes: [.movie, .quickTimeMovie, .mpeg4Movie],
                allowsMultipleSelection: false
            ) { result in
                prosesFileImporterUser(result: result)
            }
        }
    }
    
    // MARK: - Menu Opsi Video Coach (Reference)
    @ViewBuilder
    private var menuOpsiCoach: some View {
        Section("Pilih Video Acuan") {
            Button {
                showCoachPhotosPicker = true
            } label: {
                Label("Pilih dari Galeri Foto", systemImage: "photo.on.rectangle")
            }
            
            Button {
                showCoachFileImporter = true
            } label: {
                Label("Pilih dari File Dokumen", systemImage: "folder")
            }
        }
        
        Section("Contoh Video Coach") {
            Button {
                muatVideoBundleCoach(nama: "dance_coach2")
            } label: {
                Label("dance_coach2.mp4 (Rekomendasi)", systemImage: "figure.dance")
            }
            
            Button {
                muatVideoBundleCoach(nama: "dance_coach")
            } label: {
                Label("dance_coach.mp4", systemImage: "film")
            }
        }
    }
    
    // MARK: - Menu Opsi Video User (Upload / Record)
    @ViewBuilder
    private var menuOpsiUser: some View {
        Section("Input Video Tarian") {
            Button {
                showCameraRecorder = true
            } label: {
                Label("Rekam Kamera Langsung", systemImage: "camera")
            }
            
            Button {
                showUserPhotosPicker = true
            } label: {
                Label("Pilih dari Galeri Foto", systemImage: "photo.on.rectangle")
            }
            
            Button {
                showUserFileImporter = true
            } label: {
                Label("Pilih dari File Dokumen", systemImage: "folder")
            }
        }
        
        Section("Contoh Video User") {
            Button {
                muatVideoBundleUser(nama: "dance_user2")
            } label: {
                Label("dance_user2.mp4 (Rekomendasi)", systemImage: "figure.dance")
            }
            
            Button {
                muatVideoBundleUser(nama: "dance_user")
            } label: {
                Label("dance_user.mp4", systemImage: "film")
            }
        }
    }
    
    // MARK: - Helper Pengolahan Data Video
    
    private func muatPresetDemo() {
        muatVideoBundleCoach(nama: "dance_coach2")
        muatVideoBundleUser(nama: "dance_user2")
    }
    
    private func muatPresetDemo1() {
        muatVideoBundleCoach(nama: "dance_coach")
        muatVideoBundleUser(nama: "dance_user")
    }
    
    private func muatVideoBundleCoach(nama: String) {
        guard let url = Bundle.main.url(forResource: nama, withExtension: "mp4") else { return }
        isLoadingCoach = true
        Task {
            let item = await VideoHelper.createVideoItem(url: url, title: "\(nama).mp4", sourceType: .preset)
            await MainActor.run {
                self.selectedCoach = item
                self.isLoadingCoach = false
                self.coachPickerItem = nil
            }
        }
    }
    
    private func muatVideoBundleUser(nama: String) {
        guard let url = Bundle.main.url(forResource: nama, withExtension: "mp4") else { return }
        isLoadingUser = true
        Task {
            let item = await VideoHelper.createVideoItem(url: url, title: "\(nama).mp4", sourceType: .preset)
            await MainActor.run {
                self.selectedUser = item
                self.isLoadingUser = false
                self.userPickerItem = nil
            }
        }
    }
    
    private func prosesPhotosPickerCoach(item: PhotosPickerItem) {
        isLoadingCoach = true
        Task {
            if let savedURL = await VideoHelper.savePhotosPickerItemToTemp(item: item) {
                let videoItem = await VideoHelper.createVideoItem(url: savedURL, title: "Galeri Coach", sourceType: .photoLibrary)
                await MainActor.run {
                    self.selectedCoach = videoItem
                    self.isLoadingCoach = false
                    self.coachPickerItem = nil
                }
            } else {
                await MainActor.run {
                    self.isLoadingCoach = false
                    self.coachPickerItem = nil
                }
            }
        }
    }
    
    private func prosesPhotosPickerUser(item: PhotosPickerItem) {
        isLoadingUser = true
        Task {
            if let savedURL = await VideoHelper.savePhotosPickerItemToTemp(item: item) {
                let videoItem = await VideoHelper.createVideoItem(url: savedURL, title: "Galeri User", sourceType: .photoLibrary)
                await MainActor.run {
                    self.selectedUser = videoItem
                    self.isLoadingUser = false
                    self.userPickerItem = nil
                }
            } else {
                await MainActor.run {
                    self.isLoadingUser = false
                    self.userPickerItem = nil
                }
            }
        }
    }
    
    private func prosesRekamanKamera(url: URL) {
        isLoadingUser = true
        Task {
            if let localURL = VideoHelper.copyToTemp(from: url, prefix: "camera_record") {
                let videoItem = await VideoHelper.createVideoItem(url: localURL, title: "Rekaman Kamera", sourceType: .cameraRecord)
                await MainActor.run {
                    self.selectedUser = videoItem
                    self.isLoadingUser = false
                    self.userPickerItem = nil
                }
            } else {
                await MainActor.run {
                    self.isLoadingUser = false
                    self.userPickerItem = nil
                }
            }
        }
    }
    
    private func prosesFileImporterCoach(result: Result<[URL], Error>) {
        if case .success(let urls) = result, let firstURL = urls.first {
            isLoadingCoach = true
            Task {
                if let localURL = VideoHelper.copyToTemp(from: firstURL, prefix: "coach_file") {
                    let videoItem = await VideoHelper.createVideoItem(url: localURL, title: firstURL.lastPathComponent, sourceType: .file)
                    await MainActor.run {
                        self.selectedCoach = videoItem
                        self.isLoadingCoach = false
                        self.coachPickerItem = nil
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingCoach = false
                        self.coachPickerItem = nil
                    }
                }
            }
        }
    }
    
    private func prosesFileImporterUser(result: Result<[URL], Error>) {
        if case .success(let urls) = result, let firstURL = urls.first {
            isLoadingUser = true
            Task {
                if let localURL = VideoHelper.copyToTemp(from: firstURL, prefix: "user_file") {
                    let videoItem = await VideoHelper.createVideoItem(url: localURL, title: firstURL.lastPathComponent, sourceType: .file)
                    await MainActor.run {
                        self.selectedUser = videoItem
                        self.isLoadingUser = false
                        self.userPickerItem = nil
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingUser = false
                        self.userPickerItem = nil
                    }
                }
            }
        }
    }
}

// MARK: - Komponen Kotak Upload Native HIG dengan Menu & Context Menu
struct KotakUploadHIG<MenuContent: View>: View {
    let label: String
    let sublabel: String
    let systemIcon: String
    let accentColor: Color
    let videoItem: SelectedVideoItem?
    let isLoading: Bool
    let onRemove: () -> Void
    @ViewBuilder let menuContent: () -> MenuContent
    
    var body: some View {
        VStack(spacing: 8) {
            // Label Header Atas ("reference" & "upload/record")
            VStack(spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(sublabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Kotak Kontainer Card
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                
                if isLoading {
                    // Loading State
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.regular)
                        Text("Memuat video...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let video = videoItem {
                    // State Video Terpilih
                    GeometryReader { geo in
                        ZStack(alignment: .topTrailing) {
                            if let thumb = video.thumbnail {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            } else {
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
                            
                            // Gradients untuk keterbacaan teks/tombol
                            VStack {
                                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                                    .frame(height: 48)
                                Spacer()
                                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                                    .frame(height: 52)
                            }
                            
                            // Badge Durasi & Status Siap di Bawah
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
                            
                            // Tombol Hapus Native di Sudut Atas
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
                } else {
                    // State Kosong: Membuka Menu Picker saat Ditekan
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
                                Text("Pilih Video")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Text("Ketuk untuk menu")
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        videoItem != nil ? Color.green.opacity(0.7) : Color(uiColor: .separator).opacity(0.6),
                        style: StrokeStyle(lineWidth: videoItem != nil ? 2 : 1.2, dash: videoItem == nil ? [6, 4] : [])
                    )
            )
            // MARK: - Native iOS Context Menu (Tekan & Tahan / Long-Press)
            .contextMenu {
                menuContent()
                if videoItem != nil {
                    Divider()
                    Button(role: .destructive, action: onRemove) {
                        Label("Hapus Video", systemImage: "trash")
                    }
                }
            }
            
            // Detail Nama Video & Tombol Ganti Video Native HIG (Menu)
            if let video = videoItem {
                VStack(spacing: 2) {
                    Text(video.title)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Menu {
                        menuContent()
                    } label: {
                        Label("Ganti Video", systemImage: "arrow.triangle.2.circlepath")
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

// MARK: - Baris Panduan HIG
struct PetunjukItemHIG: View {
    let icon: String
    let teks: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(.blue)
                .frame(width: 16)
                .padding(.top, 1)
            Text(teks)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    UploadView()
}
