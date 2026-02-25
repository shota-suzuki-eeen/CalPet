//
//  AdBannerView.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/24.
//

import SwiftUI

/// ✅ 使う側はこれを置くだけ
/// - 例：Home の上部 / 下部など
struct AdBannerView: View {
    var height: CGFloat = 70

    var body: some View {
        BannerArea(height: height, adUnitID: AdUnitID.bannerHome)
            .frame(height: height)
    }
}
