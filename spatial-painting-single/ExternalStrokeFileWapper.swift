//
//  ExternalFileStorage.swift
//  facetracking-and-overlay
//
//  Created by blueken on 2025/05/24.
//

import ARKit
import RealityKit
import UIKit
import ImageIO

class ExternalStrokeFileWapper {
    private let documentDirectory: URL
    private var fileDir: URL
    
    init() {
        self.documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileDir = documentDirectory.appendingPathComponent("StrokeCanvas/")
        // ディレクトリが存在しない場合は作成
        if !FileManager.default.fileExists(atPath: fileDir.path) {
            do {
                try FileManager.default.createDirectory(at: fileDir, withIntermediateDirectories: true, attributes: nil)
                print("Directory created at: \(fileDir.path)")
            } catch {
                print("Error creating directory: \(error)")
            }
        }
    }
    
    /// 外部に保存する
    func writeStroke(externalStrokes : [ExternalStroke], displayScale: CGFloat) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let nowDate = Date()
        let jsonFileURL = fileDir.appendingPathComponent("\(formattedDate(nowDate))/strokes.json")
        let imageFileURL = fileDir.appendingPathComponent("\(formattedDate(nowDate))/thumbnail.png")
        do {
            // 先にディレクトリを作成
            let directoryURL = jsonFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            
            let data = try encoder.encode(externalStrokes)
            try data.write(to: jsonFileURL)
            print("File written to: \(jsonFileURL.path)")
            
            guard let imageData = makePNGData(strokes: externalStrokes, planeNormal: SIMD3<Float>(0,0,-1), planePoint: SIMD3<Float>(0,0,0), displayScale: displayScale) else {
                print("Error converting image to PNG data")
                return
            }
            try imageData.write(to: imageFileURL)
            print("Image written to: \(imageFileURL.path)")
        } catch {
            print("Error writing file: \(error)")
        }
    }
    
    /// ストロークから画像を作る
    private func makePNGData(strokes: [ExternalStroke], planeNormal: SIMD3<Float>, planePoint: SIMD3<Float>, displayScale: CGFloat) -> Data? {
        let canvasSize = CGSize(width: 1024, height: 1024)
        let n = normalize(planeNormal)
        let arbitrary: SIMD3<Float> = abs(n.x) < 0.9 ? [1,0,0] : [0,1,0]
        let u = normalize(cross(n, arbitrary)), v = cross(n, u)
        
        // 2D 射影＋バウンディング計算
        var all2D: [[SIMD2<Float>]] = []
        var minX = Float.greatestFiniteMagnitude, maxX = -Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude, maxY = -Float.greatestFiniteMagnitude
        for stroke in strokes {
            var proj: [SIMD2<Float>] = []
            for p in stroke.points {
                let pProj = p - dot(p - planePoint, n) * n
                let x = dot(pProj - planePoint, u), y = dot(pProj - planePoint, v)
                proj.append([x,y])
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
            all2D.append(proj)
        }
        
        // スケーリング
        let inset: CGFloat = 50
        let wF = maxX - minX, hF = maxY - minY
        let scale = min((canvasSize.width - inset*2)/CGFloat(wF),
                        (canvasSize.height - inset*2)/CGFloat(hF))
        
        // CGContext 作成
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: nil,
                width: Int(canvasSize.width * displayScale),
                height: Int(canvasSize.height * displayScale),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: cs,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        ctx.scaleBy(x: displayScale, y: displayScale)
        ctx.setLineCap(.round)
        ctx.setLineWidth(4)
        
        // 描画
        for (idx, stroke) in strokes.enumerated() {
            ctx.setStrokeColor(stroke.color)
            let proj = all2D[idx]
            guard proj.count > 1 else { continue }
            ctx.beginPath()
            let first = proj[0]
            ctx.move(to: CGPoint(
                x: CGFloat(first.x - minX)*scale + inset,
                y: CGFloat(maxY - first.y)*scale + inset
            ))
            for pt in proj.dropFirst() {
                ctx.addLine(to: CGPoint(
                    x: CGFloat(pt.x - minX)*scale + inset,
                    y: CGFloat(maxY - pt.y)*scale + inset
                ))
            }
            ctx.strokePath()
        }
        
        guard let cgImg = ctx.makeImage() else { return nil }
        
        // 90° 回転
        let finalImage = rotateCGImage90Clockwise(cgImg) ?? cgImg
        
        // CGImageDestination で PNG データ化
        let mutableData = CFDataCreateMutable(nil, 0)!
        guard let dest = CGImageDestinationCreateWithData(
            mutableData,
            "public.png" as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(dest, finalImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            return nil
        }
        return mutableData as Data
    }
    
    /// CGImage を 90° 時計回りに回転した新しい CGImage を返す
    func rotateCGImage90Clockwise(_ image: CGImage) -> CGImage? {
        let w = image.width
        let h = image.height
        
        guard
            let colorSpace = image.colorSpace,
            let ctx = CGContext(
                data: nil,
                width: h,               // 幅と高さを反転
                height: w,
                bitsPerComponent: image.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: image.bitmapInfo.rawValue
            )
        else {
            return nil
        }
        
        // 原点を左下（新コンテキストの (0,w)）に移動
        ctx.translateBy(x: 0, y: CGFloat(w))
        // -90° 回転 (radians)
        ctx.rotate(by: -CGFloat.pi/2)
        // 元画像を描画
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
        return ctx.makeImage()
    }
    
    /// ディレクトリの一覧を取得する
    func listDirs() -> [URL] {
        do {
            let fileManager = FileManager.default
            let directories = try fileManager.contentsOfDirectory(at: fileDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            // ディレクトリのみをフィルタリング
            let dirs = directories.filter { $0.hasDirectoryPath }
            print("Directories found: \(dirs)")
            return dirs
        } catch {
            print("Error listing files: \(error)")
            return []
        }
    }
    
    /// jsonを取得する
    func readStrokes(in dateStr: String) -> [ExternalStroke] {
        do {
            let jsonFileURL = fileDir.appendingPathComponent("\(dateStr)/strokes.json")
            let data = try Data(contentsOf: jsonFileURL)
            let decoder = JSONDecoder()
            let strokes = try decoder.decode([ExternalStroke].self, from: data)
            return strokes
        }
        catch {
            print("Error reading JSON file: \(error)")
            return []
        }
    }
    
    /// 画像を取得する
    func readImage(in dateStr: String) -> UIImage? {
        let imageFileURL = fileDir.appendingPathComponent("\(dateStr)/thumbnail.png")
        if let imageData = try? Data(contentsOf: imageFileURL) {
            return UIImage(data: imageData)
        } else {
            print("Error reading image file at \(imageFileURL.path)")
            return nil
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: date)
    }
}
