//
//  CameraPreviewView.swift
//  C4-Vision
//
//  Created by Sharon Tan on 03/09/26.
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - Custom UIView untuk Hosting AVCaptureVideoPreviewLayer
/// Tampilan UIView native UIKit yang bertugas merender feed visual kamera secara langsung menggunakan `AVCaptureVideoPreviewLayer`.
/// Kelas ini juga menangani penyesuaian rotasi / orientasi kamera saat perangkat diputar.
class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(layer)
        self.previewLayer = layer
        
        // Memantau perubahan orientasi perangkat
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Sesuaikan ukuran preview layer dengan bounds view
        previewLayer?.frame = bounds
        updateOrientation()
    }
    
    @objc private func orientationChanged() {
        DispatchQueue.main.async {
            self.updateOrientation()
        }
    }
    
    /// Menyesuaikan orientasi video preview agar selalu sesuai dengan posisi layar perangkat
    func updateOrientation() {
        guard let connection = previewLayer?.connection, connection.isVideoOrientationSupported else { return }
        
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            
        let interfaceOrientation = windowScene?.interfaceOrientation ?? .portrait
        
        let videoOrientation: AVCaptureVideoOrientation
        switch interfaceOrientation {
        case .landscapeLeft:
            videoOrientation = .landscapeLeft
        case .landscapeRight:
            videoOrientation = .landscapeRight
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        default:
            videoOrientation = .portrait
        }
        
        if connection.videoOrientation != videoOrientation {
            connection.videoOrientation = videoOrientation
        }
    }
}

// MARK: - SwiftUI Wrapper (UIViewRepresentable) untuk Preview Kamera
/// Jembatan SwiftUI `UIViewRepresentable` agar `CameraPreviewUIView` dapat dipasang di hierarki tampilan SwiftUI.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView(session: session)
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.updateOrientation()
    }
}
