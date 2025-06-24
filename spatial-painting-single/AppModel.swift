//
//  AppModel.swift
//  spatial-painting
//
//  Created by blueken on 2025/03/18.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    var senseThreshold: Float = 0.5  // 感度の初期値 added by nagao 2025/6/15
    var distanceThreshold: Float = 0.6  // 距離の初期値 added by nagao 2025/6/16
    var isArrowShown: Bool = false // 手の向きを表す矢印の表示 added by nagao 2025/6/16
}
