//
//  WebSocketClient.swift
//  spatial-painting
//
//  Created by blueken on 2025/03/20.
//

// original → https://github.com/kanakanho/sensing-handtracking-websocket/blob/main/sensing-handtracking-websocket/WebSocketClient.swift

import Foundation
import ARKit

class WebSocketClient:NSObject, ObservableObject  {
    private var webSocketTask: URLSessionWebSocketTask?
    @Published var isConnected: Bool = false
    
    func connect() {
//        let url = URL(string: "ws://192.168.11.1:8000")!
//        let url = URL(string: "ws://192.168.10.2:8909")!
        let url = URL(string: "ws://172.16.11.200:8909")!
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        webSocketTask?.send(URLSessionWebSocketTask.Message.string("new")) { error in
            if let error = error {
                print(error)
            }
        }
    }
    
    func send(_ message: String) {
        let msg = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(msg) { error in
            if let error = error {
                print(error)
            }
        }
    }
    
    func sendHandAnchor(_ handAnchor: HandAnchor) {
        // 通信のためのデータに整形
        let originTransform = handAnchor.originFromAnchorTransform
        guard let handSkeletonAllAnchorTransform = handAnchor.handSkeleton?.allJoints else { return }
        let data = handSkeletonAllAnchorTransform.map { return JointCodable(jointName: $0.name.description,anchorFromJointTransform: (originTransform * $0.anchorFromJointTransform).codable)}
        let json = try! JSONEncoder().encode(data.codable)
        guard let jsonStr = String(data: json, encoding: .utf8) else { return }
        send(jsonStr)
//         print("send: \(jsonStr)")
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
}

struct JointCodable: Codable {
    var jointName: String
    var anchorFromJointTransform: [[Float]]
}

extension simd_float4 {
    var codable: [Float] {
        return [x, y, z, w]
    }
}

extension simd_float4x4 {
    var position: SIMD3<Float> {
        self.columns.3.xyz
    }

    var codable: [[Float]] {
        return [columns.0.codable, columns.1.codable, columns.2.codable, columns.3.codable]
    }
}

extension HandSkeleton.Joint {
    var codable: JointCodable {
        return JointCodable(jointName: self.name.description, anchorFromJointTransform: anchorFromJointTransform.codable)
    }
}

struct JointCodables: Codable {
    var time: String
    var jointCodables: [JointCodable]
}

extension [JointCodable] {
    var codable: [JointCodables] {
        return [JointCodables(time: Date().timeIntervalSince1970.description, jointCodables: self)]
    }
}

