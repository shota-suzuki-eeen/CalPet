//
//  MojaView.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/21.
//

import SwiftUI
import SwiftData

struct MojaView: View {
    let state: AppState

    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = MojaViewModel()

    var body: some View {
        ZStack {
            Color.black.opacity(0.05).ignoresSafeArea()

            VStack(spacing: 14) {

                // ① もじゃの画像
                Image(viewModel.currentFusionAssetName())
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)

                // ② まとまるまで hh:mm:ss
                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    HStack(spacing: 8) {
                        Text("まとまるまで")
                            .font(.headline)
                        Text(viewModel.fusionIsRunning
                             ? viewModel.formattedRemaining(now: context.date)
                             : "06:00:00")
                            .monospacedDigit()
                            .font(.headline)
                    }
                    .padding(.top, 2)
                }

                // ③ (moja) をまとめるボタン
                Button {
                    viewModel.startFusion(now: Date())
                    save()
                } label: {
                    HStack(spacing: 8) {
                        Image("moja")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)

                        Text("をまとめる")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 18)
                .disabled(viewModel.fusionIsRunning || viewModel.mojaCount < viewModel.fusionCost)
                .opacity((viewModel.fusionIsRunning || viewModel.mojaCount < viewModel.fusionCost) ? 0.5 : 1.0)

                // ④ 所持している (moja)
                HStack(spacing: 6) {
                    Text("所持している")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Image("moja")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)

                    Text("\(viewModel.mojaCount)")
                        .monospacedDigit()
                        .font(.headline)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            // 中央トースト
            if viewModel.showCenterToast, let msg = viewModel.centerToastMessage {
                VStack {
                    Text(msg)
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(radius: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
        .navigationTitle("もじゃ合わせ")
        .navigationBarTitleDisplayMode(.inline)

        .onAppear {
            state.ensureDailyResetIfNeeded(now: Date())
            state.ensureInitialPetsIfNeeded()
            viewModel.onAppearPrepareDemoIfNeeded()
            save()
        }
    }

    private func save() {
        do { try modelContext.save() } catch { }
    }
}
