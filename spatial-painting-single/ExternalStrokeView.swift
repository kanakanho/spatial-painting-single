//
//  ExportInportView.swift
//  spatial-painting-single
//
//  Created by blueken on 2025/06/24.
//

import SwiftUI

struct ExternalStrokeView: View {
    @Environment(AppModel.self) var appModel
    @Environment(ViewModel.self) var model
    var externalStrokeFileWapper: ExternalStrokeFileWapper = ExternalStrokeFileWapper()
    
    @State var fileList: [String] = []
    @State var selectedFile: String = ""
    
    var body: some View {
        VStack {
            // 保存
            Button("Save Stroke") {
                let externalStrokes: [ExternalStroke] = .init(strokes: model.canvas.strokes, initPoint: .one)
                // 真っ白な 600x600の UIImage を生成
                let size = CGSize(width: 600, height: 600)
                let renderer = UIGraphicsImageRenderer(size: size)
                
                let uiImage = renderer.image { context in
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                    
                    // ここにさらに描画したい内容があれば追加
                    // 例: "Test" という文字列を描く
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 24),
                        .foregroundColor: UIColor.black
                    ]
                    let text = "Stroke Data"
                    text.draw(at: CGPoint(x: 20, y: 20), withAttributes: attributes)
                }
                externalStrokeFileWapper.writeStroke(externalStrokes: externalStrokes, image: uiImage)
                fileList = externalStrokeFileWapper.listDirs().map { $0.lastPathComponent }
                if fileList.count == 1 {
                    selectedFile = fileList[0]
                }
            }
            
            // ファイル選択
            Picker("Select File", selection: $selectedFile) {
                ForEach(fileList, id: \.self) { file in
                    Text(file).tag(file)
                }
            }
            .pickerStyle(.inline)
            
            // ファイル読み込み
            Button("Load Stroke") {
                if !selectedFile.isEmpty {
                    let externalStrokes = externalStrokeFileWapper.readStrokes(in: selectedFile)
                    model.canvas.addStrokes(externalStrokes.strokes(initPoint: .one))
                }
            }
        }
        .onAppear() {
            fileList = externalStrokeFileWapper.listDirs().map { $0.lastPathComponent}
        }
    }
}
