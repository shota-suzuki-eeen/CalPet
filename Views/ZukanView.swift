//
//  ZukanView.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/05.
//

import SwiftUI
import SwiftData

struct ZukanView: View {
    @Query private var appStates: [AppState]
    @StateObject private var viewModel = ZukanViewModel()

    private var state: AppState? { appStates.first }

    var body: some View {
        ZStack {
            Color(red: 0.35, green: 0.86, blue: 0.88).ignoresSafeArea()

            VStack(spacing: 14) {
                Text("図鑑")
                    .font(.title2).bold()

                // ✅ 準備中のまま。ただ、所持キャラが見えると今後の拡張が楽になる
                if let state {
                    OwnedPetsPreview(rows: viewModel.makePetRows(state: state))
                        .padding(.top, 8)
                } else {
                    Text("（準備中）")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct OwnedPetsPreview: View {
    let rows: [ZukanPetRow]

    var body: some View {
        VStack(spacing: 10) {
            Text("所持キャラ")
                .font(.headline)

            if rows.isEmpty {
                Text("（未取得）")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(rows) { row in
                        HStack {
                            Text(row.name)
                                .font(.body.weight(.semibold))
                            Spacer()
                            if row.isCurrentPet {
                                Text("育成中")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.black.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }

            Text("（図鑑は今後拡張予定）")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
    }
}
