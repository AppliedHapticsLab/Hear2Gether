//
//  Hear2getherApp.swift
//  Hear2gether
//
//  Created by Applied Haptics Laboratory on 2025/02/06.
//

import SwiftUI
import Firebase
import UserNotifications
import FirebaseDatabase

// 更新した AppDelegate: 通知設定と Watch Connectivity サービスを追加
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // Watch Connectivity サービスのインスタンス（※実装済みの iPhoneWatchConnectivityService を想定）
    var watchConnectivity = iPhoneWatchConnectivityService()
    
    // Firebase関連
    private var databaseRef: DatabaseReference?
    private var heartbeatTimer: Timer?
    private let heartbeatInterval: TimeInterval = 30 // 30秒ごとにハートビート送信
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Firebase の初期化
        FirebaseApp.configure()
        
        // ユーザー通知の設定
        setupNotifications(application)
        
        // iPhoneの状態を「アクティブ」に更新
        updateIPhoneStateToFirebase(state: "active")
        
        // ハートビートタイマーを開始
        startHeartbeatTimer()
        
        return true
    }
    
    // ユーザー通知の設定
    private func setupNotifications(_ application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("通知許可エラー: \(error.localizedDescription)")
            }
        }
        
        application.registerForRemoteNotifications()
    }
    
    // フォアグラウンド時に通知を表示
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .sound, .banner, .list])
    }
    
    // ハートビートタイマーを開始
    private func startHeartbeatTimer() {
        // 既存のタイマーを停止
        heartbeatTimer?.invalidate()
        
        // 新しいタイマーを開始
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // アクティブ状態とタイムスタンプをFirebaseに送信
            self.updateIPhoneStateToFirebase(state: "active", includeTimestamp: true)
        }
    }
    
    // Firebaseにiphone状態を送信する関数
    private func updateIPhoneStateToFirebase(state: String, includeTimestamp: Bool = false) {
        // UserIDを取得 (AuthViewModelから実際のユーザーIDを取得する必要があります)
        guard let userID = getUserID() else {
            print("iPhone状態更新: 有効なユーザーIDが見つかりません")
            return
        }
        
        // Firebase Realtime Databaseへの参照
        if databaseRef == nil {
            databaseRef = Database.database().reference().child("Userdata").child(userID).child("iphoneState")
        }
        
        // 現在の時刻（Unix時間）
        let timestamp = Date().timeIntervalSince1970
        
        // 更新データの作成
        var stateData: [String: Any] = ["state": state]
        
        // タイムスタンプを含める場合（ハートビート用）
        if includeTimestamp {
            stateData["timestamp"] = timestamp
        }
        
        // 状態更新
        databaseRef?.updateChildValues(stateData) { error, _ in
            if let error = error {
                print("iPhone状態更新エラー: \(error.localizedDescription)")
            } else {
                print("iPhoneの状態を正常に更新しました: \(state)")
            }
        }
    }
    
    // ユーザーIDを取得するヘルパーメソッド
    private func getUserID() -> String? {
        // 実際の実装では、認証済みユーザーIDを返す必要があります
        // 例: Auth.auth().currentUser?.uid
        // または UserDefaults から取得
        return UserDefaults.standard.string(forKey: "UUID")
    }
    
    // アプリがアクティブになった時の処理
    func applicationDidBecomeActive(_ application: UIApplication) {
        updateIPhoneStateToFirebase(state: "active")
        startHeartbeatTimer()
    }
    
    // アプリが非アクティブになる時の処理
    func applicationWillResignActive(_ application: UIApplication) {
        // 非アクティブになっても状態更新はしない（バックグラウンドに行くわけではないため）
    }
    
    class TaskIdentifierHolder {
        var taskID: UIBackgroundTaskIdentifier = .invalid
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        updateIPhoneStateToFirebase(state: "background")
        
        let taskHolder = TaskIdentifierHolder()
        
        // タスクIDを取得してラッパーに格納
        taskHolder.taskID = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(taskHolder.taskID)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.heartbeatTimer?.invalidate()
            self.heartbeatTimer = nil
            
            UIApplication.shared.endBackgroundTask(taskHolder.taskID)
        }
    }
    
    // アプリがフォアグラウンドに戻る時の処理
    func applicationWillEnterForeground(_ application: UIApplication) {
        updateIPhoneStateToFirebase(state: "active")
        startHeartbeatTimer()
    }
    
    // アプリが終了する時の処理
    func applicationWillTerminate(_ application: UIApplication) {
        updateIPhoneStateToFirebase(state: "terminated")
        
        // ハートビートタイマーを停止
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
}

// アプリ全体で利用する定数
struct Constants {
    static let connectionShownKey = "hasShownAppleWatchConnection"
}

/// メインのルートビュー（修正版）
struct RootView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage(Constants.connectionShownKey) private var connectionShown: Bool = false
    
    var body: some View {
        ZStack {
            if authViewModel.isLoggedIn {
                if !connectionShown {
                    // AppleWatchConnectionView を NavigationStack でラップ
                    NavigationStack {
                        AppleWatchConnectionView()
                    }
                    .transition(.opacity)
                } else {
                    MainView()
                        .transition(.opacity)
                }
            } else {
                NavigationStack {
                    LoginView()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: authViewModel.isLoggedIn)
    }
}

// アプリのエントリポイント
@main
struct HeartRateGameApp: App {
    // 更新した AppDelegate を利用
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var viewModeManager = ViewModeManager()
    
    var body: some Scene {
        WindowGroup {
            // 既存の RootView に各種環境オブジェクトを注入
            RootView()
                .environmentObject(viewModel)
                .environmentObject(authViewModel)
                .environmentObject(viewModeManager)
                // AppDelegate 経由の Watch Connectivity サービスを環境オブジェクトとして追加
                .environmentObject(appDelegate.watchConnectivity)
        }
    }
}
