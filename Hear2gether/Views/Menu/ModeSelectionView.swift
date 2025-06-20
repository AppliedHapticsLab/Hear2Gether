//
//  ModeSelectionView.swift
//  Hear2gether
//
//  Created by Applied Haptics Laboratory on 2025/02/06.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseDatabase

// 閲覧モードとメンテナンスモードの状態を管理するための環境オブジェクト
class ViewModeManager: ObservableObject {
    @Published var isViewOnlyMode: Bool = false
    @Published var isMaintenanceMode: Bool = false // メンテナンスモードの状態
    @Published var maintenanceMessage: String = "現在システムメンテナンス中です" // メンテナンスメッセージ
}

struct ModeSelectionView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var viewModeManager: ViewModeManager
    @State private var selectedTab = 0
    
    // Firebase references and handles
    @State private var appStateHandle: DatabaseHandle?
    @State private var appStatusHandle: DatabaseHandle?
    @State private var maintenanceHandle: DatabaseHandle? // メンテナンスモード用のハンドル
    
    // Apple Watchのアクティブ状態を追跡
    @State private var isWatchActive: Bool = true
    
    // 以前の選択タブを記憶（閲覧モード時に選択できないタブからの復帰用）
    @State private var previousSelectedTab = 0
    
    // ローカル操作とFirebaseからの更新を区別するためのフラグ
    @State private var isUpdatingFromFirebase = false
    
    // タブアイテムのデータ
    private let tabItems = [
        TabItem(title: "一人で", icon: "person.fill"),
        TabItem(title: "二人で", icon: "person.2.fill"),
        TabItem(title: "みんなと", icon: "shareplay"),
        TabItem(title: "設定", icon: "gearshape.fill")
    ]
    
    // Animation properties
    @State private var isAnimating = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 閲覧モードインジケーター（閲覧モード時のみ表示）
            VStack(spacing: 0) {
                if viewModeManager.isViewOnlyMode {
                    ViewOnlyModeIndicator()
                }
                Spacer()
            }
            .zIndex(1) // 他の要素より前面に表示
            
            TabView(selection: $selectedTab) {
                OnePersonHeartRateView()
                    .tag(0)
                    .ignoresSafeArea(edges: .top)
                    .overlay(
                        // 閲覧モード時にTag 0に表示するオーバーレイ
                        Group {
                            if viewModeManager.isViewOnlyMode && selectedTab == 0 {
                                ZStack {
                                    Color.black.opacity(0.7)
                                    VStack(spacing: 12) {
                                        Image(systemName: "applewatch.radiowaves.left.and.right")
                                            .font(.system(size: 40))
                                            .foregroundColor(.white)
                                        
                                        Text("この機能はApple Watchの接続が必要です")
                                            .font(.headline)
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(.white)
                                            .padding(.horizontal)
                                    }
                                    .padding()
                                }
                                .edgesIgnoringSafeArea(.all)
                            }
                        }
                    )
                
                UserSelectionView()
                    .tag(1)
                    .ignoresSafeArea(edges: .top)
                
                RoomSelectionView()
                    .tag(2)
                    .ignoresSafeArea(edges: .top)
                
                OptionsView()
                    .tag(3)
                    .ignoresSafeArea(edges: .top)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: selectedTab) { newValue, _ in
                print("selectTab: \(selectedTab)")
                // 閲覧モード時にTag 0の選択を防止
                if viewModeManager.isViewOnlyMode && newValue == 0 {
                    DispatchQueue.main.async {
                        self.selectedTab = previousSelectedTab != 0 ? previousSelectedTab : 1
                    }
                    return
                }
                
                
                // Firebaseからの更新でない場合のみ、Firebaseに反映する
                if !isUpdatingFromFirebase {
                    updateModeInFirebase(mode: selectedTab)
                } else {
                    // リモート更新後はフラグをリセット
                    isUpdatingFromFirebase = false
                }
                
                // 前回の有効なタブを記憶（条件付き更新）
                if newValue != 0 || !viewModeManager.isViewOnlyMode {
                    previousSelectedTab = newValue
                }
                
                print("newValue: \(newValue)")
                withAnimation(.spring()) {
                    isAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isAnimating = false
                }
            }
            
            // カスタムタブバー
            CustomTabBar(selectedTab: $selectedTab, items: tabItems, isAnimating: isAnimating, isViewOnlyMode: viewModeManager.isViewOnlyMode)
            
            // Apple Watchのオフライン状態を表示するオーバーレイ
            if !isWatchActive && !viewModeManager.isViewOnlyMode {
                WatchOfflineOverlay(viewModeManager: viewModeManager)
                    .environmentObject(authViewModel)
            }
            
            // メンテナンスモードオーバーレイ（最前面に表示）
            if viewModeManager.isMaintenanceMode {
                MaintenanceOverlay(viewModeManager: viewModeManager)
                    .zIndex(10) // 最も前面に表示
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            // 標準のタブバーとナビゲーションバーの外観を設定
            configureUIAppearance()
            
            // Firebaseリスナーをセットアップ
            setupFirebaseListeners()
            // 明示的にWatch状態を確認
            checkInitialWatchStatus()
            
            // メンテナンスモードの初期チェックを追加
            checkMaintenanceStatus()
        }
        .onDisappear {
            // Firebaseリスナーをクリーンアップ
            removeFirebaseListeners()
        }
    }
    
    // メンテナンス状態をチェックする関数
    private func checkMaintenanceStatus() {
        let ref = Database.database().reference()
        
        // グローバルなメンテナンスフラグをチェック
        ref.child("AppConfig").child("maintenance").child("isActive").observeSingleEvent(of: .value) { snapshot in
            if let isActive = snapshot.value as? Bool {
                DispatchQueue.main.async {
                    withAnimation {
                        self.viewModeManager.isMaintenanceMode = isActive
                    }
                }
            } else {
                // 値がない場合はデフォルトでfalseに設定
                ref.child("AppConfig").child("maintenance").child("isActive").setValue(false)
            }
        }
        
        // メンテナンスメッセージがあれば取得
        ref.child("AppConfig").child("maintenance").child("message").observeSingleEvent(of: .value) { snapshot in
            if let message = snapshot.value as? String {
                DispatchQueue.main.async {
                    self.viewModeManager.maintenanceMessage = message
                }
            } else {
                // デフォルトのメッセージを設定
                ref.child("AppConfig").child("maintenance").child("message").setValue("現在システムメンテナンス中です。ご不便をおかけして申し訳ありません。")
            }
        }
    }
    
    private func checkInitialWatchStatus() {
        guard let user = authViewModel.currentUser else { return }
        let uid = user.uid
        let ref = Database.database().reference()
        
        ref.child("Userdata").child(uid).child("AppStatus").child("isActive").observeSingleEvent(of: .value) { snapshot in
            DispatchQueue.main.async {
                if let isActive = snapshot.value as? Bool {
                    self.isWatchActive = isActive
                } else {
                    // 値がない場合は明示的にfalseに設定
                    self.isWatchActive = false
                    // 値がなければ作成する
                    ref.child("Userdata").child(uid).child("AppStatus").child("isActive").setValue(false)
                }
            }
        }
    }
    
    private func configureUIAppearance() {
        // タブバーを非表示に
        UITabBar.appearance().isHidden = true
        
        // ナビゲーションバーのスタイルを設定
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(ColorManager.backgroundColor)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.boldSystemFont(ofSize: 18)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // Firebaseリスナー設定
    private func setupFirebaseListeners() {
        guard let user = authViewModel.currentUser else {
            print("Error: No authenticated user found")
            return
        }
        
        let uid = user.uid
        let ref = Database.database().reference()
        
        // AppState（モード情報）の監視を追加
        appStateHandle = ref.child("Userdata").child(uid).child("AppState").child("CurrentMode")
            .observe(.value) { snapshot in
                if let mode = snapshot.value as? Int, mode != self.selectedTab {
                    DispatchQueue.main.async {
                        // Firebaseからの更新の場合、フラグを立ててタブを変更
                        self.isUpdatingFromFirebase = true
                        self.selectedTab = mode
                    }
                }
            }
        
        // AppStatus（Watchのアクティブ状態）の監視を追加
        appStatusHandle = ref.child("Userdata").child(uid).child("AppStatus").child("isActive")
            .observe(.value) { snapshot in
                if let isActive = snapshot.value as? Bool {
                    DispatchQueue.main.async {
                        self.isWatchActive = isActive
                        print("Watch active status updated: \(isActive)")
                        
                        // Watchがアクティブになった場合、自動的に閲覧モードを解除
                        if isActive && self.viewModeManager.isViewOnlyMode {
                            withAnimation {
                                self.viewModeManager.isViewOnlyMode = false
                            }
                        }
                    }
                } else {
                    // 値がない場合もオフラインとして扱う
                    DispatchQueue.main.async {
                        self.isWatchActive = false
                    }
                }
            }
            
        // メンテナンスモードの監視を追加
        maintenanceHandle = ref.child("AppConfig").child("maintenance").child("isActive")
            .observe(.value) { snapshot in
                if let isActive = snapshot.value as? Bool {
                    DispatchQueue.main.async {
                        withAnimation {
                            self.viewModeManager.isMaintenanceMode = isActive
                        }
                    }
                }
            }
        
        // メンテナンスメッセージの監視も追加
        ref.child("AppConfig").child("maintenance").child("message")
            .observe(.value) { snapshot in
                if let message = snapshot.value as? String {
                    DispatchQueue.main.async {
                        self.viewModeManager.maintenanceMessage = message
                    }
                }
            }
    }
    
    // Firebaseリスナー削除
    private func removeFirebaseListeners() {
        guard let user = authViewModel.currentUser else { return }
        let uid = user.uid
        let ref = Database.database().reference()
        
        if let handle = appStateHandle {
            ref.child("Userdata").child(uid).child("AppState").child("CurrentMode")
                .removeObserver(withHandle: handle)
        }
        
        if let handle = appStatusHandle {
            ref.child("Userdata").child(uid).child("AppStatus").child("isActive")
                .removeObserver(withHandle: handle)
        }
        
        // メンテナンスモードのリスナーも削除
        if let handle = maintenanceHandle {
            ref.child("AppConfig").child("maintenance").child("isActive")
                .removeObserver(withHandle: handle)
        }
    }
    
    // Firebaseにモード情報を更新するメソッド
    private func updateModeInFirebase(mode: Int) {
        guard let user = authViewModel.currentUser else {
            print("Error: No authenticated user found")
            return
        }
        
        let uid = user.uid
        let databaseRef = Database.database().reference()
        
        // CurrentMode を直接更新
        databaseRef.child("Userdata").child(uid).child("AppState").child("CurrentMode").setValue(mode) { error, _ in
            if let error = error {
                print("Error updating CurrentMode in Firebase: \(error.localizedDescription)")
            } else {
                print("Successfully updated CurrentMode in Firebase: \(mode)")
                // タイムスタンプは別途更新
                databaseRef.child("Userdata").child(uid).child("AppState").child("LastUpdated").setValue(ServerValue.timestamp())
                
                // ユーザーデフォルトにも保存（オフライン用）
                UserDefaults.standard.set(mode, forKey: "LastSelectedMode")
            }
        }
    }
}

