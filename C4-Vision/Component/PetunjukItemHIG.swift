//
//  PetunjukItemHIG.swift
//  C4-Vision
//
//  Created by Sharon Tan on 03/09/26.
//

import SwiftUI

// MARK: - Komponen Baris Petunjuk HIG (PetunjukItemHIG)
/// Komponen tampilan baris petunjuk bergaya Apple Human Interface Guidelines (HIG).
/// Menampilkan ikon nomor langkah di sisi kiri, serta judul langkah dan deskripsi penjelasan di sisi kanan.
struct PetunjukItemHIG: View {
    /// Nama ikon SF Symbol yang ditampilkan (misal: "1.circle.fill", "2.circle.fill", dll.)
    let icon: String
    
    /// Warna aksen untuk ikon (default: .blue)
    var iconColor: Color = .blue
    
    /// Judul tebal untuk langkah petunjuk (opsional)
    var title: String? = nil
    
    /// Teks deskripsi lengkap dari langkah petunjuk
    let teks: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Ikon Simbol Langkah di Kiri
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundColor(iconColor)
                .frame(width: 22)
                .padding(.top, 1)
            
            // Teks Judul dan Deskripsi di Kanan
            VStack(alignment: .leading, spacing: 2) {
                if let title = title {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                }
                Text(teks)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        PetunjukItemHIG(
            icon: "1.circle.fill",
            iconColor: .gray,
            title: "Select Reference (Coach)",
            teks: "Pilih video panduan referensi pelatih tari."
        )
    }
    .padding()
}
