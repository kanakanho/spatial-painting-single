//
//  ExternalFileStorage.swift
//  facetracking-and-overlay
//
//  Created by blueken on 2025/05/24.
//

import ARKit
import RealityKit
import UIKit

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
    func writeStroke(externalStrokes : [ExternalStroke], image: UIImage) {
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
            
            guard let imageData = image.pngData() else {
                print("Error converting image to PNG data")
                return
            }
            try imageData.write(to: imageFileURL)
            print("Image written to: \(imageFileURL.path)")
        } catch {
            print("Error writing file: \(error)")
        }
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