// メンテナンス中に表示するオーバーレイビュー
struct MaintenanceOverlay: View {
    @ObservedObject var viewModeManager: ViewModeManager
    
    var body: some View {
        ZStack {
            // 半透明の背景
            Color.black.opacity(0.85)
                .edgesIgnoringSafeArea(.all)
            
            // メッセージカード
            VStack(spacing: 20) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                Text("メンテナンス中")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(viewModeManager.maintenanceMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal)
                
                // 現在時刻を表示して再接続を試みる
                Text("しばらく経ってからアプリを再起動してください")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 8)
                
                // 再接続を試みるボタン
                Button(action: {
                    // 再接続を試みる（Firebaseへの接続再確認）
                    checkMaintenanceStatus()
                }) {
                    Text("再接続を試みる")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(ColorManager.primaryColor)
                        )
                }
                .padding(.top, 16)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.darkGray).opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.red.opacity(0.7), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 15, x: 0, y: 10)
            .padding(40)
        }
    }
    
    // メンテナンスステータスを再確認する関数
    private func checkMaintenanceStatus() {
        // Firebaseデータベースへの参照
        let ref = Database.database().reference()
        
        // グローバルなメンテナンスフラグをチェック
        ref.child("AppConfig").child("maintenance").child("isActive").observeSingleEvent(of: .value) { snapshot in
            if let isActive = snapshot.value as? Bool {
                DispatchQueue.main.async {
                    withAnimation {
                        self.viewModeManager.isMaintenanceMode = isActive
                    }
                    
                    // メンテナンスが終了していた場合に通知
                    if !isActive {
                        // ここで通知を表示したり、アプリを再読み込みしたりできます
                    }
                }
            }
        }
        
        // メンテナンスメッセージがあれば取得
        ref.child("AppConfig").child("maintenance").child("message").observeSingleEvent(of: .value) { snapshot in
            if let message = snapshot.value as? String {
                DispatchQueue.main.async {
                    self.viewModeManager.maintenanceMessage = message
                }
            }
        }
    }
}

