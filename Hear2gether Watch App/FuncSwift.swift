//
//  FuncSwift.swift
//  Heartbeat Watch App
//
//  Created by Applied Haptics Laboratory on 2024/05/11.
//

import SwiftUI
import HealthKit
import WatchKit
import Foundation
import WatchConnectivity
import Foundation

//振動パターンの提示に利用
import Combine

import HealthKit
import AVFoundation
import Kingfisher

//----------------見た目に関する構造体群----------------//
//ダークモードとライトモード用の色指定（白黒反転状態です）
struct ColorManager {
    static let baseColor = Color("Darkmode")
}

/*
// ハートビュー：scale と opacity は値として受け取る
struct HeartView: View {
    let scale: CGFloat
    let opacity: Double
    var color: Color = .red
    
    var body: some View {
        Image(systemName: "heart.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: 60, height: 60)
            .scaleEffect(scale)
            .opacity(opacity)
    }
}

// リップル（波紋）ビューは ON状態でのみ利用
struct RippleView: View {
    @Binding var scale: CGFloat
    @Binding var opacity: Double
    
    var body: some View {
        ZStack {
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.red)
                .frame(width: 60, height: 60)
                .scaleEffect(scale)
                .opacity(opacity)
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .scaleEffect(scale - 0.3)
                .opacity(opacity)
        }
    }
}
 */

//NowTime の値に基づいて枠線のスタイルを選択
func borderStyle(for time: Int) -> LinearGradient {
    switch time {
    case 0:
        return LinearGradient(gradient: Gradient(colors: [.gray]), startPoint: .topLeading, endPoint: .bottomTrailing)
    case 1:
        return LinearGradient(gradient: Gradient(colors: [.brown,.black]), startPoint: .topLeading, endPoint: .bottomTrailing)
    case 2:
        return LinearGradient(gradient: Gradient(colors: [.purple, .red, .yellow]), startPoint: .topLeading, endPoint: .bottomTrailing)
    default:
        return LinearGradient(gradient: Gradient(colors: [.gray]), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

//NowTime の値に基づいて画像の透明度を選択
func imageOpacity(for time: Int) -> Double {
    switch time {
    case 0:
        return 0.5 // 完全に不透明
    case 1:
        return 1.0 // やや透明
    case 2:
        return 1.0 // 半透明
    default:
        return 1.0
    }
}

// NowTime の値に基づいて画像の透明度を選択
func imagecolor(for time: Int) -> Color {
    switch time {
    case 0:
        return .cyan // 灰色
    case 1:
        return .blue // 青
    case 2:
        return .blue // 青
    default:
        return .gray
    }
}

/*
struct CustomImageView: View {
    var imageURL: URL?
    var nowTime: Int = 0
    @State private var isLoading = false // 画像の読み込み状態
    
    // nowTime の値に基づいて枠線のスタイルを選択
    func borderStyle(for time: Int) -> LinearGradient {
        switch time {
        case 0:
            return LinearGradient(gradient: Gradient(colors: [.gray]), startPoint: .topLeading, endPoint: .bottomTrailing)
        case 1:
            return LinearGradient(gradient: Gradient(colors: [.brown, .black]), startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2:
            return LinearGradient(gradient: Gradient(colors: [.purple, .red, .yellow]), startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(gradient: Gradient(colors: [.gray]), startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    // nowTime の値に基づいて画像の透明度を選択
    func imageOpacity(for time: Int) -> Double {
        switch time {
        case 0:
            return 0.5 // 半透明
        case 1:
            return 1.0 // 完全に不透明
        case 2:
            return 1.0 // 完全に不透明
        default:
            return 1.0
        }
    }
    
    // nowTime の値に基づいて画像の色を選択
    func imageColor(for time: Int) -> Color {
        switch time {
        case 0:
            return .cyan // シアン
        case 1:
            return .blue // 青
        case 2:
            return .blue // 青
        default:
            return .gray // グレー
        }
    }
    
    var body: some View {
        ZStack {
            // 画像部分
            Circle()
                .frame(width: 100, height: 100)
                .overlay(
                    KFImage(imageURL)
                        .onSuccess { _ in isLoading = false } // 読み込み成功時
                        .onFailure { _ in isLoading = false } // 読み込み失敗時
                        .onProgress { _, _ in isLoading = true } // 読み込み中
                        .resizable()
                        .opacity(imageOpacity(for: nowTime))
                        .aspectRatio(contentMode: .fill) // 画像をフレームに合わせて切り取る
                        .frame(width: 100, height: 100) // 丸い部分と同じサイズにする
                        .clipShape(Circle()) // 画像を丸型に切り取る
                        .overlay(
                            Circle().stroke(borderStyle(for: nowTime), lineWidth: 10)
                        )
                )
                .clipShape(Circle()) // 画像を丸型に切り取る
            
        }
    }
}
*/
