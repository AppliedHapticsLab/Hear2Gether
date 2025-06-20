//
//  UserIconView.swift
//  YourProject
//

import SwiftUI
import Kingfisher
import FirebaseAuth
import FirebaseDatabase

// MARK: - ColorManager拡張
extension ColorManager {
    // グループ関連のカラー
    static let groupHeaderColor = Color(red: 0.95, green: 0.2, blue: 0.3)
    static let groupSecondaryColor = Color(red: 0.98, green: 0.4, blue: 0.5)
    static let groupSubtleColor = Color.white.opacity(0.7)
    static let groupInactiveColor = Color.gray.opacity(0.5)
    
    // ボタンやアクセントのカラー
    static let actionPrimaryColor = Color(red: 0.95, green: 0.2, blue: 0.3)
    static let actionSecondaryColor = Color(red: 0.98, green: 0.4, blue: 0.5)
    
    // Main background and card colors - OnePersonHeartRateViewに合わせる
    static let background = Color(red: 0.08, green: 0.08, blue: 0.1) // 以前はColor.black
    static let cardBackground = Color(red: 0.12, green: 0.12, blue: 0.15) // OnePersonHeartRateViewのcardColorに合わせる
    static let secondaryBackground = Color(red: 0.18, green: 0.18, blue: 0.2) // 変更なし
    
    // Text colors
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.7)
    static let tertiaryText = Color.white.opacity(0.5)
    
    // Accent colors - adjust to match your heart icon red
    static let accent = Color(red: 0.94, green: 0.2, blue: 0.2) // More vibrant red for heart icons
    static let secondaryAccent = Color(red: 0.31, green: 0.64, blue: 0.94) // Blue accent
    
    // Borders and highlights
    static let cardBorder = Color.white.opacity(0.1)
    static let selectedBorder = Color(red: 0.94, green: 0.2, blue: 0.2) // Match heart color
    
    // グラデーション
    static let gradientStart = Color(red: 0.94, green: 0.33, blue: 0.31)
    static let gradientEnd = Color(red: 0.78, green: 0.25, blue: 0.55)
}

// MARK: - ユーザーアイコン表示ビュー (ダークテーマ)
struct UserIconView: View {
    let name: String
    let imageURL: String
    var imageSize: CGFloat = 60
    var isSelected: Bool = false
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let url = URL(string: imageURL), !imageURL.isEmpty {
                    KFImage(url)
                        // ロード中に表示するプレースホルダー
                        .placeholder {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [ColorManager.secondaryBackground, ColorManager.cardBackground]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: imageSize, height: imageSize)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: imageSize/2, height: imageSize/2)
                                        .foregroundColor(ColorManager.secondaryText)
                                )
                        }
                        // 失敗時に差し替える画像
                        .onFailureImage(UIImage(named: "defaultIcon"))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: imageSize, height: imageSize)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(ColorManager.cardBorder, lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                } else {
                    // URL が空文字の場合など
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [ColorManager.secondaryBackground, ColorManager.cardBackground]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: imageSize, height: imageSize)
                        .overlay(
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: imageSize/2, height: imageSize/2)
                                .foregroundColor(ColorManager.secondaryText)
                        )
                        .overlay(
                            Circle()
                                .stroke(ColorManager.cardBorder, lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                }
                
                // 選択状態なら強調枠を表示
                if isSelected {
                    Circle()
                        .stroke(ColorManager.selectedBorder, lineWidth: 3)
                        .frame(width: imageSize + 6, height: imageSize + 6)
                }
            }
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ColorManager.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
    }
}

// MARK: - グループデータ構造体
struct GroupData: Identifiable {
    let id: String
    var groupName: String
    var memberIDs: [String] // このグループに所属するユーザーID一覧
    var hostID: String? // ホストユーザーのID
    var viewerCount: Int = 0 // 閲覧者数
    var isActive: Bool = false // アクティブ状態
    var isBroadcasting: Bool = false // 配信状態
}

