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

    // ✅ pet_011 は未実装のため図鑑表示から除外
    private var initialPetIDs: [String] {
        AppState.initialZukanPetIDs.filter { $0 != "pet_011" }
    }
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    @State private var selectedPetID: String? = nil

    // ✅ 追加：インタースティシャル（キャラ切替用）
    @ObservedObject private var interstitial = AdMobManager.shared.interstitialCharacterSet

    var body: some View {
        ZStack {
            // ✅ 背景画像を見せたいので、ベタ塗りをやめる（レイアウトは変わらない）
            Color.clear.ignoresSafeArea()

            VStack(spacing: 14) {
                if let state {
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

                    ZukanDetailPanel(
                        state: state,
                        selectedPetID: selectedPetID ?? state.currentPetID,
                        onTrain: { id in
                            // ✅ 仕様：押したら interstitial → 見終わったら切替
                            handleTrainTapped(state: state, id: id)
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
        .background(
            ZStack {
                Image("Zukan_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.25)
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("図鑑")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let state else { return }
            state.ensureInitialPetsIfNeeded()

            // ✅ 選択中IDが未実装IDだった場合の保険
            if selectedPetID == nil || selectedPetID == "pet_011" {
                selectedPetID = initialPetIDs.contains(state.currentPetID)
                    ? state.currentPetID
                    : initialPetIDs.first
            }

            // ✅ 追加：初回から出せるように事前ロード
            interstitial.load()
        }
    }

    // ✅ 追加：ボタン押下ハンドラ（広告→切替）
    private func handleTrainTapped(state: AppState, id: String) {
        let switchPet: () -> Void = {
            state.currentPetID = id
            selectedPetID = id
            save()
        }

        // ✅ 広告が用意できていれば表示 → 見終わったら切替
        if interstitial.isReady {
            interstitial.show {
                switchPet()
            }
        } else {
            // ✅ フォールバック：まだ広告が無いならそのまま切替（UX優先）
            switchPet()
            // 次回のためにロードしておく
            interstitial.load()
        }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            // ✅ 握りつぶすと原因追跡が難しいので最低限ログ
            print("❌ ZukanView save error:", error)
        }
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
                            guard isOwned else { return }
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
                if isCurrent {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.black, lineWidth: 3)
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.black.opacity(0.18), lineWidth: 1)
                }
            }
            .opacity(isOwned ? 1.0 : 0.7)
        }
        .buttonStyle(.plain)
        .disabled(!isOwned)
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

    private var isCurrent: Bool {
        state.currentPetID == selectedPetID
    }

    // ✅ NEW: 大好物（表示用）
    private var superFavoriteDisplayText: String {
        state.isSuperFavoriteRevealed(petID: selectedPetID)
        ? PetMaster.superFavoriteFoodName(for: selectedPetID)
        : "？？？"
    }

    // ✅ 説明文：PetMaster側のテキストから「【大好物】」行を除いた本文だけを表示する
    // （表示はこのViewで必ず別途出す＝kakkeだけ消える等の事故を防ぐ）
    private var descriptionBodyText: String {
        let full = PetMaster.description(for: selectedPetID, state: state)
        // PetMasterは "\n\n【大好物】" を付与している前提
        let parts = full.components(separatedBy: "\n\n【大好物】")
        return parts.first ?? full
    }

    var body: some View {
        VStack(spacing: 12) {
            Button {
                onTrain(selectedPetID)
            } label: {
                Text(isCurrent ? "\(selectedName) をお世話中" : "\(selectedName) をお世話する")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCurrent)
            .opacity(isCurrent ? 0.6 : 1.0)

            HStack(spacing: 12) {
                VStack {
                    Image(selectedImageName)
                        .resizable()
                        .scaledToFit()
                        .padding(18)
                }
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 260)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedName)
                        .font(.headline)

                    // ✅ 本文
                    Text(descriptionBodyText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // ✅ 大好物：常にここで表示する（kakkeだけ消える等を回避）
                    Text("【大好物】\(superFavoriteDisplayText)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
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
