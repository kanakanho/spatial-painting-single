//
//  spatial_paintingApp.swift
//  spatial-painting
//
//  Created by blueken on 2025/03/18.
//

import SwiftUI

@main
struct spatial_paintingApp: App {

    @State private var appModel = AppModel()
    @State private var model = ViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .environment(model)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
     }
}