// MARK: - RoomSelectionView
struct RoomSelectionView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var viewModeManager: ViewModeManager
    
    var body: some View {
        // NavigationViewをNavigationStackに変更
        NavigationStack {
            ZStack {
                // 背景
                ColorManager.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // トップスペース（ステータスバー用）
                    Color.clear
                        .frame(height: 40)
                    // ヘッダー部分
                    VStack(spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("心拍共有")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(ColorManager.subtleTextColor)
                                
                                Text("ルーム")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(ColorManager.textColor)
                            }
                            
                            Spacer()
                            
                            // 心拍アイコン
                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(ColorManager.accent)
                                .shadow(color: ColorManager.primaryColor.opacity(0.3), radius: 8, x: 0, y: 0)
                        }
                        .padding(.horizontal, 25)
                    }
                    
                    Spacer()
                        .frame(height: 20)
                    
                    // ボタン縦並びレイアウト
                    VStack(spacing: 15) {
                        NavigationLink(destination: AllUserView()) {
                            HStack(spacing: 15) {
                                // アイコン部分
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(viewModeManager.isViewOnlyMode ? ColorManager.primaryColor.opacity(0.3) : ColorManager.primaryColor)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        ColorManager.primaryColor.opacity(viewModeManager.isViewOnlyMode ? 0.2 : 0.8),
                                                        ColorManager.secondaryColor.opacity(viewModeManager.isViewOnlyMode ? 0.2 : 0.8)
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2
                                            )
                                    )
                                    .shadow(color: ColorManager.primaryColor.opacity(viewModeManager.isViewOnlyMode ? 0.1 : 0.3), radius: 5, x: 0, y: 0)
                                
                                // テキスト部分
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ホストの開始")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(viewModeManager.isViewOnlyMode ? ColorManager.textColor.opacity(0.4) : ColorManager.textColor)
                                    
                                    Text("自分がホストとなるルームを選択")
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundColor(viewModeManager.isViewOnlyMode ? ColorManager.subtleTextColor.opacity(0.4) : ColorManager.subtleTextColor)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 20)
                            .padding(.horizontal, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(viewModeManager.isViewOnlyMode ? ColorManager.cardColor.opacity(0.5) : ColorManager.cardColor)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                ColorManager.primaryColor.opacity(viewModeManager.isViewOnlyMode ? 0.1 : 0.3),
                                                ColorManager.secondaryColor.opacity(viewModeManager.isViewOnlyMode ? 0.1 : 0.3)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                        }
                        .disabled(viewModeManager.isViewOnlyMode) // 閲覧モード時は無効化
                        
                        // 「参加するルーム」ボタン
                        NavigationLink(destination: JoinableRoomsView()) {
                            HStack(spacing: 15) {
                                // アイコン部分
                                Image(systemName: "person.2.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(ColorManager.primaryColor)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        ColorManager.primaryColor.opacity(0.8),
                                                        ColorManager.secondaryColor.opacity(0.8)
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2
                                            )
                                    )
                                    .shadow(color: ColorManager.primaryColor.opacity(0.3), radius: 5, x: 0, y: 0)
                                
                                // テキスト部分
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ルームに参加")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(ColorManager.textColor)
                                    
                                    Text("フレンドが作成したルームに参加")
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundColor(ColorManager.subtleTextColor)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 20)
                            .padding(.horizontal, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(ColorManager.cardColor)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                ColorManager.primaryColor.opacity(0.3),
                                                ColorManager.secondaryColor.opacity(0.3)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - OneGroupCircleView (Updated with Broadcasting Features)
struct OneGroupCircleView: View {
    let group: GroupData
    let currentUser: PermittedUser
    
    // Firebase関連など
    @State private var userInfoHandles: [String: DatabaseHandle] = [:]
    @State private var heartRateHandles: [String: DatabaseHandle] = [:]
    
    // メンバー情報
    @State private var permittedUsers: [PermittedUser] = []
    
    // アニメーション用
    @State private var appearPhase: CGFloat = 0.0
    @State private var centerScale: CGFloat = 0.5
    @State private var rotationAngle: Double = 0
    @State private var pulseEffect: CGFloat = 1.0
    
    // 配信状態切り替え用の追加アニメーション
    @State private var broadcastingPulse: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    @State private var broadcastRingScale: CGFloat = 0.8
    @State private var showBroadcastingEffect: Bool = false
    @State private var memberIconsScale: CGFloat = 1.0
    
    // トースト通知用
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var toastIsSuccess: Bool = true
    
    // シート表示制御
    @State private var showAddUserSheet = false
    @State private var showRemoveUserSheet = false
    
    // 追加候補ユーザー
    @State private var allUsers: [PermittedUser] = []
    
    // 配信状態を管理する変数
    @State private var isBroadcasting: Bool = false
    @State private var broadcastingHandle: DatabaseHandle?
    
    // 視聴者数管理
    @State private var viewerCount: Int = 0
    @State private var viewerCountHandle: DatabaseHandle?
    
    var body: some View {
        ZStack {
            // 背景色を他のビューと統一
            ColorManager.background.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 8) {
                // ヘッダー部分 - 上部の余白を削減
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("心拍共有")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(ColorManager.secondaryText)
                            
                            Text(group.groupName)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(ColorManager.primaryText)
                        }
                        
                        Spacer()
                        
                        // 心拍アイコン
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(ColorManager.accent)
                            .shadow(color: ColorManager.accent.opacity(0.3), radius: 8, x: 0, y: 0)
                    }
                    .padding(.horizontal, 25)
                }
                .padding(.top, 0)
                
                // -- (1) 上部カード：グループ名 + 追加/削除ボタン --
                VStack {
                    HStack {
                        // 「ユーザー追加」ボタン
                        Button(action: {
                            showAddUserSheet = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [ColorManager.secondaryAccent, ColorManager.secondaryAccent.opacity(0.7)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "person.badge.plus")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                                    .foregroundColor(ColorManager.primaryText)
                            }
                            .shadow(color: ColorManager.secondaryAccent.opacity(0.5), radius: 5, x: 0, y: 0)
                        }
                        
                        Spacer()
                        
                        // グループ名
                        Text("メンバー管理")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(ColorManager.primaryText)
                        
                        Spacer()
                        
                        // 「ユーザー削除」ボタン
                        Button(action: {
                            showRemoveUserSheet = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [ColorManager.accent, ColorManager.accent.opacity(0.7)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "person.badge.minus")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                                    .foregroundColor(ColorManager.primaryText)
                            }
                            .shadow(color: ColorManager.accent.opacity(0.5), radius: 5, x: 0, y: 0)
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorManager.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ColorManager.cardBorder.opacity(0.5),
                                    ColorManager.cardBorder.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                
                // -- (2) 中央カード：周囲に集まるユーザーアイコン --
                VStack {
                    GeometryReader { geo in
                        ZStack {
                            // 背景の円とエフェクト - サイズを大きく
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            ColorManager.secondaryBackground,
                                            ColorManager.background
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: min(geo.size.width, geo.size.height) * 0.85)
                                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                            
                            // 外側リング
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            ColorManager.gradientStart.opacity(0.4),
                                            ColorManager.gradientEnd.opacity(0.4)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: min(geo.size.width, geo.size.height) * 0.8)
                                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                                .rotationEffect(.degrees(rotationAngle))
                            
                            // 中央アイコン
                            ZStack {
                                // 配信中の場合のみ表示される効果
                                if showBroadcastingEffect {
                                    // グロー効果
                                    Circle()
                                        .fill(ColorManager.accent)
                                        .frame(width: 100, height: 100)
                                        .opacity(glowOpacity)
                                        .blur(radius: 15)
                                    
                                    // 配信波紋 - 拡散する円
                                    ForEach(0..<3) { i in
                                        Circle()
                                            .stroke(ColorManager.accent.opacity(0.7 - Double(i) * 0.2), lineWidth: 3)
                                            .frame(width: 90 + CGFloat(i * 25))
                                            .scaleEffect(broadcastRingScale * broadcastingPulse)
                                    }
                                }
                                
                                // 脈拍を示す波紋アニメーション
                                ForEach(0..<3) { i in
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    ColorManager.gradientStart.opacity(0.5 - Double(i) * 0.15),
                                                    ColorManager.gradientEnd.opacity(0.5 - Double(i) * 0.15)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                        .frame(width: 80 + CGFloat(i * 20))
                                        .scaleEffect(centerScale * pulseEffect)
                                        .opacity(Double(1 - (i * 20) % 100) / 100.0)
                                }
                                
                                UserIconView(
                                    name: currentUser.name,
                                    imageURL: currentUser.imageURL,
                                    imageSize: 80,
                                    isSelected: true
                                )
                                .scaleEffect(centerScale)
                                .onTapGesture {
                                    toggleBroadcasting()
                                }
                                
                                if isBroadcasting {
                                    VStack(spacing: 4) {
                                        Text("ライブ配信中")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(ColorManager.accent)
                                                    .shadow(color: ColorManager.accent.opacity(0.5), radius: 5, x: 0, y: 0)
                                            )
                                        
                                        // 視聴者数表示を追加
                                        if viewerCount > 0 {
                                            HStack(spacing: 4) {
                                                Image(systemName: "eye.fill")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.white)
                                                
                                                Text("\(viewerCount)")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(Color.black.opacity(0.6))
                                            )
                                        }
                                    }
                                    .offset(y: 60)
                                }
                            }
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                            
                            let centerPt = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                            let radius = min(geo.size.width, geo.size.height) * 0.37 // 縁との間隔を確保
                            
                            let circleMembers = permittedUsers.filter { $0.id != currentUser.id }
                            
                            ForEach(Array(circleMembers.enumerated()), id: \.element.id) { (idx, user) in
                                let angle = Angle(degrees: Double(idx) / Double(circleMembers.count) * 360)
                                let startFactor: CGFloat = 1.8
                                let currentRadius = radius + (radius * (startFactor - 1)) * (1 - appearPhase)
                                let currentX = centerPt.x + currentRadius * CGFloat(cos(angle.radians))
                                let currentY = centerPt.y + currentRadius * CGFloat(sin(angle.radians))
                                
                                let scale = 0.5 + 0.5 * appearPhase
                                let opacity = Double(appearPhase)
                                
                                ZStack {
                                    // 心拍数がある場合は表示
                                    if user.heartRate > 0 {
                                        VStack(spacing: 2) {
                                            UserIconView(
                                                name: user.name,
                                                imageURL: user.imageURL,
                                                imageSize: 60,
                                                isSelected: false
                                            )
                                            
                                            HStack(spacing: 2) {
                                                Image(systemName: "heart.fill")
                                                    .foregroundColor(ColorManager.accent)
                                                    .font(.system(size: 10))
                                                
                                                Text("\(user.heartRate)")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(ColorManager.accent)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule()
                                                    .fill(ColorManager.cardBackground.opacity(0.9))
                                                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                                            )
                                        }
                                    } else {
                                        UserIconView(
                                            name: user.name,
                                            imageURL: user.imageURL,
                                            imageSize: 60,
                                            isSelected: false
                                        )
                                    }
                                }
                                .scaleEffect(scale * memberIconsScale)
                                .opacity(opacity)
                                .position(x: currentX, y: currentY)
                                .animation(.spring(response: 0.5), value: memberIconsScale)
                            }
                            
                            // グループの人数の表示 - Apple Watchスタイル
                            Text("\(permittedUsers.count)人のメンバー")
                                .font(.caption)
                                .foregroundColor(ColorManager.secondaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(ColorManager.cardBackground.opacity(0.9))
                                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(ColorManager.cardBorder, lineWidth: 1)
                                )
                                .position(x: geo.size.width / 2, y: geo.size.height - 30)
                                
                            // メンバーが多い場合のページインジケーター
                            if permittedUsers.count > 7 {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(ColorManager.accent)
                                        .frame(width: 8, height: 8)
                                    
                                    Circle()
                                        .fill(ColorManager.tertiaryText)
                                        .frame(width: 8, height: 8)
                                }
                                .position(x: geo.size.width / 2, y: geo.size.height - 60)
                            }
                        }
                    }
                    .frame(height: 420) // 縦方向のスペースを拡大
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorManager.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ColorManager.cardBorder.opacity(0.5),
                                    ColorManager.cardBorder.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                
                // -- (3) 下部カード：グループ削除ボタン --
                VStack {
                    Button(action: {
                        deleteGroup()
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16))
                                .foregroundColor(ColorManager.primaryText)
                            
                            Text("このルームを削除")
                                .foregroundColor(ColorManager.primaryText)
                                .font(.headline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [ColorManager.accent, ColorManager.accent.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: ColorManager.accent.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .padding()
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorManager.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ColorManager.cardBorder.opacity(0.5),
                                    ColorManager.cardBorder.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // トースト通知
            if showToast {
                VStack {
                    Spacer()
                    ToastView(message: toastMessage, isSuccess: toastIsSuccess)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(100) // 最前面に表示
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 歯車アイコンを削除
        }
        .onAppear {
            // ユーザー情報ロード
            loadGroupMembers()
            loadFriendUsers()
            checkBroadcastingStatus()
            observeViewerCount()
            
            // ルームのアクティブ状態を更新
            updateRoomActiveStatus(isActive: true)
            
            // アニメーションを開始
            withAnimation(.easeInOut(duration: 1.0)) {
                centerScale = 1.0
            }
            
            // 0.5秒後に周囲のアイコンをフェードイン
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 1.5)) {
                    appearPhase = 1.0
                }
            }
            
            // 回転アニメーション
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            
            // 脈動アニメーション
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseEffect = 1.1
            }
            
            // 起動時から配信中なら効果を表示
            if isBroadcasting {
                showBroadcastingEffect = true
                glowOpacity = 0.6
                broadcastRingScale = 1.3
                
                // 波紋アニメーション
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    broadcastingPulse = 1.2
                }
            }
        }
        .onDisappear {
            // 配信中の場合は停止
            if isBroadcasting {
                toggleBroadcasting()
            }
            
            // ルームのアクティブ状態を更新
            updateRoomActiveStatus(isActive: false)
            
            removeAllObservers()
        }
        // -- シート：ユーザー追加 --
        .sheet(isPresented: $showAddUserSheet) {
            AddUserSheetView(allUsers: allUsers) { selectedUsers in
                for user in selectedUsers {
                    addMember(user: user)
                }
            }
        }
        // -- シート：ユーザー削除 --
        .sheet(isPresented: $showRemoveUserSheet) {
            RemoveUserSheetView(
                users: permittedUsers.filter { $0.id != currentUser.id },
                groupOwnerID: currentUser.id,
                groupID: group.id
            )
        }
    }
    
    // MARK: - ルームのアクティブ状態を更新するメソッド
    private func updateRoomActiveStatus(isActive: Bool) {
        guard !currentUser.id.isEmpty else { return }
        
        let ref = Database.database().reference()
        let activeRef = ref.child("Userdata").child(currentUser.id)
            .child("Groups").child(group.id).child("active")
        
        activeRef.setValue(isActive)
        
        // 退室時に配信も停止する
        if !isActive && isBroadcasting {
            toggleBroadcasting()
        }
    }
    
    // MARK: - 視聴者数を監視
    private func observeViewerCount() {
        guard !currentUser.id.isEmpty else { return }
        
        let ref = Database.database().reference()
        // 1. まずユーザーデータの視聴者リストを監視
        let viewersRef = ref.child("Userdata").child(currentUser.id)
            .child("Groups").child(group.id).child("viewers")
        
        viewerCountHandle = viewersRef.observe(.value) { snapshot in
            var count = 0
            for _ in snapshot.children {
                count += 1
            }
            
            DispatchQueue.main.async {
                self.viewerCount = count
            }
        }
        
        // 2. 配信中の場合は公開リストの視聴者数も監視
        if isBroadcasting {
            let publicViewerRef = ref.child("BroadcastingRooms").child(group.id).child("viewerCount")
            publicViewerRef.observe(.value) { snapshot in
                if let count = snapshot.value as? Int {
                    DispatchQueue.main.async {
                        self.viewerCount = count
                    }
                }
            }
        }
    }
    
    private func toggleBroadcasting() {
        // 変更前の状態を保存
        _ = isBroadcasting
        
        // メンバーアイコンのアニメーション
        if !isBroadcasting {
            // 配信開始時に一瞬大きくなってから戻る
            memberIconsScale = 1.2
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring()) {
                    memberIconsScale = 1.0
                }
            }
        } else {
            // 配信停止時に一瞬小さくなってから戻る
            memberIconsScale = 0.8
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring()) {
                    memberIconsScale = 1.0
                }
            }
        }
        
        // 状態を切り替え
        isBroadcasting.toggle()
        
        // Firebaseに配信状態を保存
        let ref = Database.database().reference()
        
        // 1. ルーム情報の配信状態を更新
        let broadcastRef = ref.child("Userdata").child(currentUser.id)
            .child("Groups").child(group.id)
        
        broadcastRef.updateChildValues(["broadcasting": isBroadcasting]) { (error, _) in
            if let error = error {
                print("配信状態の更新に失敗しました: \(error.localizedDescription)")
            } else {
                print("配信状態を更新しました: \(isBroadcasting ? "配信中" : "配信停止")")
            }
        }
        
        // 2. 公開用の配信中ルームリストにも追加/削除（検索しやすいように）
        let publicBroadcastRef = ref.child("BroadcastingRooms").child(group.id)
        
        if isBroadcasting {
            // 公開用リストに追加
            let broadcastData: [String: Any] = [
                "groupName": group.groupName,
                "hostID": currentUser.id,
                "hostName": currentUser.name,
                "startedAt": ServerValue.timestamp(),
                "memberCount": group.memberIDs.count,
                "viewerCount": 0 // 初期視聴者数
            ]
            publicBroadcastRef.setValue(broadcastData)
            
            // 視聴者数の監視を開始
            observeViewerCount()
            
            // 3. 現在のグループURLに現在のグループ名を保存
            let currentGroupRef = ref.child("Userdata").child(currentUser.id).child("CurrentGroup")
            let currentGroupData: [String: Any] = [
                "groupID": group.id,
                "hostID": currentUser.id,
                "isActive": true
            ]
            currentGroupRef.setValue(currentGroupData) { (error, _) in
                if let error = error {
                    print("現在のグループ情報の更新に失敗しました: \(error.localizedDescription)")
                } else {
                    print("現在のグループ情報を更新しました: \(group.groupName)")
                }
            }
        } else {
            // 公開用リストから削除
            publicBroadcastRef.removeValue()
            
            // 配信停止時に現在のグループ情報も非アクティブに設定
            let currentGroupRef = ref.child("Userdata").child(currentUser.id).child("CurrentGroup")
            currentGroupRef.updateChildValues(["isActive": false]) { (error, _) in
                if let error = error {
                    print("現在のグループ情報の非アクティブ化に失敗しました: \(error.localizedDescription)")
                } else {
                    print("現在のグループ情報を非アクティブにしました")
                }
            }
        }
        
        // 配信開始アニメーション
        if isBroadcasting {
            // 配信開始時のアニメーション
            withAnimation(.easeOut(duration: 0.3)) {
                showBroadcastingEffect = true
                glowOpacity = 0.6
            }
            
            // 波紋アニメーション
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                broadcastingPulse = 1.2
            }
            
            // 拡大アニメーション
            withAnimation(.easeOut(duration: 0.8)) {
                broadcastRingScale = 1.3
            }
            
            // 振動フィードバック
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
        } else {
            // 配信停止時のアニメーション
            withAnimation(.easeOut(duration: 0.5)) {
                glowOpacity = 0
                broadcastRingScale = 0.8
            }
            
            // アニメーションが終わったら効果を非表示に
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showBroadcastingEffect = false
                }
            }
            
            // 振動フィードバック
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
        
        // 状態変更時のポップアップメッセージ
        let impactText = isBroadcasting ? "心拍配信を開始しました" : "心拍配信を停止しました"
        
        // トースト表示
        withAnimation(.spring()) {
            showToast = true
            toastMessage = impactText
            toastIsSuccess = isBroadcasting
        }
        
        // 3秒後に非表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut) {
                showToast = false
            }
        }
    }
    
    // MARK: - グループ削除処理
    private func deleteGroup() {
        // ここで「グループ自体を削除する」Firebaseアクセス等を実装
        let ref = Database.database().reference()
        
        // 配信中なら停止
        if isBroadcasting {
            toggleBroadcasting()
        }
        
        // グループの公開情報を削除
        ref.child("BroadcastingRooms").child(group.id).removeValue()
        
        // ユーザーのグループを削除
        let groupRef = ref.child("Userdata").child(currentUser.id)
            .child("Groups").child(group.id)
        groupRef.removeValue { error, _ in
            // エラーがなければ削除成功
        }
        print("グループを削除しました")
    }
    
    // 配信状態を確認するメソッド
    private func checkBroadcastingStatus() {
        let ref = Database.database().reference()
        let broadcastRef = ref.child("Userdata").child(currentUser.id)
            .child("Groups").child(group.id).child("broadcasting")
        
        broadcastingHandle = broadcastRef.observe(.value) { snapshot in
            if let value = snapshot.value as? Bool {
                DispatchQueue.main.async {
                    self.isBroadcasting = value
                    
                    // 配信状態に応じてエフェクトを調整
                    if value && !self.showBroadcastingEffect {
                        self.showBroadcastingEffect = true
                        self.glowOpacity = 0.6
                        self.broadcastRingScale = 1.3
                        
                        // 波紋アニメーション
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            self.broadcastingPulse = 1.2
                        }
                    } else if !value && self.showBroadcastingEffect {
                        withAnimation {
                            self.glowOpacity = 0
                            self.broadcastRingScale = 0.8
                            self.showBroadcastingEffect = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - グループメンバー情報取得
    private func loadGroupMembers() {
        let ref = Database.database().reference()
        permittedUsers.removeAll()
        
        // グループに含まれるmemberIDsを順に取得
        for uid in group.memberIDs {
            let infoHandle = ref.child("Username").child(uid)
                .observe(.value) { snapshot in
                    if let dict = snapshot.value as? [String: Any] {
                        DispatchQueue.main.async {
                            if let idx = permittedUsers.firstIndex(where: { $0.id == uid }) {
                                // すでに存在する場合→更新
                                permittedUsers[idx].name = dict["UName"] as? String ?? "不明なユーザー"
                                permittedUsers[idx].imageURL = dict["Uimage"] as? String ?? ""
                            } else {
                                // 新規追加
                                let newUser = PermittedUser(
                                    id: uid,
                                    name: dict["UName"] as? String ?? "不明なユーザー",
                                    imageURL: dict["Uimage"] as? String ?? "",
                                    heartRate: 0
                                )
                                permittedUsers.append(newUser)
                            }
                        }
                    }
                }
            userInfoHandles[uid] = infoHandle
            
            // 心拍数の監視
            let hrHandle = ref.child("Userdata").child(uid)
                .child("Heartbeat").child("Watch1").child("HeartRate")
                .observe(.value) { snapshot in
                    var rate: Int = 0
                    if let intRate = snapshot.value as? Int {
                        rate = intRate
                    } else if let strRate = snapshot.value as? String,
                              let intVal = Int(strRate) {
                        rate = intVal
                    }
                    DispatchQueue.main.async {
                        if let idx = permittedUsers.firstIndex(where: { $0.id == uid }) {
                            permittedUsers[idx].heartRate = rate
                        }
                    }
                }
            heartRateHandles[uid] = hrHandle
        }
        
        // 中央ユーザーもリストに含める
        if !permittedUsers.contains(where: { $0.id == currentUser.id }) {
            permittedUsers.append(currentUser)
        }
    }
    
    // MARK: - フレンド登録されているユーザー取得
    private func loadFriendUsers() {
        guard !currentUser.id.isEmpty else { return }
        
        let ref = Database.database().reference()
        let acceptUserRef = ref.child("AcceptUser")
            .child(currentUser.id)
            .child("permittedUser")
        
        acceptUserRef.observeSingleEvent(of: .value) { snapshot in
            var friendUIDs: [String] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let allowed = child.value as? Bool, allowed == true {
                    friendUIDs.append(child.key)
                }
            }
            
            var tempList: [PermittedUser] = []
            let group = DispatchGroup()
            
            for uid in friendUIDs {
                group.enter()
                ref.child("Username").child(uid)
                    .observeSingleEvent(of: .value) { userSnapshot in
                        if let dict = userSnapshot.value as? [String: Any] {
                            let uname = dict["UName"] as? String ?? "不明なユーザー"
                            let uimage = dict["Uimage"] as? String ?? ""
                            let newUser = PermittedUser(id: uid, name: uname, imageURL: uimage, heartRate: 0)
                            tempList.append(newUser)
                        }
                        group.leave()
                    }
            }
            
            group.notify(queue: .main) {
                self.allUsers = tempList
            }
        }
    }
    
    // MARK: - メンバー追加/削除
    private func removeMember(user: PermittedUser) {
        guard !currentUser.id.isEmpty else { return }
        let currentUserID = currentUser.id
        
        let ref = Database.database().reference()
        let groupRef = ref
            .child("Userdata").child(currentUserID)
            .child("Groups").child(group.id)
        
        groupRef.observeSingleEvent(of: .value) { snapshot in
            guard var groupDict = snapshot.value as? [String: Any] else { return }
            guard var members = groupDict["members"] as? [String] else { return }
            
            members.removeAll { $0 == user.id }
            groupDict["members"] = members
            groupRef.setValue(groupDict)
            
            // 配信中の場合はメンバー数も更新
            if self.isBroadcasting {
                ref.child("BroadcastingRooms").child(self.group.id)
                    .updateChildValues(["memberCount": members.count])
            }
        }
        
        if let idx = permittedUsers.firstIndex(where: { $0.id == user.id }) {
            permittedUsers.remove(at: idx)
        }
    }
    
    private func addMember(user: PermittedUser) {
        guard !currentUser.id.isEmpty else { return }
        let currentUserID = currentUser.id
        
        let ref = Database.database().reference()
        let groupRef = ref
            .child("Userdata").child(currentUserID)
            .child("Groups").child(group.id)
        
        groupRef.observeSingleEvent(of: .value) { snapshot in
            guard var groupDict = snapshot.value as? [String: Any] else { return }
            guard var members = groupDict["members"] as? [String] else { return }
            
            if !members.contains(user.id) {
                members.append(user.id)
                groupDict["members"] = members
                groupRef.setValue(groupDict)
                
                // 配信中の場合はメンバー数も更新
                if self.isBroadcasting {
                    ref.child("BroadcastingRooms").child(self.group.id)
                        .updateChildValues(["memberCount": members.count])
                }
            }
        }
        
        if !permittedUsers.contains(where: { $0.id == user.id }) {
            permittedUsers.append(user)
        }
    }
    
    // MARK: - オブザーバー解除
    private func removeAllObservers() {
        let ref = Database.database().reference()
        for (uid, handle) in userInfoHandles {
            ref.child("Username").child(uid).removeObserver(withHandle: handle)
        }
        for (uid, handle) in heartRateHandles {
            ref.child("Userdata").child(uid)
                .child("Heartbeat").child("Watch1").child("HeartRate")
                .removeObserver(withHandle: handle)
        }
        
        // 配信状態のオブザーバーを解除
        if let broadcastingHandle = broadcastingHandle {
            ref.child("Userdata").child(currentUser.id)
                .child("Groups").child(group.id).child("broadcasting")
                .removeObserver(withHandle: broadcastingHandle)
        }
        
        // 視聴者数のオブザーバーを解除
        if let viewerCountHandle = viewerCountHandle {
            ref.child("Userdata").child(currentUser.id)
                .child("Groups").child(group.id).child("viewers")
                .removeObserver(withHandle: viewerCountHandle)
            
            // 公開リストの視聴者数も確認
            if isBroadcasting {
                ref.child("BroadcastingRooms").child(group.id).child("viewerCount")
                    .removeObserver(withHandle: viewerCountHandle)
            }
        }
        
        userInfoHandles.removeAll()
        heartRateHandles.removeAll()
        broadcastingHandle = nil
        viewerCountHandle = nil
    }
}

// MARK: - ToastView
struct ToastView: View {
    let message: String
    let isSuccess: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "info.circle.fill")
                .foregroundColor(.white)
                .font(.system(size: 22, weight: .semibold))
            
            Text(message)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(
                    isSuccess ?
                        ColorManager.accent.opacity(0.95) :
                        Color(UIColor.systemGray).opacity(0.95)
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        .padding(.bottom, 30)
    }
}

// MARK: - AllUserView (ダークテーマ) - 修正版（共有を開始するルーム用）
struct AllUserView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // ログイン中ユーザー（ヘッダー表示用）
    @State private var currentUser: PermittedUser = PermittedUser(
        id: "currentUserID", name: "Loading...", imageURL: ""
    )
    
    // Firebaseから取得したグループデータ
    @State private var groups: [GroupData] = []
    
    // グループ作成シート表示
    @State private var showGroupCreationSheet = false
    
    // 選択されたグループ
    @State private var selectedGroup: GroupData? = nil
    
    // アクティブルームの監視
    @State private var groupsHandle: DatabaseHandle?
    @State private var activeBroadcastsHandle: DatabaseHandle?
    
    var body: some View {
        ZStack {
            // 背景
            ColorManager.background.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                
                // コンテンツ
                if groups.isEmpty {
                    NoGroupPageView()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // アクティブルームセクション（配信状態によって表示が異なる）
                            if let activeGroup = groups.first(where: { $0.isBroadcasting }) {
                                VStack(alignment: .leading) {
                                    Text("配信中")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(ColorManager.primaryText)
                                        .padding(.horizontal)
                                        .padding(.bottom, 4)
                                    
                                    Button(action: {
                                        selectedGroup = activeGroup
                                    }) {
                                        HStack {
                                            // アクティブ表示用のアイコン
                                            ZStack {
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [ColorManager.accent, ColorManager.accent.opacity(0.7)]),
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(width: 50, height: 50)
                                                
                                                Image(systemName: "antenna.radiowaves.left.and.right")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(ColorManager.primaryText)
                                            }
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [
                                                                ColorManager.accent.opacity(0.8),
                                                                ColorManager.accent.opacity(0.5)
                                                            ]),
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 2
                                                    )
                                            )
                                            .shadow(color: ColorManager.accent.opacity(0.5), radius: 5, x: 0, y: 0)
                                            .padding(.trailing, 4)
                                            
                                            // ルーム情報
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(activeGroup.groupName)
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(ColorManager.primaryText)
                                                
                                                HStack(spacing: 8) {
                                                    // ライブバッジ
                                                    Text("LIVE")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(
                                                            Capsule()
                                                                .fill(ColorManager.accent)
                                                        )
                                                    
                                                    // メンバー数
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "person.fill")
                                                            .font(.system(size: 12))
                                                            .foregroundColor(ColorManager.secondaryText)
                                                        
                                                        Text("\(activeGroup.memberIDs.count)人")
                                                            .font(.system(size: 14))
                                                            .foregroundColor(ColorManager.secondaryText)
                                                    }
                                                    
                                                    // 視聴者数
                                                    if activeGroup.viewerCount > 0 {
                                                        HStack(spacing: 4) {
                                                            Image(systemName: "eye.fill")
                                                                .font(.system(size: 12))
                                                                .foregroundColor(ColorManager.secondaryText)
                                                            
                                                            Text("\(activeGroup.viewerCount)人が視聴中")
                                                                .font(.system(size: 14))
                                                                .foregroundColor(ColorManager.secondaryText)
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            // 矢印アイコン
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(ColorManager.tertiaryText)
                                                .padding(.trailing, 4)
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(ColorManager.cardBackground)
                                                .shadow(color: ColorManager.accent.opacity(0.2), radius: 8, x: 0, y: 4)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            ColorManager.accent.opacity(0.5),
                                                            ColorManager.accent.opacity(0.2)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                        .padding(.horizontal)
                                    }
                                    
                                    Divider()
                                        .background(ColorManager.cardBorder)
                                        .padding(.vertical, 8)
                                }
                            }
                            
                            // その他のルームセクション
                            Text("すべてのルーム")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(ColorManager.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.bottom, 4)
                            
                            ForEach(groups) { group in
                                // 配信中のルームは既に上に表示されているので、それ以外を表示
                                if !group.isBroadcasting {
                                    Button(action: {
                                        selectedGroup = group
                                    }) {
                                        RoomListItemView(group: group, isHostRoom: true)
                                    }
                                }
                            }
                            
                            // 新規ルーム追加ボタン
                            Button(action: {
                                showGroupCreationSheet = true
                            }) {
                                HStack {
                                    Spacer()
                                    
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                    
                                    Text("新しいルームを作成")
                                        .font(.headline)
                                    
                                    Spacer()
                                }
                                .foregroundColor(ColorManager.primaryText)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [ColorManager.secondaryAccent, ColorManager.secondaryAccent.opacity(0.7)]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                            }
                            
                            Spacer()
                                .frame(height: 100)
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .onAppear {
            setupCurrentUserInfo()
            loadGroupsFromFirebase()
            observeActiveBroadcasts()
        }
        .onDisappear {
            removeAllObservers()
        }
        .sheet(isPresented: $showGroupCreationSheet) {
            GroupCreationView()
        }
        .navigationTitle("ホストの開始")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .preferredColorScheme(.dark)
        // 変更後:
        .navigationDestination(isPresented: Binding(
            get: { selectedGroup != nil },
            set: { if !$0 { selectedGroup = nil } }
        )) {
            if let selectedGroup = selectedGroup {
                OneGroupCircleView(group: selectedGroup, currentUser: currentUser)
            }
        }
    }
    
    // MARK: - アクティブな配信を監視
    private func observeActiveBroadcasts() {
        guard let user = authViewModel.currentUser else { return }
        let uid = user.uid
        
        let ref = Database.database().reference()
        
        // 1. 自分が作成したルームの中で、配信中のものを検索
        activeBroadcastsHandle = ref.child("BroadcastingRooms")
            .observe(.value) { snapshot in
                // 配信中のルームを検索し、自分が作成したルームのみ抽出
                for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                    let groupID = child.key
                    if let dict = child.value as? [String: Any],
                       let hostID = dict["hostID"] as? String,
                       hostID == uid,
                       let viewerCount = dict["viewerCount"] as? Int {
                        
                        // 既存のグループを更新
                        DispatchQueue.main.async {
                            if let index = self.groups.firstIndex(where: { $0.id == groupID }) {
                                self.groups[index].isBroadcasting = true
                                self.groups[index].viewerCount = viewerCount
                            }
                        }
                    }
                }
            }
    }
    
    // MARK: - ログイン中ユーザー情報を取得
    private func setupCurrentUserInfo() {
        guard let user = authViewModel.currentUser else { return }
        let uid = user.uid
        let ref = Database.database().reference()
        
        ref.child("Username").child(uid)
            .observeSingleEvent(of: .value) { snapshot in
                if let dict = snapshot.value as? [String: Any] {
                    DispatchQueue.main.async {
                        currentUser = PermittedUser(
                            id: uid,
                            name: dict["UName"] as? String ?? "不明なユーザー",
                            imageURL: dict["Uimage"] as? String ?? "",
                            heartRate: 0
                        )
                    }
                }
            }
    }
    
    // MARK: - グループ一覧を取得
    private func loadGroupsFromFirebase() {
        guard let user = authViewModel.currentUser else { return }
        let uid = user.uid
        
        let ref = Database.database().reference()
        groupsHandle = ref.child("Userdata").child(uid).child("Groups")
            .observe(.value) { snapshot in
                var loadedGroups: [GroupData] = []
                for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                    let groupID = child.key
                    if let dict = child.value as? [String: Any] {
                        let groupName = dict["groupName"] as? String ?? "No Name"
                        let memberIDs = dict["members"] as? [String] ?? []
                        let isBroadcasting = dict["broadcasting"] as? Bool ?? false
                        let isActive = dict["active"] as? Bool ?? false
                        
                        // 視聴者数を取得
                        var viewerCount = 0
                        if let viewers = dict["viewers"] as? [String: Bool] {
                            viewerCount = viewers.count
                        }
                        
                        let newGroup = GroupData(
                            id: groupID,
                            groupName: groupName,
                            memberIDs: memberIDs,
                            hostID: uid,
                            viewerCount: viewerCount,
                            isActive: isActive,
                            isBroadcasting: isBroadcasting
                        )
                        loadedGroups.append(newGroup)
                    }
                }
                DispatchQueue.main.async {
                    self.groups = loadedGroups
                }
            }
    }
    
    // MARK: - オブザーバー解除
    private func removeAllObservers() {
        guard let user = authViewModel.currentUser else { return }
        let uid = user.uid
        
        let ref = Database.database().reference()
        
        if let handle = groupsHandle {
            ref.child("Userdata").child(uid).child("Groups").removeObserver(withHandle: handle)
        }
        
        if let handle = activeBroadcastsHandle {
            ref.child("BroadcastingRooms").removeObserver(withHandle: handle)
        }
        
        groupsHandle = nil
        activeBroadcastsHandle = nil
    }
}