// Apple Watchのオフライン状態を表示するオーバーレイ

// Apple Watchのオフライン状態を表示するオーバーレイビュー
struct WatchOfflineOverlay: View {
    @ObservedObject var viewModeManager: ViewModeManager
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // シミュレーター検出用
    #if targetEnvironment(simulator)
    let isSimulator = true
    #else
    let isSimulator = false
    #endif
    
    var body: some View {
        ZStack {
            // 背景オーバーレイ
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            // メッセージカード
            VStack(spacing: 16) {
                Image(systemName: "applewatch.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                
                Text("Apple Watchがオフラインです")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Apple Watchの接続状態を確認してください")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal)
                
                // シミュレーターで実行中の場合、UIDを表示
                if isSimulator {
                    VStack(spacing: 8) {
                        Text("Running in simulator mode")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yellow)
                            .padding(.top, 12)
                        
                        if let user = authViewModel.currentUser {
                            Text("Current UUID: \(user.uid)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                            
                            Text("Please enter this UUID in your Apple Watch app")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                    )
                }
                
                // 閲覧モードに切り替えるボタン
                Button(action: {
                    withAnimation(.easeInOut) {
                        viewModeManager.isViewOnlyMode = true
                    }
                }) {
                    Text("閲覧のみをします")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(ColorManager.primaryColor)
                        )
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.darkGray))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(ColorManager.primaryColor.opacity(0.6), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            .padding(32)
        }
    }
}

// タブアイテムを表すデータモデル
struct TabItem {
    let title: String
    let icon: String
}

// カスタムタブバーのデザイン
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let items: [TabItem]
    var isAnimating: Bool
    var isViewOnlyMode: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { index in
                Button(action: {
                    // 閲覧モード時はタブ0を選択できないようにする
                    if !(isViewOnlyMode && index == 0) {
                        withAnimation(.spring()) {
                            selectedTab = index
                        }
                    }
                }) {
                    VStack(spacing: 6) {
                        // アイコン
                        Image(systemName: items[index].icon)
                            .font(.system(size: 24))
                            .foregroundColor(selectedTab == index ? ColorManager.primaryColor :
                                             (isViewOnlyMode && index == 0) ? Color.gray.opacity(0.4) : Color.gray)
                            .scaleEffect(selectedTab == index && isAnimating ? 1.2 : 1.0)
                            .overlay(
                                // 閲覧モード時にタブ0に斜線を表示
                                Group {
                                    if isViewOnlyMode && index == 0 {
                                        Image(systemName: "slash.circle")
                                            .font(.system(size: 20))
                                            .foregroundColor(.red.opacity(0.7))
                                            .offset(x: 8, y: -8)
                                    }
                                }
                            )
                        
                        // タブタイトル
                        Text(items[index].title)
                            .font(.system(size: 12, weight: selectedTab == index ? .semibold : .regular))
                            .foregroundColor(selectedTab == index ? ColorManager.primaryColor :
                                             (isViewOnlyMode && index == 0) ? Color.gray.opacity(0.4) : Color.gray)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            if selectedTab == index {
                                // 選択中のタブの背景効果
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ColorManager.backgroundColor.opacity(0.3))
                                    .padding(.horizontal, 10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(ColorManager.primaryColor.opacity(0.3), lineWidth: 1)
                                            .padding(.horizontal, 10)
                                    )
                                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                            }
                        }
                    )
                }
                .buttonStyle(TabButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 30) // セーフエリア用の余白
        .background(
            // タブバーの背景 - 上部の角丸を削除
            Rectangle()
                .fill(ColorManager.backgroundColor.opacity(0.95))
                .edgesIgnoringSafeArea(.bottom)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
        )
    }
}

