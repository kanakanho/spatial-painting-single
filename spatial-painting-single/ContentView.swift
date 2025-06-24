//
//  ContentView.swift
//  spatial-painting
//
//  Created by blueken on 2025/03/18.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.dismissWindow) var dismissWindow
    
    @Environment(\.openWindow) private var openWindow
    
    // added by nagao 2025/6/15
    @Environment(AppModel.self) var appModel
    
    var body: some View {
        @Bindable var appModel = appModel
        VStack {
            Button("ファイルに保存・ファイルから読み出し") {
                openWindow(id: "ExternalStroke")
            }
            
            ToggleImmersiveSpaceButton()
        }
        .padding()
        VStack {
            Toggle(appModel.isArrowShown ? "Hand Axis On" : "Hand Axis Off", isOn: $appModel.isArrowShown)
                .toggleStyle(.button)
                .padding(.top, 20)
            VStack {
                Text("Sensitivity: \(appModel.senseThreshold, specifier: "%.2f")")
                    .font(.headline)
                Slider(value: $appModel.senseThreshold, in: 0...1) {
                    Text("Sense Threshold")
                }
                .padding(.horizontal)
            }
            .padding()
            VStack {
                Text("Distance to Head: \(appModel.distanceThreshold, specifier: "%.2f")")
                    .font(.headline)
                Slider(value: $appModel.distanceThreshold, in: 0...1) {
                    Text("Distance Threshold")
                }
                .padding(.horizontal)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .padding(.bottom, 30)
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