// MARK: - JoinableRoomsView（参加するルーム画面 - 修正版）
struct JoinableRoomsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // ログイン中ユーザー
    @State private var currentUser: PermittedUser = PermittedUser(
        id: "currentUserID", name: "Loading...", imageURL: ""
    )
    
    // 参加可能なルーム一覧
    @State private var joinableRooms: [GroupData] = []
    
    // 選択されたルーム
    @State private var selectedRoom: GroupData? = nil
    
    // フレンドユーザー情報
    @State private var friendUsers: [String: PermittedUser] = [:]
    
    // 配信ルーム監視
    @State private var broadcastingRoomsHandle: DatabaseHandle?
    
    var body: some View {
        ZStack {
            // 背景
            ColorManager.background.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                
                // コンテンツ
                if joinableRooms.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 60))
                            .foregroundColor(ColorManager.tertiaryText)
                        
                        Text("参加可能なルームがありません")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(ColorManager.primaryText)
                            .multilineTextAlignment(.center)
                        
                        Text("フレンドが作成したルームが\n表示されます")
                            .font(.system(size: 16))
                            .foregroundColor(ColorManager.secondaryText)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // 配信中ルームのセクション
                            let broadcastingRooms = joinableRooms.filter { $0.isBroadcasting }
                            if !broadcastingRooms.isEmpty {
                                VStack(alignment: .leading) {
                                    Text("配信中のルーム")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(ColorManager.primaryText)
                                        .padding(.horizontal)
                                        .padding(.bottom, 4)
                                    
                                    ForEach(broadcastingRooms) { room in
                                        Button(action: {
                                            selectedRoom = room
                                        }) {
                                            HStack {
                                                // 配信中アイコン
                                                ZStack {
                                                    Circle()
                                                        .fill(
                                                            LinearGradient(
                                                                gradient: Gradient(colors: [ColorManager.accent, ColorManager.accent.opacity(0.7)]),
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            )
                                                        )
                                                        .frame(width: 50, height: 50)
                                                    
                                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                                        .font(.system(size: 20))
                                                        .foregroundColor(ColorManager.primaryText)
                                                }
                                                .overlay(
                                                    Circle()
                                                        .stroke(
                                                            LinearGradient(
                                                                gradient: Gradient(colors: [
                                                                    ColorManager.accent.opacity(0.8),
                                                                    ColorManager.accent.opacity(0.5)
                                                                ]),
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            ),
                                                            lineWidth: 2
                                                        )
                                                )
                                                .shadow(color: ColorManager.accent.opacity(0.5), radius: 5, x: 0, y: 0)
                                                .padding(.trailing, 4)
                                                
                                                // ルーム情報
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(room.groupName)
                                                        .font(.system(size: 18, weight: .bold))
                                                        .foregroundColor(ColorManager.primaryText)
                                                    
                                                    HStack(spacing: 8) {
                                                        // ライブバッジ
                                                        Text("LIVE")
                                                            .font(.system(size: 10, weight: .bold))
                                                            .foregroundColor(.white)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(
                                                                Capsule()
                                                                    .fill(ColorManager.accent)
                                                            )
                                                        
                                                        // ホスト名
                                                        if let hostUser = getHostUser(for: room) {
                                                            HStack(spacing: 4) {
                                                                Image(systemName: "person.fill")
                                                                    .font(.system(size: 12))
                                                                    .foregroundColor(ColorManager.secondaryText)
                                                                
                                                                Text(hostUser.name)
                                                                    .font(.system(size: 14))
                                                                    .foregroundColor(ColorManager.secondaryText)
                                                            }
                                                        }
                                                        
                                                        // 視聴者数
                                                        if room.viewerCount > 0 {
                                                            HStack(spacing: 4) {
                                                                Image(systemName: "eye.fill")
                                                                    .font(.system(size: 12))
                                                                    .foregroundColor(ColorManager.secondaryText)
                                                                
                                                                Text("\(room.viewerCount)人が視聴中")
                                                                    .font(.system(size: 14))
                                                                    .foregroundColor(ColorManager.secondaryText)
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                // 矢印アイコン
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(ColorManager.tertiaryText)
                                                    .padding(.trailing, 4)
                                            }
                                            .padding()
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(ColorManager.cardBackground)
                                                    .shadow(color: ColorManager.accent.opacity(0.2), radius: 8, x: 0, y: 4)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [
                                                                ColorManager.accent.opacity(0.5),
                                                                ColorManager.accent.opacity(0.2)
                                                            ]),
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1
                                                    )
                                            )
                                            .padding(.horizontal)
                                        }
                                    }
                                    
                                    Divider()
                                        .background(ColorManager.cardBorder)
                                        .padding(.vertical, 8)
                                }
                            }
                            
                            // 配信していないルームのセクション
                            let nonBroadcastingRooms = joinableRooms.filter { !$0.isBroadcasting }
                            if !nonBroadcastingRooms.isEmpty {
                                Text("すべてのルーム")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(ColorManager.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.bottom, 4)
                                
                                ForEach(nonBroadcastingRooms) { room in
                                    Button(action: {
                                        selectedRoom = room
                                    }) {
                                        RoomListItemView(group: room, isHostRoom: false)
                                    }
                                }
                            }
                            
                            Spacer()
                                .frame(height: 100)
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .onAppear {
            setupCurrentUserInfo()
            loadJoinableRooms()
            observeBroadcastingRooms()
        }
        .onDisappear {
            removeAllObservers()
        }
        .navigationTitle("参加するルーム")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .preferredColorScheme(.dark)
        .navigationDestination(isPresented: Binding(
            get: { selectedRoom != nil },
            set: { if !$0 { selectedRoom = nil } }
        )) {
            if let selectedRoom = selectedRoom, let hostUser = getHostUser(for: selectedRoom) {
                JoinedGroupCircleView(group: selectedRoom, currentUser: currentUser, hostUser: hostUser)
            }
        }
    }
    
    // MARK: - 配信中のルームを監視
    private func observeBroadcastingRooms() {
        let ref = Database.database().reference()
        
        broadcastingRoomsHandle = ref.child("BroadcastingRooms").observe(.value) { snapshot in
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                let groupID = child.key
                
                if let dict = child.value as? [String: Any],
                   let hostID = dict["hostID"] as? String,
                   let _ = dict["hostName"] as? String,
                   let groupName = dict["groupName"] as? String,
                   let viewerCount = dict["viewerCount"] as? Int {
                    
                    // 自分が参加できるルームかチェック
                    self.checkIfUserCanJoin(hostID: hostID, groupID: groupID) { canJoin, memberIDs in
                        if canJoin {
                            DispatchQueue.main.async {
                                // ホストユーザー情報を取得
                                self.loadHostUserInfo(hostID: hostID)
                                
                                // ルームの情報を更新
                                if let index = self.joinableRooms.firstIndex(where: { $0.id == groupID }) {
                                    self.joinableRooms[index].isBroadcasting = true
                                    self.joinableRooms[index].viewerCount = viewerCount
                                } else {
                                    // 新しいルームとして追加
                                    let newRoom = GroupData(
                                        id: groupID,
                                        groupName: groupName,
                                        memberIDs: memberIDs,
                                        hostID: hostID,
                                        viewerCount: viewerCount,
                                        isActive: true,
                                        isBroadcasting: true
                                    )
                                    self.joinableRooms.append(newRoom)
                                }
                            }
                        }
                    }
                }
            }
            
            // 配信されなくなったルームの配信フラグをオフにする
            let activeGroupIDs = Set((snapshot.children.allObjects as? [DataSnapshot] ?? []).map { $0.key })
            
            DispatchQueue.main.async {
                for index in 0..<self.joinableRooms.count {
                    if !activeGroupIDs.contains(self.joinableRooms[index].id) {
                        self.joinableRooms[index].isBroadcasting = false
                    }
                }
            }
        }
    }
    
    // ホストユーザー情報を取得
    private func getHostUser(for room: GroupData) -> PermittedUser? {
        if let hostID = room.hostID {
            return friendUsers[hostID]
        }
        return nil
    }
    
    // ホストユーザー情報をロード
    private func loadHostUserInfo(hostID: String) {
        // すでに取得済みならスキップ
        if friendUsers[hostID] != nil {
            return
        }
        
        let ref = Database.database().reference()
        
        ref.child("Username").child(hostID)
            .observeSingleEvent(of: .value) { snapshot in
                if let dict = snapshot.value as? [String: Any] {
                    let name = dict["UName"] as? String ?? "不明なユーザー"
                    let imageURL = dict["Uimage"] as? String ?? ""
                    
                    let hostUser = PermittedUser(
                        id: hostID,
                        name: name,
                        imageURL: imageURL,
                        heartRate: 0
                    )
                    
                    DispatchQueue.main.async {
                        self.friendUsers[hostID] = hostUser
                    }
                }
            }
    }
    
    // MARK: - ログイン中ユーザー情報を取得
    private func setupCurrentUserInfo() {
        guard let user = authViewModel.currentUser else { return }
        let uid = user.uid
        let ref = Database.database().reference()
        
        ref.child("Username").child(uid)
            .observeSingleEvent(of: .value) { snapshot in
                if let dict = snapshot.value as? [String: Any] {
                    DispatchQueue.main.async {
                        currentUser = PermittedUser(
                            id: uid,
                            name: dict["UName"] as? String ?? "不明なユーザー",
                            imageURL: dict["Uimage"] as? String ?? "",
                            heartRate: 0
                        )
                    }
                }
            }
    }
    
    // MARK: - 参加可能なルーム一覧を取得
    private func loadJoinableRooms() {
        guard let user = authViewModel.currentUser else { return }
        _ = user.uid
        let ref = Database.database().reference()
        
        // 1. BroadcastingRoomsから公開配信中のルームを取得
        ref.child("BroadcastingRooms").observeSingleEvent(of: .value) { snapshot in
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                let groupID = child.key
                
                if let roomDict = child.value as? [String: Any],
                   let hostID = roomDict["hostID"] as? String,
                   let groupName = roomDict["groupName"] as? String,
                   let viewerCount = roomDict["viewerCount"] as? Int {
                    
                    // 自分が参加可能かをチェック（フレンド関係など）
                    self.checkIfUserCanJoin(hostID: hostID, groupID: groupID) { canJoin, memberIDs in
                        if canJoin {
                            // ホストユーザー情報を取得
                            self.loadHostUserInfo(hostID: hostID)
                            
                            let room = GroupData(
                                id: groupID,
                                groupName: groupName,
                                memberIDs: memberIDs,
                                hostID: hostID,
                                viewerCount: viewerCount,
                                isActive: true,
                                isBroadcasting: true
                            )
                            
                            DispatchQueue.main.async {
                                if !self.joinableRooms.contains(where: { $0.id == groupID }) {
                                    self.joinableRooms.append(room)
                                }
                            }
                        }
                    }
                }
            }
            
            // 2. 非配信中のルームも取得（フレンドのユーザーデータから）
            self.loadFriendUsers()
        }
    }
    
    // フレンドユーザー情報と彼らのルームを取得
    private func loadFriendUsers() {
        guard let user = authViewModel.currentUser else { return }
        let uid = user.uid
        let ref = Database.database().reference()
        
        // フレンド一覧を取得
        ref.child("AcceptUser").child(uid).child("permittedUser")
            .observeSingleEvent(of: .value) { snapshot in
                for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                    let friendUID = child.key
                    
                    if let allowed = child.value as? Bool, allowed {
                        // フレンドユーザーの情報を取得
                        ref.child("Username").child(friendUID)
                            .observeSingleEvent(of: .value) { userSnapshot in
                                if let dict = userSnapshot.value as? [String: Any] {
                                    let name = dict["UName"] as? String ?? "不明なユーザー"
                                    let imageURL = dict["Uimage"] as? String ?? ""
                                    
                                    let friendUser = PermittedUser(
                                        id: friendUID,
                                        name: name,
                                        imageURL: imageURL,
                                        heartRate: 0
                                    )
                                    
                                    DispatchQueue.main.async {
                                        self.friendUsers[friendUID] = friendUser
                                    }
                                    
                                    // フレンドのグループを取得
                                    ref.child("Userdata").child(friendUID).child("Groups")
                                        .observeSingleEvent(of: .value) { groupsSnapshot in
                                            for groupChild in groupsSnapshot.children.allObjects as? [DataSnapshot] ?? [] {
                                                let groupID = groupChild.key
                                                
                                                if let groupDict = groupChild.value as? [String: Any],
                                                   let groupName = groupDict["groupName"] as? String,
                                                   let memberIDs = groupDict["members"] as? [String],
                                                   memberIDs.contains(uid) {
                                                    
                                                    // 配信状態を確認
                                                    let isBroadcasting = groupDict["broadcasting"] as? Bool ?? false
                                                    
                                                    // 視聴者数を取得
                                                    var viewerCount = 0
                                                    if let viewers = groupDict["viewers"] as? [String: Bool] {
                                                        viewerCount = viewers.count
                                                    }
                                                    
                                                    // 既に配信中リストに含まれていれば追加しない
                                                    if !isBroadcasting || !self.joinableRooms.contains(where: { $0.id == groupID }) {
                                                        let room = GroupData(
                                                            id: groupID,
                                                            groupName: groupName,
                                                            memberIDs: memberIDs,
                                                            hostID: friendUID,
                                                            viewerCount: viewerCount,
                                                            isActive: false,
                                                            isBroadcasting: isBroadcasting
                                                        )
                                                        
                                                        DispatchQueue.main.async {
                                                            if !self.joinableRooms.contains(where: { $0.id == groupID }) {
                                                                self.joinableRooms.append(room)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                }
                            }
                    }
                }
            }
    }
    
    // 参加可能かどうかを確認するヘルパーメソッド
    private func checkIfUserCanJoin(hostID: String, groupID: String, completion: @escaping (Bool, [String]) -> Void) {
        guard let user = authViewModel.currentUser else {
            completion(false, [])
            return
        }
        let uid = user.uid
        let ref = Database.database().reference()
        
        // 1. フレンド関係をチェック
        ref.child("AcceptUser").child(uid).child("permittedUser").child(hostID)
            .observeSingleEvent(of: .value) { snapshot in
                guard let isPermitted = snapshot.value as? Bool, isPermitted else {
                    completion(false, [])
                    return
                }
                
                // 2. そのルームのメンバーリストを取得
                ref.child("Userdata").child(hostID).child("Groups").child(groupID).child("members")
                    .observeSingleEvent(of: .value) { membersSnapshot in
                        let memberIDs = (membersSnapshot.value as? [String]) ?? []
                        
                        // 3. 自分がメンバーに含まれているかチェック
                        let canJoin = memberIDs.contains(uid)
                        completion(canJoin, memberIDs)
                    }
            }
    }
    
    // MARK: - オブザーバー解除
    private func removeAllObservers() {
        let ref = Database.database().reference()
        
        if let handle = broadcastingRoomsHandle {
            ref.child("BroadcastingRooms").removeObserver(withHandle: handle)
        }
        
        broadcastingRoomsHandle = nil
    }
}

                                                   // MARK: - JoinedGroupCircleView (参加者用ルーム詳細ビュー) - 視聴者機能追加
struct JoinedGroupCircleView: View {
    let group: GroupData
    let currentUser: PermittedUser
    let hostUser: PermittedUser
    
    // Firebase関連など
    @State private var userInfoHandles: [String: DatabaseHandle] = [:]
    @State private var heartRateHandles: [String: DatabaseHandle] = [:]
    
    // メンバー情報
    @State private var permittedUsers: [PermittedUser] = []
    
    // アニメーション用
    @State private var appearPhase: CGFloat = 0.0
    @State private var centerScale: CGFloat = 0.5
    @State private var rotationAngle: Double = 0
    @State private var pulseEffect: CGFloat = 1.0
    
    // ホストの配信状態を管理する変数
    @State private var isHostBroadcasting: Bool = false
    @State private var broadcastingHandle: DatabaseHandle?
    
    // ホストの心拍数アニメーション
    @State private var hostHeartRate: Int = 0
    @State private var isAnimating: Bool = false
    @State private var lastBeatTime: Date = Date()
    @State private var heartbeatTimer: Timer? = nil
    
    // ハートビートアニメーション用
    @State private var heartScale: CGFloat = 1.0
    @State private var rippleScale: CGFloat = 0.5
    @State private var heartOpacity: Double = 1.0
    @State private var rippleOpacity: Double = 0.0
    
    // 視聴者状態管理
    @State private var isRegisteredAsViewer: Bool = false
    
    // バイブレーション管理
    private let hapticManager = HapticManager()
    @AppStorage("iphoneVibrationEnabled") private var hapticFeedbackEnabled: Bool = false
    
    /// 心拍数に応じた1拍あたりの間隔（秒）
    var beatInterval: Double {
        60.0 / Double(max(hostHeartRate, 1))
    }
    
    var body: some View {
        ZStack {
            // 背景色を他のビューと統一
            ColorManager.background.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 16) {
                    // ヘッダー部分
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("心拍共有")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(ColorManager.secondaryText)
                                
                                Text(group.groupName)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(ColorManager.primaryText)
                            }
                            
                            Spacer()
                            
                            // 心拍アイコン
                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(ColorManager.accent)
                                .shadow(color: ColorManager.accent.opacity(0.3), radius: 8, x: 0, y: 0)
                        }
                        .padding(.horizontal, 25)
                    }
                    .padding(.top, 0)
                    
                    // ホスト情報カード
                    VStack {
                        HStack(spacing: 15) {
                            // ホストのアイコン
                            UserIconView(
                                name: hostUser.name,
                                imageURL: hostUser.imageURL,
                                imageSize: 50,
                                isSelected: false
                            )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ルームホスト")
                                    .font(.system(size: 14))
                                    .foregroundColor(ColorManager.secondaryText)
                                
                                Text(hostUser.name)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(ColorManager.primaryText)
                            }
                            
                            Spacer()
                            
                            // ホスト表示バッジ
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(ColorManager.secondaryAccent)
                                    .font(.system(size: 14))
                                
                                Text("ホスト")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(ColorManager.secondaryAccent)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(ColorManager.secondaryAccent.opacity(0.2))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(ColorManager.secondaryAccent.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ColorManager.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        ColorManager.cardBorder.opacity(0.5),
                                        ColorManager.cardBorder.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    // 統合された心拍表示カード
                    VStack {
                        GeometryReader { geometry in
                            VStack(spacing: 0) {
                                // カードタイトル
                                Text("ホストの心拍")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(ColorManager.secondaryText)
                                
                                // 心拍アニメーションとBPM表示を横に並べる
                                VStack(alignment: .center, spacing: 20) {
                                    // 左側：心拍アニメーション
                                    ZStack {
                                        if isHostBroadcasting && hostHeartRate > 0 {
                                            // リップルエフェクト
                                            RippleView(scale: $rippleScale, opacity: $rippleOpacity)
                                            
                                            // 心拍アイコン
                                            HeartView(
                                                scale: heartScale,
                                                opacity: heartOpacity,
                                                color: ColorManager.primaryColor
                                            )
                                        } else if isHostBroadcasting {
                                            // 配信中だが心拍データがない場合
                                            ZStack {
                                                MultiCenterFadeCircleView()
                                                
                                                HeartView(
                                                    scale: 1.0,
                                                    opacity: 0.8,
                                                    color: ColorManager.secondaryColor
                                                )
                                            }
                                        } else {
                                            // 配信がオフラインの場合
                                            ZStack {
                                                MultiCenterFadeCircleView()
                                                
                                                HeartView(
                                                    scale: 1.0,
                                                    opacity: 0.5,
                                                    color: ColorManager.inactiveColor
                                                )
                                            }
                                        }
                                    }
                                    .frame(width: 200, height: 200)
                                    
                                    // 右側：BPM表示
                                    VStack(alignment: .center, spacing: 8) {
                                        // 心拍数値
                                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                                            if isHostBroadcasting && hostHeartRate > 0 {
                                                Text("\(hostHeartRate)")
                                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                                    .foregroundColor(isHostBroadcasting ? ColorManager.primaryColor : ColorManager.subtleTextColor)
                                            }else{
                                                Text("---")
                                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                                    .foregroundColor(isHostBroadcasting ? ColorManager.primaryColor : ColorManager.subtleTextColor)
                                            }
                                            
                                            Text("BPM")
                                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                                .foregroundColor(isHostBroadcasting ? ColorManager.secondaryColor : ColorManager.subtleTextColor)
                                                .padding(.leading, 4)
                                        }
                                    }
                                }
                            }
                            .frame(width: geometry.size.width * 0.92)
                            .frame(height: 300)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        }
                        .frame(height: 400) // 適切な高さに設定
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ColorManager.cardBackground)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    
                    // -- 中央カード：周囲に集まるユーザーアイコン --
                    VStack {
                        GeometryReader { geo in
                            ZStack {
                                // 背景の円とエフェクト
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                ColorManager.secondaryBackground,
                                                ColorManager.background
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: min(geo.size.width, geo.size.height) * 0.85)
                                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                                
                                // 外側リング
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                ColorManager.gradientStart.opacity(0.4),
                                                ColorManager.gradientEnd.opacity(0.4)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                                    .frame(width: min(geo.size.width, geo.size.height) * 0.8)
                                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                                    .rotationEffect(.degrees(rotationAngle))
                                
                                // 中央アイコン (メインユーザー)
                                ZStack {
                                    // 脈拍を示す波紋アニメーション
                                    ForEach(0..<3) { i in
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        ColorManager.gradientStart.opacity(0.5 - Double(i) * 0.15),
                                                        ColorManager.gradientEnd.opacity(0.5 - Double(i) * 0.15)
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2
                                            )
                                            .frame(width: 80 + CGFloat(i * 20))
                                            .scaleEffect(centerScale * pulseEffect)
                                            .opacity(Double(1 - (i * 20) % 100) / 100.0)
                                    }
                                    
                                    UserIconView(
                                        name: currentUser.name,
                                        imageURL: currentUser.imageURL,
                                        imageSize: 80,
                                        isSelected: true
                                    )
                                    .scaleEffect(centerScale)
                                }
                                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                                
                                // 視聴者バッジの表示
                                if isRegisteredAsViewer && isHostBroadcasting {
                                    Text("視聴中")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(ColorManager.secondaryAccent)
                                                .shadow(color: ColorManager.secondaryAccent.opacity(0.5), radius: 5, x: 0, y: 0)
                                        )
                                        .position(x: geo.size.width / 2, y: geo.size.height / 2 + 60)
                                }
                                
                                let centerPt = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                                let radius = min(geo.size.width, geo.size.height) * 0.37 // 縁との間隔を確保
                                
                                let circleMembers = permittedUsers.filter { $0.id != currentUser.id }
                                
                                ForEach(Array(circleMembers.enumerated()), id: \.element.id) { (idx, user) in
                                    let angle = Angle(degrees: Double(idx) / Double(circleMembers.count) * 360)
                                    let startFactor: CGFloat = 1.8
                                    let currentRadius = radius + (radius * (startFactor - 1)) * (1 - appearPhase)
                                    let currentX = centerPt.x + currentRadius * CGFloat(cos(angle.radians))
                                    let currentY = centerPt.y + currentRadius * CGFloat(sin(angle.radians))
                                    
                                    let scale = 0.5 + 0.5 * appearPhase
                                    let opacity = Double(appearPhase)
                                    
                                    ZStack {
                                        // 心拍数がある場合は表示
                                        if user.heartRate > 0 {
                                            VStack(spacing: 2) {
                                                UserIconView(
                                                    name: user.name,
                                                    imageURL: user.imageURL,
                                                    imageSize: 60,
                                                    isSelected: false
                                                )
                                                
                                                HStack(spacing: 2) {
                                                    Image(systemName: "heart.fill")
                                                        .foregroundColor(ColorManager.accent)
                                                        .font(.system(size: 10))
                                                    
                                                    Text("\(user.heartRate)")
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(ColorManager.accent)
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(
                                                    Capsule()
                                                        .fill(ColorManager.cardBackground.opacity(0.9))
                                                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                                                )
                                            }
                                        } else {
                                            UserIconView(
                                                name: user.name,
                                                imageURL: user.imageURL,
                                                imageSize: 60,
                                                isSelected: false
                                            )
                                        }
                                    }
                                    .scaleEffect(scale)
                                    .opacity(opacity)
                                    .position(x: currentX, y: currentY)
                                }
                                
                                // グループの人数の表示
                                Text("\(permittedUsers.count)人のメンバー")
                                    .font(.caption)
                                    .foregroundColor(ColorManager.secondaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(ColorManager.cardBackground.opacity(0.9))
                                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(ColorManager.cardBorder, lineWidth: 1)
                                    )
                                    .position(x: geo.size.width / 2, y: geo.size.height - 30)
                                
                                // メンバーが多い場合のページインジケーター
                                if permittedUsers.count > 7 {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(ColorManager.accent)
                                            .frame(width: 8, height: 8)
                                        
                                        Circle()
                                            .fill(ColorManager.tertiaryText)
                                            .frame(width: 8, height: 8)
                                    }
                                    .position(x: geo.size.width / 2, y: geo.size.height - 60)
                                }
                            }
                        }
                        .frame(height: 420) // 縦方向のスペースを拡大
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ColorManager.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        ColorManager.cardBorder.opacity(0.5),
                                        ColorManager.cardBorder.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    // 参加者向けの下部カード（例：ルームを退出するボタン）
                    VStack {
                        Toggle(isOn: $hapticFeedbackEnabled) {
                            HStack {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                    .foregroundColor(ColorManager.primaryText)
                                
                                Text("バイブレーションで心拍を体感")
                                    .foregroundColor(ColorManager.primaryText)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: ColorManager.accent))
                        .padding(.vertical, 8)
                        
                        Button(action: {
                            leaveRoom()
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16))
                                    .foregroundColor(ColorManager.primaryText)
                                
                                Text("このルームを退出")
                                    .foregroundColor(ColorManager.primaryText)
                                    .font(.headline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        ColorManager.secondaryAccent,
                                        ColorManager.secondaryAccent.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: ColorManager.secondaryAccent.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ColorManager.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        ColorManager.cardBorder.opacity(0.5),
                                        ColorManager.cardBorder.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            
            // 配信オフライン時のオーバーレイ
            if !isHostBroadcasting {
                ZStack {
                    // グレースケールオーバーレイ
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 16) {
                        Image(systemName: "tv.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        
                        Text("配信はオフラインです")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("ホストが配信を開始するのをお待ちください")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.7))
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: isHostBroadcasting)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // ユーザー情報ロード
            loadGroupMembers()
            
            // ホストの配信状態を監視
            observeBroadcastStatus()
            
            // ホストの心拍数を監視
            observeHostHeartRate()
            
            // 視聴者として登録
            registerAsViewer(true)
            
            // アニメーションを開始
            withAnimation(.easeInOut(duration: 1.0)) {
                centerScale = 1.0
            }
            
            // 0.5秒後に周囲のアイコンをフェードイン
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 1.5)) {
                    appearPhase = 1.0
                }
            }
            
            // 回転アニメーション
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            
            // 脈動アニメーション
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseEffect = 1.1
            }
            
            // 心拍アニメーションのタイマーを開始
            startHeartbeatTimer()
        }
        .onDisappear {
            // 視聴者登録を解除
            registerAsViewer(false)
            
            removeAllObservers()
            
            // タイマーを停止
            heartbeatTimer?.invalidate()
            heartbeatTimer = nil
        }
    }
    
    // 心拍数に応じたテキストを取得
    private func getHeartRateRangeText(_ rate: Int) -> String {
        switch rate {
        case 0:
            return "データなし"
        case 1...60:
            return "安静時の心拍数"
        case 61...100:
            return "通常の心拍数"
        case 101...140:
            return "運動時の心拍数"
        default:
            return "高い心拍数"
        }
    }
    
    // JoinedGroupCircleView内のregisterAsViewerメソッドを修正
    private func registerAsViewer(_ isViewing: Bool) {
        guard let hostID = group.hostID, !hostID.isEmpty else { return }
        
        let ref = Database.database().reference()
        
        // 1. ホスト側のグループにviewerとして登録（既存のコード）
        let viewerRef = ref.child("Userdata").child(hostID)
            .child("Groups").child(group.id)
            .child("viewers").child(currentUser.id)
        
        if isViewing {
            viewerRef.setValue(true)
            isRegisteredAsViewer = true
        } else {
            viewerRef.removeValue()
            isRegisteredAsViewer = false
        }
        
        // 2. BroadcastingRoomsの視聴者カウント更新（既存のコード）
        let publicViewerRef = ref.child("BroadcastingRooms").child(group.id)
        
        if isViewing {
            // 視聴開始：カウンターをインクリメント
            publicViewerRef.child("viewerCount").runTransactionBlock { (currentData) -> TransactionResult in
                var count = 0
                if let value = currentData.value as? Int {
                    count = value
                }
                currentData.value = count + 1
                return TransactionResult.success(withValue: currentData)
            }
        } else {
            // 視聴終了：カウンターをデクリメント（最低0）
            publicViewerRef.child("viewerCount").runTransactionBlock { (currentData) -> TransactionResult in
                var count = 0
                if let value = currentData.value as? Int {
                    count = value
                }
                currentData.value = max(0, count - 1) // 0以下にはならないよう保証
                return TransactionResult.success(withValue: currentData)
            }
        }
        
        // 3. 【新規追加】視聴者自身のAppStateに現在の視聴状態を保存
        let userAppStateRef = ref.child("Userdata").child(currentUser.id).child("AppState")
        
        if isViewing {
            // 視聴開始：現在視聴中のルーム情報を保存
            let viewingData: [String: Any] = [
                "currentlyViewing": true,
                "roomID": group.id,
                "hostID": hostID,
                "roomName": group.groupName,
                "startedViewingAt": ServerValue.timestamp()
            ]
            userAppStateRef.updateChildValues(viewingData)
        } else {
            // 視聴終了：視聴状態をクリア
            userAppStateRef.updateChildValues([
                "currentlyViewing": false,
                "roomID": "None",
                "hostID": "None",
                "roomName": "None",
                "startedViewingAt": "None"
            ])
        }
    }
    
    // MARK: - 心拍アニメーション関連
    
    // タイマーを開始するメソッド
    private func startHeartbeatTimer() {
        // 既存のタイマーがあれば無効化
        heartbeatTimer?.invalidate()
        
        // 新しいタイマーを作成（0.1秒間隔でチェック）
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // 配信中かつ心拍数が有効な場合のみ処理
            if self.isHostBroadcasting && self.hostHeartRate > 0 && !self.isAnimating {
                let now = Date()
                let currentBeatInterval = self.beatInterval
                let timeSinceLastBeat = now.timeIntervalSince(self.lastBeatTime)
                
                // 前回の鼓動から適切な時間が経過しているか確認
                if timeSinceLastBeat >= currentBeatInterval {
                    // 次の鼓動の基準時間を設定
                    self.lastBeatTime = self.lastBeatTime.addingTimeInterval(currentBeatInterval)
                    // 時間のずれが大きすぎる場合は現在時刻にリセット
                    if abs(self.lastBeatTime.timeIntervalSince(now)) > currentBeatInterval {
                        self.lastBeatTime = now
                    }
                    
                    // 心拍数に基づいたアニメーションを実行
                    self.animateHeartbeat(interval: currentBeatInterval)
                }
            }
        }
    }
    
    // 心拍アニメーションを実行するメソッド
    private func animateHeartbeat(interval: Double) {
        // アニメーション中なら処理しない
        guard !isAnimating else { return }
        
        // アニメーション中フラグをセット
        isAnimating = true
        
        // バイブレーション機能が有効で、配信中かつ心拍数が有効な場合のみ実行
        if hapticFeedbackEnabled && isHostBroadcasting && hostHeartRate > 0 {
            // 心拍数に応じたバイブレーションを再生
            hapticManager.playHeartbeatHapticWithSettings(interval: interval)
            
            // 補助的な軽いバイブレーションを提供
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred(intensity: 0.4)
        }
        
        // 心拍数に基づくアニメーション時間を計算
        let animationDuration = interval * 0.8
        
        // 初期アニメーション状態をセット
        rippleScale = 0.9
        rippleOpacity = 0.7
        
        // ステップ1: ハートを膨らませる
        withAnimation(.easeInOut(duration: animationDuration * 0.3)) {
            heartScale = 1.25
            rippleScale = 1.2
        }
        
        // ステップ2: リップルを広げる
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.2) {
            withAnimation(.easeOut(duration: animationDuration * 0.5)) {
                self.rippleScale = 1.7
                self.rippleOpacity = 0.0
            }
        }
        
        // ステップ3: ハートを元のサイズに戻す
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.3) {
            withAnimation(.easeOut(duration: animationDuration * 0.4)) {
                self.heartScale = 1.0
            }
        }
        
        // アニメーション完了のスケジュール
        DispatchQueue.main.asyncAfter(deadline: .now() + (animationDuration * 0.95)) {
            self.isAnimating = false
        }
    }
    
    // MARK: - ホストの心拍数を監視
    private func observeHostHeartRate() {
        guard let hostID = group.hostID, !hostID.isEmpty else { return }
        
        let ref = Database.database().reference()
        let heartRateRef = ref
            .child("Userdata").child(hostID)
            .child("Heartbeat").child("Watch1").child("HeartRate")
        
        let hrHandle = heartRateRef.observe(.value) { snapshot in
            var rate: Int = 0
            if let intRate = snapshot.value as? Int {
                rate = intRate
            } else if let strRate = snapshot.value as? String,
                      let intVal = Int(strRate) {
                rate = intVal
            }
            
            DispatchQueue.main.async {
                self.hostHeartRate = rate
                
                // 心拍数に変化があり配信中の場合、次のアニメーションをすぐに表示できるように時間をリセット
                if rate > 0 && self.isHostBroadcasting {
                    self.lastBeatTime = Date().addingTimeInterval(-self.beatInterval)
                }
            }
        }
        
        heartRateHandles["host_heartrate"] = hrHandle
    }
    
    // MARK: - ルーム退出処理
    private func leaveRoom() {
        // 現在のユーザーをグループから削除する処理
        guard let hostID = group.hostID, !hostID.isEmpty else { return }
        
        let ref = Database.database().reference()
        let groupRef = ref
            .child("Userdata").child(hostID)
            .child("Groups").child(group.id)
        
        groupRef.observeSingleEvent(of: .value) { snapshot in
            guard var groupDict = snapshot.value as? [String: Any] else { return }
            guard var members = groupDict["members"] as? [String] else { return }
            
            // メンバーリストから自分を削除
            members.removeAll { $0 == currentUser.id }
            groupDict["members"] = members
            
            // 更新をFirebaseに送信
            groupRef.updateChildValues(["members": members]) { error, _ in
                if let error = error {
                    print("ルーム退出エラー: \(error.localizedDescription)")
                } else {
                    print("ルームを退出しました")
                    // ナビゲーションで前の画面に戻る処理を追加
                }
            }
        }
    }
    
    // MARK: - ホストの配信状態を確認するメソッド
    private func observeBroadcastStatus() {
        guard let hostID = group.hostID, !hostID.isEmpty else { return }
        
        let ref = Database.database().reference()
        
        // まず公開リストをチェック（より高速で信頼性が高い）
        let publicBroadcastRef = ref.child("BroadcastingRooms").child(group.id)
        
        publicBroadcastRef.observe(.value) { snapshot in
            let isActive = snapshot.exists()
            DispatchQueue.main.async {
                withAnimation {
                    self.isHostBroadcasting = isActive
                    
                    // 配信開始時は心拍アニメーションを準備
                    if isActive {
                        self.lastBeatTime = Date()
                        self.startHeartbeatTimer()
                    }
                }
            }
        }
        
        // バックアップとしてユーザーデータも監視
        let broadcastRef = ref
            .child("Userdata").child(hostID)
            .child("Groups").child(group.id).child("broadcasting")
        
        broadcastingHandle = broadcastRef.observe(.value) { snapshot in
            if let value = snapshot.value as? Bool {
                DispatchQueue.main.async {
                    withAnimation {
                        // 公開リストと矛盾がある場合のみ更新
                        if self.isHostBroadcasting != value {
                            self.isHostBroadcasting = value
                            
                            // 配信開始時は心拍アニメーションを準備
                            if value {
                                self.lastBeatTime = Date()
                                self.startHeartbeatTimer()
                            }
                        }
                    }
                }
            } else {
                // 配信状態が設定されていない場合はデフォルトでfalse
                DispatchQueue.main.async {
                    withAnimation {
                        self.isHostBroadcasting = false
                    }
                }
            }
        }
    }
    
    // MARK: - グループメンバー情報取得
    private func loadGroupMembers() {
        let ref = Database.database().reference()
        permittedUsers.removeAll()
        
        // グループに含まれるmemberIDsを順に取得
        for uid in group.memberIDs {
            let infoHandle = ref.child("Username").child(uid)
                .observe(.value) { snapshot in
                    if let dict = snapshot.value as? [String: Any] {
                        DispatchQueue.main.async {
                            if let idx = permittedUsers.firstIndex(where: { $0.id == uid }) {
                                // すでに存在する場合→更新
                                permittedUsers[idx].name = dict["UName"] as? String ?? "不明なユーザー"
                                permittedUsers[idx].imageURL = dict["Uimage"] as? String ?? ""
                            } else {
                                // 新規追加
                                let newUser = PermittedUser(
                                    id: uid,
                                    name: dict["UName"] as? String ?? "不明なユーザー",
                                    imageURL: dict["Uimage"] as? String ?? "",
                                    heartRate: 0
                                )
                                permittedUsers.append(newUser)
                            }
                        }
                    }
                }
            userInfoHandles[uid] = infoHandle
            
            // 心拍数の監視
            let hrHandle = ref.child("Userdata").child(uid)
                .child("Heartbeat").child("Watch1").child("HeartRate")
                .observe(.value) { snapshot in
                    var rate: Int = 0
                    if let intRate = snapshot.value as? Int {
                        rate = intRate
                    } else if let strRate = snapshot.value as? String,
                              let intVal = Int(strRate) {
                        rate = intVal
                    }
                    DispatchQueue.main.async {
                        if let idx = permittedUsers.firstIndex(where: { $0.id == uid }) {
                            permittedUsers[idx].heartRate = rate
                        }
                    }
                }
            heartRateHandles[uid] = hrHandle
        }
        
        // 中央ユーザーもリストに含める
        if !permittedUsers.contains(where: { $0.id == currentUser.id }) {
            permittedUsers.append(currentUser)
        }
    }
    
    // MARK: - オブザーバー解除
    private func removeAllObservers() {
        let ref = Database.database().reference()
        for (uid, handle) in userInfoHandles {
            ref.child("Username").child(uid).removeObserver(withHandle: handle)
        }
        for (uid, handle) in heartRateHandles {
            if uid == "host_heartrate" {
                if let hostID = group.hostID {
                    ref.child("Userdata").child(hostID)
                        .child("Heartbeat").child("Watch1").child("HeartRate")
                        .removeObserver(withHandle: handle)
                }
            } else {
                ref.child("Userdata").child(uid)
                    .child("Heartbeat").child("Watch1").child("HeartRate")
                    .removeObserver(withHandle: handle)
            }
        }
        
        // 配信状態のオブザーバーを解除
        if let handle = broadcastingHandle, let hostID = group.hostID {
            ref.child("Userdata").child(hostID)
                .child("Groups").child(group.id).child("broadcasting")
                .removeObserver(withHandle: handle)
        }
        
        userInfoHandles.removeAll()
        heartRateHandles.removeAll()
        broadcastingHandle = nil
    }
}

                                                   // MARK: - RoomListItemView (ルームアイテム表示用コンポーネント)
