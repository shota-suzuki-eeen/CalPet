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

    /// 互換用（既存コードが使っている場合に備えて残す）
    static func activeRootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow }
        return window?.rootViewController
    }

    /// ✅ FocusQuest 側と同じ思想：最前面のVCを取る（広告の表示/ロードが安定する）
    func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC: UIViewController? = {
            if let base { return base }
            let scenes = connectedScenes
            let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            let window = windowScene?.windows.first { $0.isKeyWindow }
            return window?.rootViewController
        }()

        if let nav = baseVC as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = baseVC as? UITabBarController {
            return topMostViewController(base: tab.selectedViewController)
        }
        if let presented = baseVC?.presentedViewController {
            return topMostViewController(base: presented)
        }
        return baseVC
    }
}

// MARK: - Banner (SwiftUI)

struct AdMobBannerView: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat   // ✅ 既存との互換のため残す（固定運用なので基本未使用）

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BannerView {
        // ✅ FocusQuest と同じ：iPhone想定で 320×50 固定
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID

        // ✅ topMost VC を使う（rootVCより安定）
        banner.rootViewController = UIApplication.shared.topMostViewController()

        // ✅ 背景は透明
        banner.backgroundColor = .clear

        banner.load(Request())

        context.coordinator.lastLoadedAdUnitID = adUnitID
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        uiView.rootViewController = UIApplication.shared.topMostViewController()
        uiView.backgroundColor = .clear

        // ✅ adUnit が変わったときだけ再ロード（width変動では再ロードしない）
        if context.coordinator.lastLoadedAdUnitID != adUnitID {
            uiView.adUnitID = adUnitID
            uiView.load(Request())
            context.coordinator.lastLoadedAdUnitID = adUnitID
        }
    }

    final class Coordinator {
        var lastLoadedAdUnitID: String?
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

            // ✅ 互換のため残す（固定運用なので最終的に width は効きづらいが、既存設計は壊さない）
            let w = normalizeBannerWidth(rawW)

            let adH = min(max(1, contentHeight), height)

            ZStack {
                Color.clear

                AdMobBannerView(adUnitID: adUnitID, width: w)
                    .frame(width: w, height: adH)
                    .clipped()
                    .padding(.top, topOffset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(height: height)
    }

    /// ✅ banner要求に使う width を「ポイント幅」に正規化する（互換用）
    private func normalizeBannerWidth(_ rawW: CGFloat) -> CGFloat {
        let screenW = UIScreen.main.bounds.width
        let scale = UIScreen.main.scale

        var w = maxWidth.map { min(rawW, $0) } ?? rawW
        w = min(w, screenW)

        if w > screenW * 1.15 {
            w = w / scale
            w = min(w, screenW)
        }

        return max(1, w)
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

        // ✅ topMost VC を使う（rootVCより安定）
        guard let root = UIApplication.shared.topMostViewController() else {
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

// MARK: - Interstitial

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

    /// - Parameter onDismiss: 広告が閉じられたタイミングで実行
    func show(onDismiss: @escaping () -> Void) {
        guard let ad = interstitialAd else {
            isReady = false
            return
        }

        // ✅ topMost VC を使う（rootVCより安定）
        guard let root = UIApplication.shared.topMostViewController() else {
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
        let callback = onDismiss
        onDismiss = nil
        callback?()

        load()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        lastErrorMessage = error.localizedDescription

        let callback = onDismiss
        onDismiss = nil
        callback?()

        load()
    }
}
