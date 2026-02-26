//
//  AdMobManager.swift
//  Cal Pet
//
//  Created by ChatGPT on 2026/02/24.
//

import Foundation
import SwiftUI
import UIKit
import Combine
import GoogleMobileAds

// MARK: - Ad Unit IDs

enum AdUnitID {
    static let appID: String = "ca-app-pub-1093843343402854~6781234297"

    // 本番
    static let bannerHomeProd: String = "ca-app-pub-1093843343402854/1772450194"
    static let rewardMojaProd: String = "ca-app-pub-1093843343402854/7270666378"
    static let rewardFoodProd: String = "ca-app-pub-1093843343402854/8425488459"

    // ✅ 追加：本番（Interstitial_character_set）
    static let interstitialCharacterSetProd: String = "ca-app-pub-1093843343402854/7464061895"

    // 開発（Google公式のダミー）
    static let bannerTest: String = "ca-app-pub-3940256099942544/2934735716"
    static let rewardedTest: String = "ca-app-pub-3940256099942544/1712485313"

    // ✅ 追加：Interstitial のテストID（Google公式）
    static let interstitialTest: String = "ca-app-pub-3940256099942544/4411468910"

    static var bannerHome: String {
        #if DEBUG
        return bannerTest
        #else
        return bannerHomeProd
        #endif
    }

    static var rewardMoja: String {
        #if DEBUG
        return rewardedTest
        #else
        return rewardMojaProd
        #endif
    }

    static var rewardFood: String {
        #if DEBUG
        return rewardedTest
        #else
        return rewardFoodProd
        #endif
    }

    // ✅ 追加：Interstitial_character_set
    static var interstitialCharacterSet: String {
        #if DEBUG
        return interstitialTest
        #else
        return interstitialCharacterSetProd
        #endif
    }
}

// MARK: - App-level Manager

@MainActor
final class AdMobManager: ObservableObject {
    static let shared = AdMobManager()

    @Published private(set) var didStart: Bool = false

    // ✅ 追加：キャラ切替用 interstitial をアプリ全体で1つ保持
    let interstitialCharacterSet = InterstitialAdManager(adUnitID: AdUnitID.interstitialCharacterSet)

    private init() {}

    func start() {
        guard !didStart else { return }
        didStart = true

        MobileAds.shared.start()

        // ✅ 追加：起動時に1回ロードして持っておく
        interstitialCharacterSet.load()
    }
}

// MARK: - Root VC helper

private extension UIApplication {
    static func activeRootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow }
        return window?.rootViewController
    }
}

// MARK: - Banner (SwiftUI)

struct AdMobBannerView: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.activeRootViewController()

        banner.load(Request())

        context.coordinator.lastLoadedAdUnitID = adUnitID
        context.coordinator.lastLoadedWidth = width
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        uiView.rootViewController = UIApplication.activeRootViewController()

        let newSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        if uiView.adSize.size.width != newSize.size.width ||
           uiView.adSize.size.height != newSize.size.height {
            uiView.adSize = newSize
        }

        // ✅ adUnit / width が変わったときだけ再ロード
        let shouldReload =
            context.coordinator.lastLoadedAdUnitID != adUnitID ||
            abs((context.coordinator.lastLoadedWidth ?? 0) - width) > 0.5

        if shouldReload {
            uiView.adUnitID = adUnitID
            uiView.load(Request())
            context.coordinator.lastLoadedAdUnitID = adUnitID
            context.coordinator.lastLoadedWidth = width
        }
    }

    final class Coordinator {
        var lastLoadedAdUnitID: String?
        var lastLoadedWidth: CGFloat?
    }
}

/// ✅ レイアウト維持用（既存のHomeView上部スペース等に置く想定）
struct BannerArea: View {
    let height: CGFloat
    let adUnitID: String
    var maxWidth: CGFloat? = nil
    var contentHeight: CGFloat = 50

    // ✅ 追加：広告だけを下げる量（セーフエリア直下にしたい）
    var topOffset: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let rawW = max(1, proxy.size.width)
            let w = maxWidth.map { min(rawW, $0) } ?? rawW
            let adH = min(max(1, contentHeight), height)

            ZStack {
                Color.clear

                AdMobBannerView(adUnitID: adUnitID, width: w)
                    .frame(width: w, height: adH)
                    .clipped()
                    // ✅ ここで “下に下げる”
                    .padding(.top, topOffset)
                    // ✅ 上寄せのまま（paddingで下げる）
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Rewarded

@MainActor
final class RewardedAdManager: ObservableObject {
    @Published private(set) var isReady: Bool = false
    @Published private(set) var lastErrorMessage: String? = nil

    private let adUnitID: String
    private var rewardedAd: RewardedAd?

    init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    func load() {
        isReady = false
        lastErrorMessage = nil
        rewardedAd = nil

        RewardedAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            guard let self else { return }

            if let error {
                self.lastErrorMessage = error.localizedDescription
                self.isReady = false
                self.rewardedAd = nil
                return
            }

            self.rewardedAd = ad
            self.isReady = (ad != nil)
        }
    }

    func show(onReward: @escaping () -> Void) {
        guard let ad = rewardedAd else {
            isReady = false
            return
        }
        guard let root = UIApplication.activeRootViewController() else {
            isReady = false
            return
        }

        ad.present(from: root) {
            onReward()
        }

        // 表示後は再ロード推奨
        isReady = false
        rewardedAd = nil
        load()
    }
}

// MARK: - Interstitial (✅ 追加)

@MainActor
final class InterstitialAdManager: NSObject, ObservableObject {
    @Published private(set) var isReady: Bool = false
    @Published private(set) var lastErrorMessage: String? = nil

    private let adUnitID: String
    private var interstitialAd: InterstitialAd?

    // 「見終わったら（dismissされたら）」呼ぶ
    private var onDismiss: (() -> Void)?

    init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    func load() {
        isReady = false
        lastErrorMessage = nil
        interstitialAd = nil

        InterstitialAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            guard let self else { return }

            if let error {
                self.lastErrorMessage = error.localizedDescription
                self.isReady = false
                self.interstitialAd = nil
                return
            }

            self.interstitialAd = ad
            self.interstitialAd?.fullScreenContentDelegate = self
            self.isReady = (ad != nil)
        }
    }

    /// - Parameter onDismiss: 広告が閉じられたタイミングで実行（＝「見終わったらキャラ切替」をここに乗せる）
    func show(onDismiss: @escaping () -> Void) {
        guard let ad = interstitialAd else {
            isReady = false
            // ここで「広告が無い」場合でも進めたいなら、呼び出し側で isReady を見て分岐する想定
            return
        }
        guard let root = UIApplication.activeRootViewController() else {
            isReady = false
            return
        }

        self.onDismiss = onDismiss
        ad.fullScreenContentDelegate = self

        ad.present(from: root)

        // 表示したら一旦クリア（次回のために dismiss 後に reload する）
        isReady = false
        interstitialAd = nil
    }
}

// MARK: - GADFullScreenContentDelegate

extension InterstitialAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // ✅ 見終わった（閉じられた）→ ここでキャラ切替などを実行
        let callback = onDismiss
        onDismiss = nil
        callback?()

        // ✅ 次回のために再ロード
        load()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        lastErrorMessage = error.localizedDescription

        // 出せなかった場合でも UI が固まらないように、必要なら進める
        let callback = onDismiss
        onDismiss = nil
        callback?()

        load()
    }
}