struct RoomListItemView: View {
    let group: GroupData
    var isHostRoom: Bool = true
    
    var body: some View {
        HStack {
            // ルームアイコン
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                isHostRoom ? ColorManager.secondaryAccent : ColorManager.accent,
                                isHostRoom ? ColorManager.secondaryAccent.opacity(0.7) : ColorManager.accent.opacity(0.7)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: isHostRoom ? "play.circle.fill" : "person.2.fill")
                    .font(.system(size: 22))
                    .foregroundColor(ColorManager.primaryText)
            }
            .padding(.trailing, 4)
            
            // ルーム情報
            VStack(alignment: .leading, spacing: 4) {
                Text(group.groupName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ColorManager.primaryText)
                
                HStack(spacing: 8) {
                    // メンバー数
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ColorManager.secondaryText)
                        
                        Text("\(group.memberIDs.count)人")
                            .font(.system(size: 14))
                            .foregroundColor(ColorManager.secondaryText)
                    }
                    
                    // 閲覧者数（参加するルームの場合）
                    if !isHostRoom && group.viewerCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 12))
                                .foregroundColor(ColorManager.secondaryText)
                            
                            Text("\(group.viewerCount)人が視聴中")
                                .font(.system(size: 14))
                                .foregroundColor(ColorManager.secondaryText)
                        }
                    }
                    
                    // 配信中バッジ
                    if group.isBroadcasting {
                        Text("LIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(ColorManager.accent)
                            )
                    }
                }
            }
            
            Spacer()
            
            // 矢印アイコン
            Image(systemName: "chevron.right")
                .foregroundColor(ColorManager.tertiaryText)
                .padding(.trailing, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorManager.cardBackground)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ColorManager.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

                                                   // MARK: - NoGroupPageView (ダークテーマ) - 空のグループ表示用
