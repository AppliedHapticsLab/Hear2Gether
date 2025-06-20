import SwiftUI
import EFQRCode  // EFQRCode を導入（Swift Package Managerなどで追加してください）
import WatchConnectivity
import ImageIO  // ImageIO を追加

struct QRLoginView: View {
    // ランダムなUIDと有効期限（5分）
    @State private var randomUID: String = UUID().uuidString
    @State private var expirationDate: Date = Date().addingTimeInterval(300) // 300秒＝5分
    
    // タイマーで画面更新（残り時間の更新用）
    @State private var timer: Timer? = nil
    
    // 生成されたQRコード画像
    @State private var qrImage: UIImage? = nil
    // iPhone側からの応答で画面遷移するための環境オブジェクト
    @EnvironmentObject var connector: LoginConnector
    @EnvironmentObject var extensionDelegate: ExtensionDelegate
    
    // デバッグモード用のフラグとUUID
    #if targetEnvironment(simulator)
    @State private var isDebugMode: Bool = false
    @State private var debugUUID: String = "6YaJ3UEyp5SVUOch1DYdNobQAFD2"
    #endif
    
    // 画面サイズ（watchOSの場合は WKInterfaceDevice.current().screenBounds で取得）
    private let screenBounds = WKInterfaceDevice.current().screenBounds
    
    private let meURL = "https://test-dff46-default-rtdb.firebaseio.com"
    
    var body: some View {
        if connector.shouldNavigate {
            // onAppear を使用して副作用を実行
            HelloView()
                .environmentObject(connector)
                .environmentObject(extensionDelegate)
                .onAppear {
                    
                    updateAppStatusToFirebase(isActive: true, reason: "becameActive")
                }
        } else {
                ScrollView {
                    VStack {
                        Text("iPhoneでスキャン")
                            .font(.headline)
                        
                        // 有効期限切れの場合、再生成ボタンを表示
                        if remainingTime() <= 0 {
                            Button("QRコード再生成") {
                                regenerateQR()
                            }
                            .padding()
                            .background(Color.blue.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        } else {
                            // 生成されたQRコード画像表示
                            if let qrImage = qrImage {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: 150, height: 150)
                            } else {
                                Text("QRコード生成中...")
                            }
                        }
                        
                        // シミュレータでのみ表示されるデバッグモード
                        #if targetEnvironment(simulator)
                        Toggle("デバッグモード", isOn: $isDebugMode)
                            .padding(.top, 10)
                            .foregroundColor(.orange)
                        
                        if isDebugMode {
                            // UUID入力フィールド
                            TextField("デバッグUUID", text: $debugUUID)
                            
                            Button("デバッグ: 次の画面へ") {
                                connector.receivedData = debugUUID
                                print(connector.receivedData)
                                connector.shouldNavigate = true
                            }

                        }
                        #endif
                        
                        // スクロール用の余白
                        Spacer().frame(height: 20)
                    }
                    .padding(.vertical, 10)
                }
                .onAppear {
                    generateQRCode()
                    startTimer()
                }
                .onDisappear {
                    timer?.invalidate()
                }
            }
        }
   
    /// UID と有効期限を再生成し、新たなQRコードを生成する
    private func regenerateQR() {
        randomUID = UUID().uuidString
        expirationDate = Date().addingTimeInterval(300)
        generateQRCode()
    }
    
    /// 現在の残り時間（秒）を返す
    private func remainingTime() -> Int {
        let remaining = Int(expirationDate.timeIntervalSince(Date()))
        return max(remaining, 0)
    }
    
