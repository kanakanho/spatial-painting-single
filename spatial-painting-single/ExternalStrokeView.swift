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
    
    @Environment(\.displayScale) private var displayScale: CGFloat
    
    var externalStrokeFileWapper: ExternalStrokeFileWapper = ExternalStrokeFileWapper()
    
    @State private var imageURLs: [URL] = []
    @State private var selectedURL: URL?
    
    @State var fileList: [String] = []
    @State var selectedFile: String = ""
    
    @State private var isLoading: Bool = false
    @State private var isDeleteMode: Bool = false
    
    var body: some View {
        VStack {
            if isDeleteMode {
                VStack(spacing: 0) {
                    // サムネイルグリッド
                    ThumbnailDeleteGridView(
                        imageURLs: $imageURLs,
                        selectedURL: $selectedURL
                    )
                    // 選択中のファイルを下部に表示
                    if let url = selectedURL {
                        let comps = url.pathComponents
                        Text("Selected: \(comps[comps.count - 2])")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                    }
                }
                //.onAppear(perform: loadThumbnails)
                .ignoresSafeArea(edges: .bottom)
                
                // ファイル読み込み
                Button("Delete File") {
                    // 選択されたファイルを削除
                    if let selectedImageURL = selectedURL {
                        externalStrokeFileWapper.deleteStroke(in: selectedImageURL)
                    }
                    fileList = externalStrokeFileWapper.listDirs().map { $0.lastPathComponent }.sorted(by: >)
                    imageURLs = loadThumbnails()
                    selectedURL = nil
                }
                .padding(.bottom, 20)
            } else {
                // 保存
                Button("Save Stroke") {
                    let externalStrokes: [ExternalStroke] = .init(strokes: model.canvas.strokes, initPoint: .one)
                    externalStrokeFileWapper.writeStroke(externalStrokes: externalStrokes, displayScale: displayScale)
                    fileList = externalStrokeFileWapper.listDirs().map { $0.lastPathComponent }.sorted(by: >)
                    imageURLs = loadThumbnails()
                    if fileList.count == 1 {
                        selectedFile = fileList[0]
                    }
                }
                .padding(.top, 20)
                
                VStack(spacing: 0) {
                    // サムネイルグリッド
                    ThumbnailGridView(
                        imageURLs: $imageURLs,
                        selectedURL: $selectedURL
                    )
                    // 選択中のファイルを下部に表示
                    if let url = selectedURL {
                        let comps = url.pathComponents
                        Text("Selected: \(comps[comps.count - 2])")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                
                // ファイル読み込み
                Toggle("Load Stroke Mode", isOn: $isLoading)
                    .toggleStyle(.button)
                    .padding(.bottom, 20)
                    .onChange(of: isLoading) {
                        if isLoading {
                            if let comps = selectedURL?.pathComponents {
                                selectedFile = comps[comps.count - 2]
                            }
                            if !selectedFile.isEmpty {
                                let externalStrokes = externalStrokeFileWapper.readStrokes(in: selectedFile)
                                model.canvas.addTmpStrokes(externalStrokes.strokes(initPoint: .one))
                            }
                        } else {
                            model.canvas.clearTmpStrokes()
                        }
                    }
                
                // ロードしたデータの確定
                Button("Confirm Loaded Stroke") {
                    model.canvas.confirmTmpStrokes()
                    // isLoading を false にしてロードモードを終了
                    isLoading = false
                }
                .padding(.bottom, 20)
                .disabled(!model.canvas.tmpStrokes.isEmpty)
                
            }
            Toggle("Delete Mode", isOn: $isDeleteMode)
                .toggleStyle(.button)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            
        }
        .onAppear() {
            fileList = externalStrokeFileWapper.listDirs().map { $0.lastPathComponent }.sorted(by: >)
            imageURLs = loadThumbnails()
            externalStrokeFileWapper.planeNormalVector = model.planeNormalVector
            externalStrokeFileWapper.planePoint = model.planePoint
        }
        .onDisappear {
            isLoading = false
            model.canvas.clearTmpStrokes()
        }
    }
    
    /// Documents/StrokeCanvas 以下をスキャンして thumbnail.png を集める
    private func loadThumbnails() -> [URL] {
        let docDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        let canvasDir = docDir.appendingPathComponent("StrokeCanvas", isDirectory: true)
        
        var urls: [URL] = []
        
        for dir in fileList {
            let thumb = canvasDir.appendingPathComponent(dir+"/thumbnail.png")
            if FileManager.default.fileExists(atPath: thumb.path) {
                urls.append(thumb)
            }
        }
        return urls
    }
}

/// サムネイル一覧＋選択ビュー
struct ThumbnailGridView: View {
    @Binding var imageURLs: [URL]    // サムネイル画像ファイルの URL 一覧
    @Binding var selectedURL: URL?   // 選択中の画像 URL
    
    // Adaptive サイズのカラムレイアウト
    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(imageURLs, id: \.self) { url in
                    if let cg = loadCGImage(from: url) {
                        Button {
                            selectedURL = url
                        } label: {
                            Image(decorative: cg, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipped()
                                .overlay(
                                    // 選択中はアクセントカラーで枠線
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(selectedURL == url
                                                ? Color.accentColor
                                                : Color.clear,
                                                lineWidth: 4
                                               )
                                )
                        }
                        .buttonStyle(.plain) // フォーカス可能に
                    }
                }
            }
            .padding()
        }
    }
    
    /// URL から CGImage を生成
    private func loadCGImage(from url: URL) -> CGImage? {
        guard let data = try? Data(contentsOf: url),
              let src  = CGImageSourceCreateWithData(data as CFData, nil),
              let img  = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else { return nil }
        return img
    }
}

/// サムネイル一覧＋選択ビュー
struct ThumbnailDeleteGridView: View {
    @Binding var imageURLs: [URL]    // サムネイル画像ファイルの URL 一覧
    @Binding var selectedURL: URL?   // 選択中の画像 URL
    
    // Adaptive サイズのカラムレイアウト
    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(imageURLs, id: \.self) { url in
                    if let cg = loadCGImage(from: url) {
                        Button {
                            selectedURL = url
                        } label: {
                            Image(decorative: cg, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipped()
                                .overlay(
                                    // 選択中はアクセントカラーで枠線
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(selectedURL == url
                                                ? Color.red
                                                : Color.clear,
                                                lineWidth: 4
                                               )
                                )
                        }
                        .buttonStyle(.plain) // フォーカス可能に
                    }
                }
            }
            .padding()
        }
    }
    
    /// URL から CGImage を生成
    private func loadCGImage(from url: URL) -> CGImage? {
        guard let data = try? Data(contentsOf: url),
              let src  = CGImageSourceCreateWithData(data as CFData, nil),
              let img  = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else { return nil }
        return img
    }
}

#Preview(windowStyle: .automatic) {
    ExternalStrokeView()
        .environment(AppModel())
        .environment(ViewModel())
}
