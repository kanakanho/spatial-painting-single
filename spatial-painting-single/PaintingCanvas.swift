/*
 See the LICENSE.txt file for this sample’s licensing information.
 
 Abstract:
 A class that creates a volume so that a person can create meshes with the location of the drag gesture.
 */

import SwiftUI
import RealityKit

/// A class that stores each stroke and generates a mesh, in real time, from a person's gesture movement.
class PaintingCanvas {
    /// The main root entity for the painting canvas.
    let root = Entity()
    
    var strokes: [Stroke] = []
    let tmpRoot = Entity()
    var tmpStrokes: [Stroke] = []
    var tmpBoundingBox: BoundingBoxCube = BoundingBoxCube()
    
    var eraserEntity: Entity = Entity()
    
    /// The stroke that a person creates.
    var currentStroke: Stroke?
    
    var activeColor = SimpleMaterial.Color.white
    
    /// The distance for the box that extends in the positive direction.
    let big: Float = 1E2
    
    /// The distance for the box that extends in the negative direction.
    let small: Float = 1E-2
    
    var currentPosition: SIMD3<Float> = .zero
    var isFirstStroke = true
    
    // Sets up the painting canvas with six collision boxes that stack on each other.
    init() {
        root.addChild(addBox(size: [big, big, small], position: [0, 0, -0.5 * big]))
        root.addChild(addBox(size: [big, big, small], position: [0, 0, +0.5 * big]))
        root.addChild(addBox(size: [big, small, big], position: [0, -0.5 * big, 0]))
        root.addChild(addBox(size: [big, small, big], position: [0, +0.5 * big, 0]))
        root.addChild(addBox(size: [small, big, big], position: [-0.5 * big, 0, 0]))
        root.addChild(addBox(size: [small, big, big], position: [+0.5 * big, 0, 0]))
        root.addChild(tmpRoot)
    }
    
    /// Create a collision box that takes in user input with the drag gesture.
    private func addBox(size: SIMD3<Float>, position: SIMD3<Float>) -> Entity {
        /// The new entity for the box.
        let box = Entity()
        
        // Enable user inputs.
        box.components.set(InputTargetComponent())
        
        // Enable collisions for the box.
        box.components.set(CollisionComponent(shapes: [.generateBox(size: size)], isStatic: true))
        
        // Set the position of the box from the position value.
        box.position = position
        
        return box
    }
    
    func setActiveColor(color: SimpleMaterial.Color) {
        activeColor = color
    }
    
    func setEraserEntity(_ entity: Entity) {
        eraserEntity = entity
    }
    
    /// Generate a point when the user uses the drag gesture.
    func addPoint(_ uuid: UUID, _ position: SIMD3<Float>) {
        if isFirstStroke {
            isFirstStroke = false
            return
        }
        
        /// currentPosition との距離が一定以上離れている場合は早期リターンする
        let distance = length(position - currentPosition)
        currentPosition = position
        //print("distance: \(distance)")
        if distance > 0.1 {
            //print("distance is too far, return")
            currentStroke = nil
            return
        }
        
        /// The maximum distance between two points before requiring a new point.
        let threshold: Float = 1E-9
        
        // Start a new stroke if no stroke exists.
        if currentStroke == nil {
            currentStroke = Stroke(uuid: uuid)
            currentStroke!.setActiveColor(color: activeColor)
            strokes.append(currentStroke!)
            
            // Add the stroke to the root.
            root.addChild(currentStroke!.entity)
        }
        
        // Check whether the length between the current hand position and the previous point meets the threshold.
        if let previousPoint = currentStroke?.points.last, length(position - previousPoint) < threshold {
            return
        }
        
        // Add the current position to the stroke.
        currentStroke?.points.append(position)
        
        // Update the current stroke mesh.
        currentStroke?.updateMesh()
    }
    
    /// Clear the stroke when the drag gesture ends.
    func finishStroke() {
        if let stroke = currentStroke {
            // Trigger the update mesh operation.
            stroke.updateMesh()
            
            var count = 0
            for point in stroke.points {
                if count % 5 == 0 {
                    let entity = eraserEntity.clone(recursive: true)
                    entity.name = "eraser"
                    let material = SimpleMaterial(color: UIColor(white: 1.0, alpha: 0.0), isMetallic: false)
                    entity.components.set(ModelComponent(mesh: .generateSphere(radius: 0.01), materials: [material]))
                    entity.components.set(StrokeComponent(stroke.uuid))
                    entity.setScale([0.0025, 0.0025, 0.0025], relativeTo: nil)
                    entity.position = point
                    root.addChild(entity)
                }
                count += 1
            }
            
            // Clear the current stroke.
            currentStroke = nil
        }
    }
}

