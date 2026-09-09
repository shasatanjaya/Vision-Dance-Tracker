//
//  UploadView.swift
//  C4-Vision
//
//  Created by Sharon Tan on 02/09/26.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Layar Pemilihan & Perekaman Video Tarian (UploadView)
/// Layar utama alur awal aplikasi untuk memilih video acuan (Coach) dan video tarian pengguna (User).
///
/// Menggunakan arsitektur **MVVM** di mana seluruh state dan logika pemilih
// an video
/// didelegasikan ke `UploadViewModel`.
struct UploadView: View {
    
    // MARK: - View Model (MVVM)
    @StateObject private var viewModel = UploadViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background native iOS Inset Grouped
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // MARK: - 1. Kartu Petunjuk HIG (How It Works)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Text("HOW IT WORKS")
                                    .font(.footnote)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 10) {
                                PetunjukItemHIG(
                                    icon: "1.circle.fill",
                                    iconColor: .gray,
                                    title: "Select Reference (Coach)",
                                    teks: "Choose a benchmark dance video from your Photo Library, Files, or quick presets."
                                )
                                PetunjukItemHIG(
                                    icon: "2.circle.fill",
                                    iconColor: .gray,
                                    title: "Record or Upload Your Dance",
                                    teks: "Record yourself with live Coach music & resizable PiP guide, or upload your practice video."
                                )
                                PetunjukItemHIG(
                                    icon: "3.circle.fill",
                                    iconColor: .gray,
                                    title: "Real-Time AI Pose Comparison",
                                    teks: "Compare both movements frame-by-frame with skeleton tracking and auto-pause on posture errors."
                                )
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        
                        // MARK: - 2. Dua Kartu Upload Berdampingan (Step 1: Coach -> Step 2: User)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("SELECT VIDEO SOURCES")
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            
                            HStack(alignment: .top, spacing: 14) {
                                // KARTU 1: REFERENCE (COACH) - LANGKAH 1 (Selalu Aktif)
                                KotakUploadHIG(
                                    stepNumber: "1",
                                    label: "REFERENCE",
                                    sublabel: "Coach Video (Reference)",
                                    systemIcon: "person.badge.shield.checkmark.fill",
                                    accentColor: .blue,
                                    videoItem: viewModel.selectedCoach,
                                    isLoading: viewModel.isLoadingCoach,
                                    isLocked: false,
                                    onRemove: {
                                        viewModel.removeCoach()
                                    }
                                ) {
                                    menuOpsiCoach
                                }
                                
                                // KARTU 2: UPLOAD / RECORD (USER) - LANGKAH 2 (Terkunci jika belum ada Coach)
                                KotakUploadHIG(
                                    stepNumber: "2",
                                    label: "UPLOAD / RECORD",
                                    sublabel: viewModel.isUserSectionLocked ? "Select Coach First" : "Practice Video (User)",
                                    systemIcon: "video.fill.badge.plus",
                                    accentColor: .purple,
                                    videoItem: viewModel.selectedUser,
                                    isLoading: viewModel.isLoadingUser,
                                    isLocked: viewModel.isUserSectionLocked,
                                    onRemove: {
                                        viewModel.removeUser()
                                    }
                                ) {
                                    menuOpsiUser
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        
                        // MARK: - 3. Tombol Shortcut Preset Demo Cepat
                        Button(action: {
                            viewModel.muatPresetDemo()
                        }) {
                            HStack(spacing: 6) {
                                Text("Load Quick Demo Presets (Coach 2 & User 2)")
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
                        
                        // MARK: - 4. Tombol Utama CTA (Start Comparison)
                        Button(action: {
                            if viewModel.canStartComparison {
                                viewModel.navigateToComparison = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                                Text("Start Video Comparison")
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
                        .disabled(!viewModel.canStartComparison)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 24)
                    }
                    .frame(maxWidth: 920)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Upload Videos")
            .navigationBarTitleDisplayMode(.large)
            
            // MARK: - Navigasi ke Layar ContentView (Pose Comparison)
            .navigationDestination(isPresented: $viewModel.navigateToComparison) {
                if let coach = viewModel.selectedCoach, let user = viewModel.selectedUser {
                    ContentView(
                        coachURL: coach.url,
                        userURL: user.url,
                        labelCoach: "Coach: \(coach.title)",
                        labelUser: "User: \(user.title)"
                    )
                }
            }
            
            // MARK: - Peringatan (Alert) Harus Pilih Coach Dulu
            .alert("Select Coach Video First", isPresented: $viewModel.showMustSelectCoachAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please select a reference (Coach) video in Step 1 first so its music and dance guide can play automatically while you record.")
            }
            
            // MARK: - Sheet Photos Picker Galeri
            .photosPicker(isPresented: $viewModel.showCoachPhotosPicker, selection: $viewModel.coachPickerItem, matching: .videos)
            .onChange(of: viewModel.coachPickerItem) { _, newItem in
                if let item = newItem {
                    viewModel.prosesPhotosPickerCoach(item: item)
                }
            }
            .photosPicker(isPresented: $viewModel.showUserPhotosPicker, selection: $viewModel.userPickerItem, matching: .videos)
            .onChange(of: viewModel.userPickerItem) { _, newItem in
                if let item = newItem {
                    viewModel.prosesPhotosPickerUser(item: item)
                }
            }
            
            // MARK: - FullScreen Cover Perekam Kamera Tarian
            .fullScreenCover(isPresented: $viewModel.showCameraRecorder) {
                if let coach = viewModel.selectedCoach {
                    DanceCameraRecorderView(coachURL: coach.url) { recordedURL in
                        viewModel.prosesRekamanKamera(url: recordedURL)
                    }
                    .ignoresSafeArea()
                }
            }
            
            // MARK: - File Importers (Aplikasi Files)
            .fileImporter(
                isPresented: $viewModel.showCoachFileImporter,
                allowedContentTypes: [.movie, .quickTimeMovie, .mpeg4Movie],
                allowsMultipleSelection: false
            ) { result in
                viewModel.prosesFileImporterCoach(result: result)
            }
            .fileImporter(
                isPresented: $viewModel.showUserFileImporter,
                allowedContentTypes: [.movie, .quickTimeMovie, .mpeg4Movie],
                allowsMultipleSelection: false
            ) { result in
                viewModel.prosesFileImporterUser(result: result)
            }
        }
    }
    
    // MARK: - Menu Opsi Pemilihan Video Coach (Langkah 1)
    @ViewBuilder
    private var menuOpsiCoach: some View {
        Section("Select Reference Video (Step 1)") {
            Button {
                viewModel.showCoachPhotosPicker = true
            } label: {
                Label("Choose from Photo Library", systemImage: "photo.on.rectangle")
            }
            
            Button {
                viewModel.showCoachFileImporter = true
            } label: {
                Label("Choose from Files", systemImage: "folder")
            }
        }
        
        Section("Sample Coach Videos") {
            Button {
                viewModel.muatVideoBundleCoach(nama: "dance_coach2")
            } label: {
                Label("dance_coach2.mp4 (Recommended)", systemImage: "figure.dance")
            }
            
            Button {
                viewModel.muatVideoBundleCoach(nama: "dance_coach")
            } label: {
                Label("dance_coach.mp4", systemImage: "film")
            }
        }
    }
    
    // MARK: - Menu Opsi Pemilihan Video User (Langkah 2)
    @ViewBuilder
    private var menuOpsiUser: some View {
        if viewModel.selectedCoach != nil {
            Section("Record Dance with Coach Music") {
                Button {
                    viewModel.showCameraRecorder = true
                } label: {
                    Label("Record Camera", systemImage: "record.circle")
                }
            }
            
            Section("Import Video File / Photos") {
                Button {
                    viewModel.showUserPhotosPicker = true
                } label: {
                    Label("Choose from Photo Library", systemImage: "photo.on.rectangle")
                }
                
                Button {
                    viewModel.showUserFileImporter = true
                } label: {
                    Label("Choose from Files", systemImage: "folder")
                }
            }
            
            Section("Sample User Videos") {
                Button {
                    viewModel.muatVideoBundleUser(nama: "dance_user2")
                } label: {
                    Label("dance_user2.mp4 (Recommended)", systemImage: "figure.dance")
                }
                
                Button {
                    viewModel.muatVideoBundleUser(nama: "dance_user")
                } label: {
                    Label("dance_user.mp4", systemImage: "film")
                }
            }
        } else {
            Section("Locked (Requires Reference Video)") {
                Button {
                    viewModel.showMustSelectCoachAlert = true
                } label: {
                    Label("Select Reference (Coach) First", systemImage: "lock.fill")
                }
            }
        }
    }
}

#Preview {
    UploadView()
}
