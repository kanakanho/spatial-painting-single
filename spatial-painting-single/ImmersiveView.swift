//
//  ImmersiveView.swift
//  spatial-painting
//
//  Created by blueken on 2025/03/18.
//

import SwiftUI
import ARKit
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    
    @Environment(ViewModel.self) var model
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openWindow) var openWindow

    @State var lastIndexPose: SIMD3<Float>?
    
    // added by nagao 2025/6/15
    @Environment(AppModel.self) var appModel

    @State var headLockedEntity: Entity = {
        let headAnchor = AnchorEntity(.head)
        headAnchor.position = [0.0, 0.0, -0.01]
        return headAnchor
    }()

    var body: some View {
        RealityView { content in
            do {
                let scene = try await Entity(named: "Immersive", in: realityKitContentBundle)
                //content.add(scene)
                model.colorPalletModel.setSceneEntity(scene: scene)

                content.add(model.setupContentEntity())
                content.add(model.colorPalletModel.colorPalletEntity)
                let root = model.canvas.root
                content.add(root)

                // added by nagao 2025/6/16
                model.setAppModel(appModel)
                /*
                let color = UIColor(red: 192/255, green: 192/255, blue: 192/255, alpha: 1.0)
                let coneEntity = ModelEntity(
                    mesh: .generateCone(height: 0.1, radius: 0.02),
                    materials: [SimpleMaterial(color: color, isMetallic: true)])
                coneEntity.name = "cone"
                headLockedEntity.addChild(coneEntity)
                */

                if let eraserEntity = scene.findEntity(named: "collider") {
                    model.canvas.setEraserEntity(eraserEntity)
                } else {
                    print("eraserEntity not found")
                }
                
                content.add(headLockedEntity)
                model.setHeadLockedEntity(headLockedEntity)

                // added by nagao 3/22
                for fingerEntity in model.fingerEntities.values {
                    //print("Collision Setting for \(fingerEntity.name)")
                    _ = content.subscribe(to: CollisionEvents.Began.self, on: fingerEntity) { collisionEvent in
                        if model.colorPalletModel.colorNames.contains(collisionEvent.entityB.name) {
                            model.changeFingerColor(entity: fingerEntity, colorName: collisionEvent.entityB.name)
                            model.isEraserMode = false
                            //print("💥 Collision between \(collisionEvent.entityA.name) and \(collisionEvent.entityB.name) began")
                        } else if (collisionEvent.entityB.name == "clear") {
                            let material = SimpleMaterial(color: UIColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 0.2), isMetallic: true)
                            fingerEntity.components.set(ModelComponent(mesh: .generateSphere(radius: 0.01), materials: [material]))
                            model.isEraserMode = true
                            _ = model.recordTime(isBegan: true)
                        } else if (collisionEvent.entityB.components.contains(where: {$0 is StrokeComponent})) {
                            if !model.isEraserMode {
                                return
                            }
                            guard let strokeComponent = collisionEvent.entityB.components[StrokeComponent.self] else {
                                return
                            }
                            model.canvas.root.children.removeAll{ $0.components[StrokeComponent.self]?.uuid == strokeComponent.uuid
                            }
                            model.canvas.strokes.removeAll{ $0.entity.components[StrokeComponent.self]?.uuid == strokeComponent.uuid
                            }
                        }
                    }

                    _ = content.subscribe(to: CollisionEvents.Ended.self, on: fingerEntity) { collisionEvent in
                        if model.colorPalletModel.colorNames.contains(collisionEvent.entityB.name) {
                            model.selectColor(colorName: collisionEvent.entityB.name)
                            //print("💥 Collision between \(collisionEvent.entityA.name) and \(collisionEvent.entityB.name) ended")
                        } else if (collisionEvent.entityB.name == "clear") {
                            if model.recordTime(isBegan: false) {
                                /*
                                for stroke in model.canvas.strokes {
                                    stroke.entity.removeFromParent()
                                }
                                */
                                model.canvas.root.children.removeAll()
                                model.canvas.strokes.removeAll()
                            }
                        }
                    }
                }

                root.components.set(ClosureComponent(closure: { deltaTime in
                    var anchors = [HandAnchor]()
                    
                    if let left = model.latestHandTracking.left {
                        anchors.append(left)
                    }
                    
                    if let right = model.latestHandTracking.right {
                        anchors.append(right)
                    }
                    
                    // Loop through each anchor the app detects.
                    for anchor in anchors {
                        /// The hand skeleton that associates the anchor.
                        guard let handSkeleton = anchor.handSkeleton else {
                            continue
                        }

                        /// The current position and orientation of the thumb tip.
                        let thumbPos = (
                            anchor.originFromAnchorTransform * handSkeleton.joint(.thumbTip).anchorFromJointTransform).translation()

                        /// The current position and orientation of the index finger tip.
                        let indexPos = (anchor.originFromAnchorTransform * handSkeleton.joint(.indexFingerTip).anchorFromJointTransform).translation()

                        /// The threshold to check if the index and thumb are close.
                        let pinchThreshold: Float = 0.03

                        // Update the last index position if the distance
                        // between the thumb tip and index finger tip is
                        // less than the pinch threshold.
                        if length(thumbPos - indexPos) < pinchThreshold {
                            lastIndexPose = indexPos
                        }
                    }
                }))
            } catch {
                print("Error in RealityView's make: \(error)")
            }
        }
        .task {
            //model.webSocketClient.connect()
            do {
                /*
                if model.dataProvidersAreSupported && model.isReadyToRun {
                    try await model.session.run([model.sceneReconstruction, model.handTracking])
                } else {
                    await dismissImmersiveSpace()
                }
                */
                try await model.session.run([model.sceneReconstruction, model.handTracking])
            } catch {
                print("Failed to start session: \(error)")
                await dismissImmersiveSpace()
                openWindow(id: "error")
            }
        }
        .task {
            await model.processHandUpdates()
        }
        .task(priority: .low) {
            await model.processReconstructionUpdates()
        }
        .task {
            await model.monitorSessionEvents()
        }
        .task {
            await model.processWorldUpdates()
        }
        .task {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                //model.initBall()
                model.colorPalletModel.initEntity()
            }
        }
        .onChange(of: appModel.isArrowShown) { _, newValue in
            Task {
                if newValue {
                    model.showHandArrowEntities()
                } else {
                    model.hideHandArrowEntities()
                }
            }
        }
        .onDisappear {
            model.dismissHandArrowEntities()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .targetedToAnyEntity()
                .onChanged({ _ in
                    if !model.isEraserMode, let pos = lastIndexPose {
                        let uuid: UUID = UUID()
                        model.canvas.addPoint(uuid, pos)
                    }
                })
                .onEnded({ _ in
                    if !model.isEraserMode {
                        model.canvas.finishStroke()
                    }
                })
            )
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