/// 直接 Stroke を追加するときに行う処理の拡張
extension PaintingCanvas {
    /// 一時的な Stroke をまとめて追加する
    func addTmpStrokes(_ strokes: [Stroke]) {
        for stroke in strokes {
            addTmpStroke(stroke)
        }
        
        // 頂点同士を繋ぐ線のエンティティを生成
        generateBoundingBox()
        for corner in tmpBoundingBox.corners {
            generateCornerEntity(corner: corner.value)
        }
        
        for edge in tmpBoundingBox.edges {
            generateLineEntiry(linePoint: edge)
        }
    }
    
    func generateCornerEntity(corner: SIMD3<Float>) {
        let pointEntity = Entity()
        let mesh = MeshResource.generateSphere(radius: 0.01)
        let material = SimpleMaterial(color: .red, isMetallic: false)
        pointEntity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        pointEntity.position = corner
        tmpRoot.addChild(pointEntity)
    }
    
    func generateLineEntiry(linePoint: (SIMD3<Float>, SIMD3<Float>)) {
        let lineEntity = Entity()
        
        let mesh = MeshResource.generateBox(size: [0.01, 0.01, length(linePoint.1 - linePoint.0)])
        let material = SimpleMaterial(color: UIColor(white: 1.0, alpha: 0.5), isMetallic: false)
        
        lineEntity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        
        // 中点を計算して位置を設定
        let midPoint = (linePoint.0 + linePoint.1) / 2
        lineEntity.position = midPoint
        
        // 向きを計算して設定
        let direction = normalize(linePoint.1 - linePoint.0)
        let rotation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: direction)
        lineEntity.transform.rotation = rotation
        
