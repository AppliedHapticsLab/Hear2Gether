import SwiftUI
import FirebaseAuth
import FirebaseDatabase
import AVFoundation
import WatchConnectivity

// MARK: - カメラプレビュー用の UIViewRepresentable
struct CameraPreview: UIViewRepresentable {
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // 必要に応じた更新処理
    }
}

// MARK: - AppleWatchConnectionView（iPhone側の接続用画面）
struct AppleWatchConnectionView: View {
    // 画面遷移フラグ（接続完了後に次画面へ遷移）
    @State private var showModeSelection = false
    // AppViewModel 等、その他の環境オブジェクト（必要に応じて）
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // UserDefaults の値を管理（接続完了表示用）
    @AppStorage("connectionShownKey") private var connectionShown: Bool = false
    
    // カメラマネージャ（QRコード検出用）
    @StateObject private var cameraManager = CameraManager()
    
    // iPhone 側での接続完了判定用フラグ（Watch から matchConfirmed の通知が来た場合に true になる）
    @State private var matchConfirmed: Bool = false
    // Firebase 用のユーザー UUID（事前に iPhone 側で設定しておく）
    @AppStorage("UserUUID") var userUUID: String = "sample-user-uuid"
    
    // アニメーション用
    @State private var pulsate = false
    
    // Firebase参照を追加
    @State private var databaseRef = Database.database().reference()
        
    // 接続状態チェック用のフラグ
    @State private var checkedConnectionStatus = false
    
    // オンライン状態検出用の新しいフラグ
    @State private var watchIsOnline = false
    // 自動接続メッセージの表示制御
    @State private var showAutoConnectMessage = false
    
    // 環境変数（前の画面に戻るため）
    @Environment(\.dismiss) var dismiss
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // 黒背景
            Color.black.edgesIgnoringSafeArea(.all)
            
            // カメラプレビュー
            CameraPreview(session: cameraManager.session)
                .edgesIgnoringSafeArea(.all)
            
            // 半透明のオーバーレイ
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // トップバー
                HStack {
                    Spacer()
                    
                    // スキップボタン
                    Button(action: {
                        // スキップボタン - 次の画面へ
                        completeConnection()
                    }) {
                        Text("Apple Watchがない方はこちら")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(14)
                    }
                    .padding(.trailing, 16)
                }
                .frame(height: 44)
                .padding(.top, getSafeAreaTop())
                
                Spacer()
                
                // Apple Watchのアウトラインフレーム
                ZStack {
                    // 黄色いガイドフレーム - 角丸長方形で手首の形を表現
                    RoundedRectangle(cornerRadius: 38)
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: 220, height: 260)
                    
