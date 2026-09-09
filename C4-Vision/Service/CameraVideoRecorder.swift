//
//  CameraVideoRecorder.swift
//  C4-Vision
//
//  Created by Sharon Tan on 02/09/26.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - UIViewControllerRepresentable untuk Merekam Video dari Kamera
struct CameraVideoRecorder: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onVideoRecorded: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.mediaTypes = [UTType.movie.identifier]
            picker.cameraCaptureMode = .video
            picker.videoQuality = .typeHigh
            picker.cameraDevice = .rear
        } else {
            picker.sourceType = .photoLibrary
            picker.mediaTypes = [UTType.movie.identifier]
        }
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraVideoRecorder
        
        init(_ parent: CameraVideoRecorder) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                parent.onVideoRecorded(videoURL)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