struct NoGroupPageView: View {
    @State private var animationAmount: CGFloat = 1.0
    @State private var showGroupCreationSheet = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 視覚的なアイコン
            ZStack {
                Circle()
                    .fill(ColorManager.secondaryBackground)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "person.3.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(ColorManager.tertiaryText)
            }
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [ColorManager.secondaryAccent.opacity(0.7), ColorManager.accent.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .scaleEffect(animationAmount)
                    .opacity(Double(2 - animationAmount))
                    .animation(
                        Animation.easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: animationAmount
                    )
            )
            .onAppear {
                animationAmount = 1.3
            }
            
            Text("ルームが登録されていません")
                .foregroundColor(ColorManager.primaryText)
                .font(.system(size: 20, weight: .bold))
                .multilineTextAlignment(.center)
            
            Text("新しいルームを作成して\n友達と心拍情報をシェアしよう")
                .foregroundColor(ColorManager.secondaryText)
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
            
            Button(action: {
                showGroupCreationSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("新しくルームを作成")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [ColorManager.secondaryAccent, ColorManager.secondaryAccent.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: ColorManager.secondaryAccent.opacity(0.4), radius: 5, x: 0, y: 3)
            }
            .padding(.top, 20)
            .sheet(isPresented: $showGroupCreationSheet) {
                GroupCreationView()
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(ColorManager.background)
    }
}