    /// 残り時間を mm:ss 形式の文字列に変換して返す
    private func remainingTimeString() -> String {
        let remaining = remainingTime()
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func generateQRCode() {
        // QRコードの内容として使う randomUID を expectedQRCode にも設定
        connector.expectedQRCode = randomUID

        // Asset Catalog に "logo" という名前で画像を登録しておく（例：企業ロゴ）
        if let cgImage = EFQRCode.generate(
            for: randomUID
            //watermark: UIImage(named: "logo")?.cgImage
        ) {
            self.qrImage = UIImage(cgImage: cgImage)
            print("Create QRCode image success \(cgImage)")
        } else {
            print("Create QRCode image failed!")
        }
    }
    
    // Firebaseにアプリ状態を送信する関数
    private func updateAppStatusToFirebase(isActive: Bool, reason: String) {
        // UserDefaultsからユーザーIDを取得
        guard let userID = UserDefaults.standard.string(forKey: "UUID"),
              !userID.isEmpty, userID != "No data" else {
            print("アプリ状態更新: 有効なユーザーIDが見つかりません")
            return
        }
        
        // FirebaseのURL作成
        guard let url = URL(string: "\(meURL)/Userdata/\(userID)/AppStatus.json") else {
            print("アプリ状態更新: 無効なURL")
            return
        }
        
        // リクエスト作成
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        
        // アプリの状態データを作成
        let statusData: [String: Any] = [
            "isActive": isActive,
            "lastUpdated": Int64(Date().timeIntervalSince1970 * 1000),
            "stateChangeReason": reason
        ]
        
        // JSONに変換
        guard let jsonData = try? JSONSerialization.data(withJSONObject: statusData) else {
            print("アプリ状態更新: JSONシリアライズに失敗")
            return
        }
        
        request.httpBody = jsonData
        
        // リクエスト送信
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("アプリ状態更新: エラー発生 \(error.localizedDescription)")
                return
            }
            
            print("アプリ状態を正常にFirebaseに更新しました: \(isActive ? "アクティブ" : "非アクティブ") (理由: \(reason))")
        }.resume()
    }
    
    /// 1秒ごとにタイマーで更新する（画面更新用）
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            _ = self.remainingTimeString()
        }
    }
}

struct QRLoginView_Previews: PreviewProvider {
    static var previews: some View {
        QRLoginView()
            .environmentObject(LoginConnector())
            .environmentObject(ExtensionDelegate())
    }
}

class LoginConnector: NSObject, ObservableObject, WCSessionDelegate {
    // MARK: - プロパティ
    @Published var receivedMessage = "PHONE : 未受信"
    @AppStorage("AuthPass") var count = ""
    @AppStorage("LoginFlag") var shouldNavigate: Bool = false
    @AppStorage("UUID") var receivedData = "" // iPhone側から送られてくるユーザーUUIDを格納
    @Published var isPermissionDenied: Bool = false
    @AppStorage("VibrationSet") var vibrationData = false
    @AppStorage("VibrationMode") var vibrationMode = 0
    @Published var isWatchConnected: Bool = false

    // Watch 側で期待するQRコードの内容（QRLoginView で設定される）
    @Published var expectedQRCode: String = ""
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - WCSessionDelegate Methods
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Watch: activationDidCompleteWith state=\(activationState.rawValue)")
    }
    
    // MARK: - メッセージ受信処理
    // iPhone 側から送られてくるメッセージに、"scannedUUID" と "userUUID" が含まれる前提
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            if let scannedUUID = message["scannedUUID"] as? String,
               let userUUID = message["userUUID"] as? String {
                print("Watch: Received scannedUUID: \(scannedUUID)")
                print("Watch: Received userUUID: \(userUUID)")
                var matchConfirmed = false
                if scannedUUID == self.expectedQRCode {
                    self.shouldNavigate = true
                    self.receivedData = userUUID
                    matchConfirmed = true
                    print("Watch: UUID 一致。次の画面へ遷移します。")
                } else {
                    self.shouldNavigate = false
                    print("Watch: UUID 不一致。")
                    print(self.expectedQRCode)
                }
                // 返信時に、"matchConfirmed" キーを追加して iPhone 側に送信
                replyHandler(["received": true, "matchConfirmed": matchConfirmed])
            } else {
                self.count = "No data"
                self.receivedData = "No data"
                self.shouldNavigate = false
                print("Watch: メッセージ内容の読み込みに失敗しました。")
                replyHandler(["received": false])
            }
        }
    }
    
    // 他の必要な WCSessionDelegate メソッドも実装してください…
}