                    if matchConfirmed {
                        // 接続成功時の表示
                        AppleWatchSuccess()
                    } else {
                            
                        // スキャンを促すパルスアニメーション
                        RoundedRectangle(cornerRadius: 38)
                            .stroke(Color.white.opacity(pulsate ? 0.1 : 0.4), lineWidth: 2)
                            .frame(width: 200, height: 240)
                            .scaleEffect(pulsate ? 1.05 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true),
                                value: pulsate
                            )
                            .onAppear {
                                pulsate = true
                            }
                    }
                }
                .padding(.bottom, 40)
                
                // 下部テキスト
                VStack(spacing: 16) {
                    Text("Apple Watchの「Hear2gether」を開いてください．")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                    
                    Text("表示されたQRコードを画面上のファインダーに合わせてください。")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 20)
                .padding(.horizontal, 20) // 横方向の余白を追加
                
                Spacer()
            }
            
            // 接続成功時のオーバーレイ
            if matchConfirmed {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                
                VStack(spacing: 30) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.green)
                    
                    Text("接続に成功しました")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Button(action: {
                        completeConnection()
                    }) {
                        Text("続ける")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Apple Watchオンライン検出時のオーバーレイ（新規追加）
            if showAutoConnectMessage {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                
                VStack(spacing: 30) {
                    Image(systemName: "applewatch.radiowaves.left.and.right")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                    
                    Text("Apple Watchがオンラインです")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("自動的にメイン画面に移動します...")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onChange(of: cameraManager.recognizedQRCode) { newValue,_ in
            if let scanned = newValue, !matchConfirmed {
                // 振動フィードバック
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // QRコードが検出されたら、iPhone側から Apple Watch へ送信する
                WatchSessionManager.shared.sendScannedData(scannedUUID: scanned, userUUID: userUUID) { confirmed in
                    // 返信で matchConfirmed が true ならボタン表示を有効にする
                    withAnimation(.spring()) {
                        self.matchConfirmed = confirmed
                    }
                }
            }
        }
        // 以下の行を NavigationView 用から fullScreenCover に変更
        .fullScreenCover(isPresented: $showModeSelection) {
                MainView()
        }
        .onAppear {
            guard let user = authViewModel.currentUser else { return }
            userUUID = user.uid
            // AppStatusのisActiveを継続的に監視
            observeActiveStatus(userID: user.uid)
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
    }
    
    /// 接続完了時の共通処理
    private func completeConnection() {
        withAnimation(.easeInOut(duration: 0.5)) {
            showModeSelection = true
            viewModel.isLoggedIn = true
            connectionShown = true
        }
    }
    
    // AppStatusのisActiveを監視する関数（継続的に監視するよう変更）
    private func observeActiveStatus(userID: String) {
        let statusRef = databaseRef.child("Userdata").child(userID).child("AppStatus").child("isActive")
        
        // 値の変更を継続的に監視する
        statusRef.observe(.value) { snapshot in
            if let isActive = snapshot.value as? Bool {
                print("接続状態の変更を検出: \(isActive)")
                
                if isActive && !watchIsOnline {
                    // 初めてtrueになった場合の処理
                    watchIsOnline = true
                    // UIフィードバック
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // 自動接続メッセージを表示
                    withAnimation(.spring()) {
                        showAutoConnectMessage = true
                    }
                    
                    // 2秒後に画面遷移
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        completeConnection()
                    }
                }
            }
        }
        
        // 初回のチェック（すでにtrueの場合に即座に反応するため）
        statusRef.observeSingleEvent(of: .value) { snapshot in
            if let isActive = snapshot.value as? Bool, isActive {
                print("初期チェック: Apple Watchはすでに接続済みです")
                watchIsOnline = true
                
                // 自動接続メッセージを表示
                withAnimation(.spring()) {
                    showAutoConnectMessage = true
                }
                
                // 2秒後に画面遷移
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    completeConnection()
                }
            } else {
                print("初期チェック: Apple Watchは未接続です")
                checkedConnectionStatus = true
            }
        }
    }
    
    // SafeAreaのトップマージンを取得
    private func getSafeAreaTop() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.top ?? 20
    }
}

// MARK: - Apple Watchのフレームを描画
struct AppleWatchFrame: View {
    var body: some View {
        ZStack {
            // 本体フレーム
            RoundedRectangle(cornerRadius: 32)
                .foregroundColor(.gray.opacity(0.9))
                .frame(width: 170, height: 200)
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 4)
            
        }
    }
}

// MARK: - 接続成功時のApple Watch表示
struct AppleWatchSuccess: View {
    var body: some View {
        ZStack {
            
            // 成功表示（ディスプレイ部分にオーバーレイ）
            RoundedRectangle(cornerRadius: 28)
                .foregroundColor(.black)
                .frame(width: 152, height: 182)
                .overlay(
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .foregroundColor(.green)
                        
                        Text("接続完了")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                )
        }
    }
}

// MARK: - カメラマネージャ（QRコード検出）
class CameraManager: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    // 検出された QR コードの内容を保持する
    @Published var recognizedQRCode: String? = nil
    
    override init() {
        super.init()
        configureSession()
    }
    
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                        for: .video,
                                                        position: .back),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoDeviceInput)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(videoDeviceInput)
        
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }
        
        session.commitConfiguration()
        // 推奨: バックグラウンドスレッドで実行
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           metadataObject.type == .qr,
           let qrValue = metadataObject.stringValue {
            recognizedQRCode = qrValue
        } else {
            recognizedQRCode = nil
        }
    }
}

// MARK: - iPhone側 WatchSessionManager
class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    /// iPhone 側で読み取った QR コードの UUID と、Firebase 用ユーザー UUID を Apple Watch に送信する
    func sendScannedData(scannedUUID: String, userUUID: String, completion: @escaping (Bool) -> Void) {
        guard WCSession.default.isReachable else {
            print("iPhone: Apple Watch が接続されていません")
            completion(false)
            return
        }
        
        let message: [String: Any] = [
            "scannedUUID": scannedUUID,
            "userUUID": userUUID
        ]
        
        WCSession.default.sendMessage(message, replyHandler: { reply in
            print("iPhone: Watch からの返信: \(reply)")
            if let matchConfirmed = reply["matchConfirmed"] as? Bool {
                completion(matchConfirmed)
            } else {
                completion(false)
            }
        }, errorHandler: { error in
            print("iPhone: メッセージ送信エラー: \(error.localizedDescription)")
            completion(false)
        })
    }
    
    // MARK: - WCSessionDelegate の最低限の実装
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("iPhone: activation state \(activationState.rawValue)")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}

struct AppleWatchConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        AppleWatchConnectionView()
            .environmentObject(AppViewModel())
    }
}
