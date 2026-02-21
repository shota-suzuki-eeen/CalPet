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
    @Environment(\.modelContext) private var modelContext

    private var state: AppState? { appStates.first }

    // ✅ 初期実装予定：12体ぶんを常に表示（正本は AppState.initialZukanPetIDs）
    private var initialPetIDs: [String] { AppState.initialZukanPetIDs }

    // ✅ 1列4キャラ
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    // ✅ 下半分表示用：選択中キャラ（デフォルトは育成中）
    @State private var selectedPetID: String? = nil

    var body: some View {
        ZStack {
            Color(red: 0.35, green: 0.86, blue: 0.88).ignoresSafeArea()

            VStack(spacing: 14) {
                if let state {
                    // --- 上半分：図鑑グリッド ---
                    ZukanGrid(
                        petIDs: initialPetIDs,
                        ownedIDs: Set(state.ownedPetIDs()),
                        currentPetID: state.currentPetID,
                        columns: columns,
                        selectedPetID: selectedPetID,
                        onSelect: { id in
                            selectedPetID = id
                        }
                    )
                    .padding(.top, 6)

                    // --- 下半分：詳細（画像 / 説明 / 育成ボタン） ---
                    ZukanDetailPanel(
                        state: state,
                        selectedPetID: selectedPetID ?? state.currentPetID,
                        onTrain: { id in
                            state.currentPetID = id
                            selectedPetID = id
                            save()
                        }
                    )
                    .padding(.top, 6)

                } else {
                    Text("（準備中）")
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("図鑑")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let state else { return }
            state.ensureInitialPetsIfNeeded()
            if selectedPetID == nil {
                selectedPetID = state.currentPetID
            }
        }
    }

    private func save() {
        do { try modelContext.save() } catch { }
    }
}

// MARK: - Grid

private struct ZukanGrid: View {
    let petIDs: [String]
    let ownedIDs: Set<String>
    let currentPetID: String
    let columns: [GridItem]
    let selectedPetID: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(petIDs, id: \.self) { id in
                    let isOwned = ownedIDs.contains(id)
                    let isCurrent = (currentPetID == id)

                    ZukanCell(
                        petID: id,
                        isOwned: isOwned,
                        isCurrent: isCurrent,
                        isSelected: (selectedPetID == id),
                        onTap: {
                            guard isOwned else { return } // ✅ 未獲得は反応しない
                            onSelect(id)
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ZukanCell: View {
    let petID: String
    let isOwned: Bool
    let isCurrent: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private var displayName: String {
        guard isOwned else { return "？？？" }
        return PetMaster.all.first(where: { $0.id == petID })?.name ?? petID
    }

    private var imageName: String {
        isOwned ? PetMaster.assetName(for: petID) : "CalPet_secret"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 52)
                    .padding(.top, 10)

                Text(displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(isOwned ? .primary : .secondary)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                // ✅ 育成中キャラ：太め黒枠
                if isCurrent {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.black, lineWidth: 3)
                } else if isSelected {
                    // ✅ 選択中（育成中とは別）：薄い枠（任意）
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.black.opacity(0.18), lineWidth: 1)
                }
            }
            .opacity(isOwned ? 1.0 : 0.7)   // ✅ 未獲得は暗く
        }
        .buttonStyle(.plain)
        .disabled(!isOwned)               // ✅ 未獲得はタップ無効
    }
}

// MARK: - Detail (Lower half)

private struct ZukanDetailPanel: View {
    let state: AppState
    let selectedPetID: String
    let onTrain: (String) -> Void

    private var selectedName: String {
        PetMaster.all.first(where: { $0.id == selectedPetID })?.name ?? selectedPetID
    }

    private var selectedImageName: String {
        PetMaster.assetName(for: selectedPetID)
    }

    private var selectedDescription: String {
        PetMaster.description(for: selectedPetID)
    }

    private var isCurrent: Bool {
        state.currentPetID == selectedPetID
    }

    var body: some View {
        VStack(spacing: 12) {
            // ✅ 緑枠：育成ボタン
            Button {
                onTrain(selectedPetID)
            } label: {
                Text(isCurrent ? "\(selectedName) を育成中" : "\(selectedName) を育成する")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCurrent)
            .opacity(isCurrent ? 0.6 : 1.0)

            // ✅ 赤（画像）＋青（説明）
            HStack(spacing: 12) {
                // 画像（赤枠想定）
                VStack {
                    Image(selectedImageName)
                        .resizable()
                        .scaledToFit()
                        .padding(18)
                }
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 260)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // 説明（青枠想定）
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedName)
                        .font(.headline)

                    Text(selectedDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 260, alignment: .topLeading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