        tmpRoot.addChild(lineEntity)
    }
    
    /// 一時的な Stroke を追加する
    func addTmpStroke(_ stroke: Stroke) {
        let newStroke = Stroke(uuid: stroke.uuid)
        newStroke.setActiveColor(color: stroke.activeColor)
        newStroke.points = stroke.points
        newStroke.updateMesh()
        self.tmpStrokes.append(newStroke)
        tmpRoot.addChild(newStroke.entity)
    }
    
    /// 追加処理の完了
    func confirmTmpStrokes() {
        for stroke in tmpStrokes {
            stroke.points = stroke.points.map {
                let position = $0
                // 位置を調整する（必要に応じて）
                return SIMD3<Float>(tmpRoot.transform.matrix * SIMD4<Float>(position.x, position.y, position.z, 1.0))
            }
            let newStroke = Stroke(uuid: stroke.uuid)
            newStroke.setActiveColor(color: stroke.activeColor)
            newStroke.points = stroke.points
            newStroke.updateMesh()
            self.strokes.append(newStroke)
            root.addChild(newStroke.entity)
            
            var count = 0
            for point in stroke.points {
                if count % 5 == 0 {
                    let entity = eraserEntity.clone(recursive: true)
                    entity.name = "eraser"
                    let material = SimpleMaterial(color: UIColor(white: 1.0, alpha: 0.0), isMetallic: false)
                    entity.components.set(ModelComponent(mesh: .generateSphere(radius: 0.01), materials: [material]))
                    entity.components.set(StrokeComponent(stroke.uuid))
                    entity.setScale([0.0025, 0.0025, 0.0025], relativeTo: nil)
                    entity.position = point
                    root.addChild(entity)
                }
                count += 1
            }
        }
        
        // root から tmpStrokes のエンティティを削除
        tmpRoot.children.removeAll()
        tmpStrokes.removeAll()
        tmpRoot.transform.matrix = .identity
    }
    
    /// 一時的なストロークをクリアする（追加処理の停止）
    func clearTmpStrokes() {
        for stroke in tmpStrokes {
            stroke.entity.removeFromParent()
        }
        tmpRoot.children.removeAll()
        tmpStrokes.removeAll()
    }
    
    /// ストロークを動かす
    func transfromFromMatrix(_ matrix: simd_float4x4) {
        tmpRoot.transform.matrix = tmpRoot.transform.matrix * matrix
        
        /// バウンディングボックスの更新
        updateBoundingBox(matrix: matrix)
    }
    
    /// point が BoundingBoxCube の内部にあるかどうかを判定する
    func isPointInsideBoundingBox(_ point: SIMD3<Float>) -> Bool {
        return tmpBoundingBox.isPointInside(point)
    }
    
    struct BoundingBoxCube {
        /// 頂点の位置を示す列挙型
        enum Corner: Int, CaseIterable {
            case minXMinYMinZ = 0
            case maxXMinYMinZ = 1
            case minXMaxYMinZ = 2
            case maxXMaxYMinZ = 3
            case minXMinYMaxZ = 4
            case maxXMinYMaxZ = 5
            case minXMaxYMaxZ = 6
            case maxXMaxYMaxZ = 7
        }
        
        let corners: [Corner:SIMD3<Float>]  // 8頂点
        
        /// イニシャライザ（指定なし時は原点に8頂点）
        init() {
            self.corners = Dictionary(uniqueKeysWithValues: Corner.allCases.map { ($0, SIMD3<Float>(0, 0, 0)) })
        }

        /// イニシャライザ（全頂点指定）
        init(corners: [Corner: SIMD3<Float>]) {
            self.corners = corners
        }
        
        var edges: [(SIMD3<Float>, SIMD3<Float>)] {
            let edgeIndices: [(Corner, Corner)] = [
                (.minXMinYMinZ, .maxXMinYMinZ),
                (.minXMaxYMinZ, .maxXMaxYMinZ),
                (.minXMinYMaxZ, .maxXMinYMaxZ),
                (.minXMaxYMaxZ, .maxXMaxYMaxZ),
                (.minXMinYMinZ, .minXMaxYMinZ),
                (.maxXMinYMinZ, .maxXMaxYMinZ),
                (.minXMinYMaxZ, .minXMaxYMaxZ),
                (.maxXMinYMaxZ, .maxXMaxYMaxZ),
                (.minXMinYMinZ, .minXMinYMaxZ),
                (.maxXMinYMinZ, .maxXMinYMaxZ),
                (.minXMaxYMinZ, .minXMaxYMaxZ),
                (.maxXMaxYMinZ, .maxXMaxYMaxZ)
            ]
            
            return edgeIndices.map { (corners[$0.0]!, corners[$0.1]!) }
        }
        
        var center: SIMD3<Float> {
            let sum = corners.values.reduce(SIMD3<Float>.zero, +)
            return sum / Float(corners.count)
        }
        
        func isPointInside(_ point: SIMD3<Float>) -> Bool {
            let minX = corners[.minXMinYMinZ]!.x
            let maxX = corners[.maxXMaxYMaxZ]!.x
            let minY = corners[.minXMinYMinZ]!.y
            let maxY = corners[.maxXMaxYMaxZ]!.y
            let minZ = corners[.minXMinYMinZ]!.z
            let maxZ = corners[.maxXMaxYMaxZ]!.z
            
            return (point.x >= minX &&
                    point.x <= maxX &&
                    point.y >= minY &&
                    point.y <= maxY &&
                    point.z >= minZ &&
                    point.z <= maxZ)
        }
    }
    
    /// [ExternalStroke] 全体で最も端の位置を取得する
    ///  - Returns: 最も端の位置（直方体の8頂点）
    private func generateBoundingBox() {
        guard !self.tmpStrokes.isEmpty else { return }
        
        var minX: Float = .greatestFiniteMagnitude
        var minY: Float = .greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var maxY: Float = -.greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude
        
        for stroke in self.tmpStrokes {
            for point in stroke.points {
                minX = Swift.min(minX, point.x)
                minY = Swift.min(minY, point.y)
                minZ = Swift.min(minZ, point.z)
                maxX = Swift.max(maxX, point.x)
                maxY = Swift.max(maxY, point.y)
                maxZ = Swift.max(maxZ, point.z)
            }
        }
        
        tmpBoundingBox = BoundingBoxCube(corners: [
            .minXMinYMinZ: SIMD3<Float>(minX, minY, minZ),
            .maxXMinYMinZ: SIMD3<Float>(maxX, minY, minZ),
            .minXMaxYMinZ: SIMD3<Float>(minX, maxY, minZ),
            .maxXMaxYMinZ: SIMD3<Float>(maxX, maxY, minZ),
            .minXMinYMaxZ: SIMD3<Float>(minX, minY, maxZ),
            .maxXMinYMaxZ: SIMD3<Float>(maxX, minY, maxZ),
            .minXMaxYMaxZ: SIMD3<Float>(minX, maxY, maxZ),
            .maxXMaxYMaxZ: SIMD3<Float>(maxX, maxY, maxZ)
        ])
    }
    
    private func updateBoundingBox(matrix: simd_float4x4) {
        // すべてのコーナーを変換
        var newCorners: [PaintingCanvas.BoundingBoxCube.Corner: SIMD3<Float>] = [:]
        for corner in tmpBoundingBox.corners {
            let transformedPosition = matrix * SIMD4<Float>(corner.value.x, corner.value.y, corner.value.z, 1.0)
            newCorners[corner.key] = SIMD3<Float>(transformedPosition.x, transformedPosition.y, transformedPosition.z)
        }
        tmpBoundingBox = BoundingBoxCube(corners: newCorners)
    }
}
