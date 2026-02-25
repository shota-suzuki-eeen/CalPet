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

    // 開発（Google公式のダミー）
    static let bannerTest: String = "ca-app-pub-3940256099942544/2934735716"
    static let rewardedTest: String = "ca-app-pub-3940256099942544/1712485313"

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
}

// MARK: - App-level Manager

@MainActor
final class AdMobManager: ObservableObject {
    static let shared = AdMobManager()

    @Published private(set) var didStart: Bool = false

    private init() {}

    /// ✅ アプリ起動時に1回だけ呼ぶ（Cal_PetApp.onAppear など）
    func start() {
        guard !didStart else { return }
        didStart = true

        // ✅ v13系: GADMobileAds ではなく MobileAds
        MobileAds.shared.start() // completionHandler は不要/非推奨側に寄る
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

    var body: some View {
        GeometryReader { proxy in
            let w = max(1, proxy.size.width)

            ZStack {
                Color.clear

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    AdMobBannerView(adUnitID: adUnitID, width: w)
                        .frame(height: min(height, 60))
                    Spacer(minLength: 0)
                }
                .frame(height: height)
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

        isReady = false
        lastErrorMessage = nil

        // ✅ v13系: present(from: ...)
        ad.present(from: root) { [weak self] in
            onReward()
            self?.load()
        }

        rewardedAd = nil
    }
}