// 角丸の一部だけを適用する拡張
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// 角丸の一部だけを実現するシェイプ
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// タブボタンのスタイル
struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// 閲覧モードを表示するインジケーターバー（シンプル版）
struct ViewOnlyModeIndicator: View {
    var body: some View {
        HStack {
            Image(systemName: "eye")
                .font(.system(size: 16))
                .foregroundColor(.white)
            Text("閲覧モード")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(Color.orange.opacity(0.7))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

// ViewModelレイヤーでApple Watchの接続状態を確認し、必要に応じて閲覧モードを自動的に解除するメソッド
extension ViewModeManager {
    func checkWatchConnectionAndUpdateMode(authViewModel: AuthViewModel, completion: @escaping (Bool) -> Void) {
        guard let user = authViewModel.currentUser else {
            completion(false)
            return
        }
        
        let uid = user.uid
        let ref = Database.database().reference()
        
        // Firebase からのリアルタイム監視の代わりに単一の読み取りを行う
        ref.child("Userdata").child(uid).child("AppStatus").child("isActive").observeSingleEvent(of: .value) { snapshot in
            if let isActive = snapshot.value as? Bool {
                DispatchQueue.main.async {
                    if isActive {
                        withAnimation(.easeInOut) {
                            self.isViewOnlyMode = false
                        }
                    }
                    completion(isActive)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        } withCancel: { error in
            print("Error checking watch connection: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
}

// Previews
struct ModeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ModeSelectionView()
            .environmentObject(AuthViewModel())
            .preferredColorScheme(.dark)
    }
}
