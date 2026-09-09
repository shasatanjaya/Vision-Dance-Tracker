//
//  CameraManager.swift
//  C4-Vision
//
//  Created by Sharon Tan on 03/09/26.
//

import SwiftUI
import AVFoundation
import UIKit
import Combine

// MARK: - Pengelola Kamera (CameraManager)
/// Kelas pengontrol native AVFoundation untuk mengelola sesi perekaman kamera video (`AVCaptureSession`).
///
/// Fitur Utama:
/// 1. **Front & Back Camera**: Mengatur kamera depan (default untuk latihan tarian / selfie) atau kamera belakang.
/// 2. **Audio & Video Input**: Menggabungkan input mikrofon dan sensor kamera ke dalam satu sesi.
/// 3. **Output File Movie**: Menyimpan rekaman video ke direktori sementara (`temporaryDirectory`) berformat `.mp4`.
/// 4. **Auto-Orientation & Mirroring**: Menyesuaikan orientasi rekaman dan efek cermin (mirroring) kamera depan secara otomatis.
class CameraManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    
    /// Sesi penangkapan AVFoundation
    let session = AVCaptureSession()
    
    /// Output file perekaman movie
    private let movieOutput = AVCaptureMovieFileOutput()
    
    /// Perangkat input video aktif (kamera depan / belakang)
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    /// Callback saat rekaman selesai disimpan ke URL
    private var completionHandler: ((URL?) -> Void)?
    
    /// Status apakah proses perekaman video sedang berlangsung
    @Published var isRecording: Bool = false
    
    /// Status kamera aktif (true = Kamera Depan / Selfie, false = Kamera Belakang)
    @Published var isFrontCamera: Bool = true
    
    override init() {
        super.init()
    }
    
    // MARK: - 1. Pengecekan Izin Akses Kamera & Setup Sesi
    
    /// Memeriksa izin akses kamera perangkat dan memulai sesi jika telah diizinkan
    func checkPermissionsAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async { self?.setupSession() }
                }
            }
        default:
            break
        }
    }
    
    /// Mengonfigurasi input kamera, input mikrofon audio, dan output file
    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        
        // Setup Input Video (Default: Kamera Depan agar penari bisa melihat dirinya di layar)
        let device = getCamera(position: isFrontCamera ? .front : .back)
        if let device = device, let input = try? AVCaptureDeviceInput(device: device) {
            if session.canAddInput(input) {
                session.addInput(input)
                self.videoDeviceInput = input
            }
        }
        
        // Setup Input Audio Mikrofon
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
        }
        
        // Setup Output Movie
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            updateRecordingOrientation()
        }
        
        session.commitConfiguration()
        
        // Jalankan sesi kamera di thread background (qos userInitiated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    // MARK: - 2. Ganti Kamera Depan / Belakang
    
    /// Mengganti kamera aktif antara kamera depan dan kamera belakang
    func switchCamera() {
        session.beginConfiguration()
        if let currentInput = videoDeviceInput {
            session.removeInput(currentInput)
        }
        
        isFrontCamera.toggle()
        let newDevice = getCamera(position: isFrontCamera ? .front : .back)
        if let newDevice = newDevice, let newInput = try? AVCaptureDeviceInput(device: newDevice) {
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                self.videoDeviceInput = newInput
            }
        }
        
        updateRecordingOrientation()
        session.commitConfiguration()
    }
    
    // MARK: - 3. Penyesuaian Orientasi & Mirroring
    
    /// Mendeteksi orientasi antarmuka layar aktif
    func currentVideoOrientation() -> AVCaptureVideoOrientation {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            
        let interfaceOrientation = windowScene?.interfaceOrientation ?? .portrait
        
        switch interfaceOrientation {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }
    
    /// Memperbarui orientasi dan mirroring video output agar hasil rekaman tidak terbalik
    func updateRecordingOrientation() {
        if let connection = movieOutput.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = currentVideoOrientation()
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isFrontCamera
            }
        }
    }
    
    /// Mengambil perangkat kamera fisik sesuai posisi yang diminta
    private func getCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: position
        )
        return discoverySession.devices.first
    }
    
    // MARK: - 4. Operasi Rekam & Berhenti
    
    /// Memulai perekaman video kamera ke file temporary
    func startRecording(completion: @escaping (URL?) -> Void) {
        guard !isRecording else { return }
        self.completionHandler = completion
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dance_record_\(UUID().uuidString).mp4")
        
        updateRecordingOrientation()
        
        movieOutput.startRecording(to: tempURL, recordingDelegate: self)
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }
    
    /// Menghentikan perekaman video kamera
    func stopRecording() {
        guard isRecording else { return }
        movieOutput.stopRecording()
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    /// Menghentikan sesi kamera saat keluar dari layar
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if self?.session.isRunning == true {
                self?.session.stopRunning()
            }
        }
    }
    
    // MARK: - 5. AVCaptureFileOutputRecordingDelegate
    
    /// Dipanggil oleh AVFoundation saat file video selesai ditulis ke disk
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        completionHandler?(error == nil ? outputFileURL : nil)
    }
}