                                                   // MARK: - GroupCreationView (ダークテーマ) - 新規ルーム作成
struct GroupCreationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // 許可されたユーザー情報
    @State private var permittedUsers: [PermittedUser] = []
    // 選択されたユーザーIDを保持
    @State private var selectedUserIDs: Set<String> = []
    @State private var groupName: String = ""
    @State private var heartRateSharingEnabled: Bool = true
    
    @State private var permittedUsersHandle: DatabaseHandle?
    @State private var userInfoHandles: [String: DatabaseHandle] = [:]
    
    // アラート用
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    // アニメーション用
    @State private var animateGradient = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                ColorManager.background.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // タイトルとアイコン
                        VStack(spacing: 10) {
                            Image(systemName: "person.3.sequence.fill")
                                .font(.system(size: 60))
                                .foregroundColor(
                                    LinearGradient(
                                        gradient: Gradient(colors: [ColorManager.secondaryAccent, ColorManager.accent]),
                                        startPoint: animateGradient ? .leading : .trailing,
                                        endPoint: animateGradient ? .trailing : .leading
                                    )
                                    .mask(
                                        Image(systemName: "person.3.sequence.fill")
                                            .font(.system(size: 60))
                                    ) as? Color
                                )
                                .onAppear {
                                    withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: true)) {
                                        animateGradient.toggle()
                                    }
                                }
                            
                            Text("ルーム作成")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(ColorManager.primaryText)
                        }
                        .padding(.top, 20)
                        
                        // グループ名入力フィールド
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ルーム名")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ColorManager.secondaryText)
                            
                            TextField("ルーム名を入力", text: $groupName)
                                .foregroundColor(ColorManager.primaryText)
                                .padding()
                                .background(ColorManager.secondaryBackground)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(ColorManager.cardBorder, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal)
                        
                        // 心拍数共有設定
                        VStack(alignment: .leading, spacing: 8) {
                            Text("共有設定")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ColorManager.secondaryText)
                            
                            VStack {
                                Toggle(isOn: $heartRateSharingEnabled) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "heart.fill")
                                            .foregroundColor(ColorManager.accent)
                                            .font(.system(size: 20))
                                        
                                        Text("心拍数共有を許可")
                                            .foregroundColor(ColorManager.primaryText)
                                            .font(.system(size: 16))
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: ColorManager.secondaryAccent))
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                            }
                            .background(ColorManager.secondaryBackground)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(ColorManager.cardBorder, lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                        
                        // メンバー選択
                        VStack(alignment: .leading, spacing: 12) {
                            Text("メンバー選択")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ColorManager.secondaryText)
                                .padding(.horizontal)
                            
                            // フレンド一覧を横スクロール
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(permittedUsers) { user in
                                        Button(action: {
                                            // 選択状態をトグル
                                            if selectedUserIDs.contains(user.id) {
                                                selectedUserIDs.remove(user.id)
                                            } else {
                                                selectedUserIDs.insert(user.id)
                                            }
                                        }) {
                                            UserIconView(
                                                name: user.name,
                                                imageURL: user.imageURL,
                                                imageSize: 60,
                                                isSelected: selectedUserIDs.contains(user.id)
                                            )
                                        }
                                    }
                                }
                                .padding()
                                .padding(.horizontal, 4)
                            }
                            .background(ColorManager.secondaryBackground)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(ColorManager.cardBorder, lineWidth: 1)
                            )
                            .padding(.horizontal)
                            
                            // 選択人数表示
                            if !selectedUserIDs.isEmpty {
                                Text("\(selectedUserIDs.count)人のメンバーを選択中")
                                    .font(.system(size: 14))
                                    .foregroundColor(ColorManager.secondaryAccent)
                                    .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 30)
                        
                        // 作成ボタン
                        Button(action: {
                            if groupName.trimmingCharacters(in: .whitespaces).isEmpty {
                                alertMessage = "ルーム名を入力してください。"
                                showAlert = true
                            } else {
                                createGroup()
                            }
                        }) {
                            Text("ルームを作成")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .bold))
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [ColorManager.secondaryAccent, ColorManager.secondaryAccent.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: ColorManager.secondaryAccent.opacity(0.4), radius: 5, x: 0, y: 3)
                        }
                        .padding(.horizontal)
                        .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(groupName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1.0)
                    }
                }
            }
            .navigationTitle("ルーム作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(ColorManager.secondaryAccent)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("入力エラー"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupPermittedUsersObservers()
        }
        .onDisappear {
            removeAllObservers()
        }
    }
    
    // MARK: - 許可ユーザーの監視設定
    private func setupPermittedUsersObservers() {
        guard let currentUser = authViewModel.currentUser else { return }
        let uid = currentUser.uid
        let ref = Database.database().reference()
        
        permittedUsersHandle = ref.child("AcceptUser").child(uid).child("permittedUser")
            .observe(.value) { snapshot in
                var updatedIDs: Set<String> = []
                for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                    if let allowed = child.value as? Bool, allowed {
                        updatedIDs.insert(child.key)
                    }
                }
                DispatchQueue.main.async {
                    permittedUsers.removeAll { !updatedIDs.contains($0.id) }
                    for newID in updatedIDs {
                        if !permittedUsers.contains(where: { $0.id == newID }) {
                            let newUser = PermittedUser(id: newID, name: "Loading", imageURL: "")
                            permittedUsers.append(newUser)
                            observeUserInfo(for: newID)
                        }
                    }
                }
            }
    }
    
    private func observeUserInfo(for permittedUID: String) {
        let ref = Database.database().reference()
        let handle = ref.child("Username").child(permittedUID)
            .observe(.value) { snapshot in
                if let dict = snapshot.value as? [String: Any] {
                    DispatchQueue.main.async {
                        if let index = permittedUsers.firstIndex(where: { $0.id == permittedUID }) {
                            permittedUsers[index].name = dict["UName"] as? String ?? "不明なユーザー"
                            permittedUsers[index].imageURL = dict["Uimage"] as? String ?? ""
                        }
                    }
                }
            }
        userInfoHandles[permittedUID] = handle
    }
    
    private func removeAllObservers() {
        guard let currentUser = authViewModel.currentUser else { return }
        let uid = currentUser.uid
        let ref = Database.database().reference()
        
        if let handle = permittedUsersHandle {
            ref.child("AcceptUser").child(uid).child("permittedUser").removeObserver(withHandle: handle)
        }
        for (permittedUID, handle) in userInfoHandles {
            ref.child("Username").child(permittedUID).removeObserver(withHandle: handle)
        }
        userInfoHandles.removeAll()
    }
    
    // MARK: - グループ作成処理
    private func createGroup() {
        guard let currentUser = authViewModel.currentUser, !groupName.isEmpty else { return }
        let uid = currentUser.uid
        let ref = Database.database().reference()
        
        // グループIDを自動生成
        let groupRef = ref.child("Userdata").child(uid).child("Groups").childByAutoId()
        let groupID = groupRef.key ?? UUID().uuidString
        
        // 自分も含む全メンバーのIDリスト
        var allMembers = Array(selectedUserIDs)
        if !allMembers.contains(uid) {
            allMembers.append(uid)
        }
        
        let groupData: [String: Any] = [
            "groupName": groupName,
            "createdBy": currentUser.uid,
            "members": allMembers,
            "heartRateSharingEnabled": heartRateSharingEnabled,
            "createdAt": ServerValue.timestamp(),
            "broadcasting": false,
            "active": false
        ]
        
        groupRef.setValue(groupData) { error, _ in
            if let error = error {
                print("ルーム作成エラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    alertMessage = "ルームの作成に失敗しました: \(error.localizedDescription)"
                    showAlert = true
                }
            } else {
                print("ルーム『\(groupName)』が作成されました。ID: \(groupID)")
                // 作成後は入力欄と選択状態をリセット
                DispatchQueue.main.async {
                    groupName = ""
                    selectedUserIDs.removeAll()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

struct AddUserSheetView: View {
    /// 全ユーザーなどを想定（フレンド一覧など）
    let allUsers: [PermittedUser]
    
    /// 親ビューに複数選択したユーザーを渡すコールバック
    let onSelectUsers: ([PermittedUser]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    /// 選択状態のユーザーIDを格納
    @State private var selectedUsers = Set<String>()
    @State private var searchText = ""
    
    var filteredUsers: [PermittedUser] {
        if searchText.isEmpty {
            return allUsers
        } else {
            return allUsers.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ColorManager.tertiaryText)
                    
                    TextField("ユーザーを検索", text: $searchText)
                        .foregroundColor(ColorManager.primaryText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(10)
                .background(ColorManager.secondaryBackground)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // リストで複数ユーザーを選択
                List(filteredUsers) { user in
                    MultipleSelectionRow(
                        user: user,
                        isSelected: selectedUsers.contains(user.id)
                    ) {
                        // タップで選択状態をトグル
                        if selectedUsers.contains(user.id) {
                            selectedUsers.remove(user.id)
                        } else {
                            selectedUsers.insert(user.id)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .background(ColorManager.background)
                
                // 下部の「追加する」ボタン
                Button(action: {
                    confirmSelection()
                }) {
                    Text("追加する (\(selectedUsers.count)人)")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [ColorManager.secondaryAccent, ColorManager.secondaryAccent.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .shadow(color: ColorManager.secondaryAccent.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .disabled(selectedUsers.isEmpty)
                .padding(.bottom, 16)
            }
            .navigationTitle("ユーザーを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(ColorManager.secondaryAccent)
                }
            }
            .background(ColorManager.background.edgesIgnoringSafeArea(.all))
        }
        .preferredColorScheme(.dark)
    }
    
    /// 選択完了 → 親ビューに渡してシートを閉じる
    private func confirmSelection() {
        let selected = allUsers.filter { selectedUsers.contains($0.id) }
        onSelectUsers(selected)
        dismiss()
    }
}

struct MultipleSelectionRow: View {
    let user: PermittedUser
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            // アイコン
            if let url = URL(string: user.imageURL), !user.imageURL.isEmpty {
                KFImage(url)
                    .resizable()
                    .placeholder {
                        Circle().fill(ColorManager.secondaryBackground)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(ColorManager.tertiaryText)
                            )
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(ColorManager.cardBorder, lineWidth: 1)
                    )
            } else {
                Circle()
                    .fill(ColorManager.secondaryBackground)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(ColorManager.tertiaryText)
                    )
                    .overlay(
                        Circle()
                            .stroke(ColorManager.cardBorder, lineWidth: 1)
                    )
            }
            
            // 名前
            Text(user.name)
                .foregroundColor(ColorManager.primaryText)
                .font(.system(size: 16, weight: .medium))
                .padding(.leading, 6)
            
            Spacer()
            
            // チェックマーク
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(ColorManager.secondaryAccent)
                    .font(.system(size: 22))
            } else {
                Image(systemName: "circle")
                    .foregroundColor(ColorManager.tertiaryText)
                    .font(.system(size: 22))
            }
        }
        .contentShape(Rectangle()) // 行全体をタップ可能に
        .onTapGesture {
            onTap()
        }
        .padding(.vertical, 4)
    }
}

struct RemoveUserSheetView: View {
    /// このグループに属するメンバー一覧（削除候補）
    let users: [PermittedUser]
    
    /// グループを管理しているユーザーのID
    let groupOwnerID: String
    
    /// グループID
    let groupID: String
    
    @Environment(\.dismiss) private var dismiss
    
    /// 選択状態のユーザーIDを格納
    @State private var selectedUsers = Set<String>()
    
    var body: some View {
        NavigationView {
            VStack {
                // 複数ユーザーを選択するリスト
                List(users) { user in
                    MultipleSelectionRow(
                        user: user,
                        isSelected: selectedUsers.contains(user.id)
                    ) {
                        // タップで選択状態をトグル
                        if selectedUsers.contains(user.id) {
                            selectedUsers.remove(user.id)
                        } else {
                            selectedUsers.insert(user.id)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .background(ColorManager.background)
                
                // 下部の「削除する」ボタン
                Button(action: {
                    removeSelectedUsers()
                }) {
                    Text("削除する (\(selectedUsers.count)人)")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(selectedUsers.isEmpty ? Color.gray : ColorManager.accent)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .shadow(color: ColorManager.accent.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .disabled(selectedUsers.isEmpty)
                .padding(.bottom, 16)
            }
            .navigationTitle("削除するユーザーを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(ColorManager.secondaryAccent)
                }
            }
            .background(ColorManager.background.edgesIgnoringSafeArea(.all))
        }
        .preferredColorScheme(.dark)
    }
    
    /// 選択されたユーザーを一括削除
    private func removeSelectedUsers() {
        let ref = Database.database().reference()
        
        // グループ作成者(オーナー)のノード
        let groupRef = ref
            .child("Userdata")
            .child(groupOwnerID)
            .child("Groups")
            .child(groupID)
        
        groupRef.observeSingleEvent(of: .value) { snapshot in
            guard var groupDict = snapshot.value as? [String: Any] else { return }
            guard var members = groupDict["members"] as? [String] else { return }
            
            // 選択されたユーザーを members 配列から削除
            for userID in selectedUsers {
                members.removeAll { $0 == userID }
            }
            groupDict["members"] = members
            
            // 配信中の場合はメンバー数も更新
            if let isBroadcasting = groupDict["broadcasting"] as? Bool, isBroadcasting {
                ref.child("BroadcastingRooms").child(groupID)
                    .updateChildValues(["memberCount": members.count])
            }
            
            // Firebaseに更新を反映
            groupRef.setValue(groupDict) { error, _ in
                if error == nil {
                    // 成功したらシートを閉じる
                    DispatchQueue.main.async {
                        dismiss()
                    }
                } else {
                    // エラー処理
                    print("メンバー削除失敗: \(error?.localizedDescription ?? "")")
                }
            }
        }
    }
}
