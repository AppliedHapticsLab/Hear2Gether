import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseDatabase
import FirebaseStorage
import CryptoKit
import AuthenticationServices
import GoogleSignIn

/// 既存ユーザーのデータ構造の整合性を確認・修正
private func validateUserDataStructure(for user: User) {
    let ref = Database.database().reference()
    let uid = user.uid
    
    // Username ノードの確認
    ref.child("Username").child(uid).observeSingleEvent(of: .value) { snapshot in
        if !snapshot.exists() {
            // Username ノードがない場合は作成
            let usernameData: [String: Any] = [
                "UName": user.displayName ?? "User\(Int.random(in: 1000...9999))",
                "Uimage": user.photoURL?.absoluteString ?? ""
            ]
            ref.child("Username").child(uid).setValue(usernameData)
        }
    }
    
    // AppState ノードの確認
    ref.child("Userdata").child(uid).child("AppState").observeSingleEvent(of: .value) { snapshot in
        if !snapshot.exists() {
            // AppState ノードがない場合は作成
            let appStateData: [String: Any] = [
                "CurrentMode": 0,
                "LastUpdated": ServerValue.timestamp(),
                "CurrentGroup": "",
                "hostID": "",
                "SelectUser": "None"
            ]
            ref.child("Userdata").child(uid).child("AppState").setValue(appStateData)
        }
    }
    
    // AppStatus ノードの確認
    ref.child("Userdata").child(uid).child("AppStatus").observeSingleEvent(of: .value) { snapshot in
        if !snapshot.exists() {
            // AppStatus ノードがない場合は作成
            let appStatusData: [String: Any] = [
                "isActive": false,
                "lastConnected": ServerValue.timestamp()
            ]
            ref.child("Userdata").child(uid).child("AppStatus").setValue(appStatusData)
        }
    }
    
    // Heartbeat ノードの確認
    ref.child("Userdata").child(uid).child("Heartbeat").child("Watch1").observeSingleEvent(of: .value) { snapshot in
        if !snapshot.exists() {
            // Heartbeat ノードがない場合は作成
            let heartbeatData: [String: Any] = [
                "HeartRate": 60,
                "Timestamp": ServerValue.timestamp()
            ]
            ref.child("Userdata").child(uid).child("Heartbeat").child("Watch1").setValue(heartbeatData)
        }
    }
    
    // AcceptUser ノードの確認
    ref.child("AcceptUser").child(uid).observeSingleEvent(of: .value) { snapshot in
        if !snapshot.exists() {
            // AcceptUser ノードがない場合は作成
            let acceptUserData: [String: Any] = [
                "permittedUser": [:],
                "permissions": [:]
            ]
            ref.child("AcceptUser").child(uid).setValue(acceptUserData)
        }
    }
}


/// モダンな背景ビュー
struct ModernBackgroundView: View {
    // テーマカラー - Hear2getherブランドカラー
    private let primaryColor = Color(red: 0.95, green: 0.2, blue: 0.3)
    private let secondaryColor = Color(red: 0.85, green: 0.2, blue: 0.5)
    private let accentColor = Color(red: 0.7, green: 0.3, blue: 0.6)
    
    var body: some View {
        ZStack {
            // グラデーション背景
            LinearGradient(
                gradient: Gradient(colors: [
                    primaryColor,
                    secondaryColor,
                    accentColor
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 装飾的な要素：柔らかい円形の装飾
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 300, height: 300)
                .position(x: UIScreen.main.bounds.width * 0.8, y: UIScreen.main.bounds.height * 0.2)
                .blur(radius: 30)
            
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 250, height: 250)
                .position(x: UIScreen.main.bounds.width * 0.1, y: UIScreen.main.bounds.height * 0.8)
                .blur(radius: 30)
            
            // メッシュパターン
            GeometryReader { geometry in
                ForEach(0..<10) { row in
                    ForEach(0..<10) { column in
                        Circle()
                            .fill(Color.white.opacity(0.03))
                            .frame(width: 8, height: 8)
                            .position(
                                x: geometry.size.width / 10 * CGFloat(column),
                                y: geometry.size.height / 10 * CGFloat(row)
                            )
                    }
                }
            }
        }
    }
}

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showNext: Bool = false
    @State private var currentNonce: String?
    @State private var appleSignInDelegate: AppleSignInDelegate?
    
    // presentationProvider を保持するための State
    @State private var presentationProvider: ApplePresentationProvider?
    
    // Firebase Realtimeデータベース参照
    @State var ref: DatabaseReference! = Database.database().reference()
    
    // エラー表示用
    @State private var showAlert: Bool = false
    @State private var errorMessage: String = ""
    
    // アニメーション用
    @State private var contentOpacity: Double = 0
    @State private var iconOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.8
    
    // チュートリアル表示用 - 初期値を明示的に false に設定
    @State private var showTutorial: Bool = false
    
    // テーマカラー - Hear2getherブランドカラー
    private let primaryColor = Color(red: 0.95, green: 0.2, blue: 0.3)
    
    // 閉じるボタンの表示制御
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationStack {
            ZStack {
                // モダンな背景を表示
                ModernBackgroundView()
                
                VStack{
                    // アプリアイコン - 上部に配置
                    VStack {
                        // アイコン画像 - iPhone風の表示スタイル
                        Image("app_icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                            .padding(.top, 60)
                            .scaleEffect(iconScale)
                            .opacity(iconOpacity)
                            .onAppear {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    iconOpacity = 1
                                    iconScale = 1
                                }
                            }
                        
                        Spacer()
                    }
                    
                    // メインコンテンツ
                    VStack(spacing: 20) {
                        // タイトルとサブタイトル
                        VStack(spacing: 20) {
                            Text("Hear2gether にようこそ")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 1, y: 1)
                            
                            Text("心をつなぐアプリで、\n大切な人との絆を深めましょう。")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 1, y: 1)
                                .frame(height: 60)
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer()
                        
                        // ソーシャルログインボタン群
                        VStack(spacing: 16) {
                            // Googleログイン
                            Button(action: {
                                signInWithGoogle()
                            }) {
                                HStack {
                                    Text("G")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(Color.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                        .padding(.leading, 12)
                                    
                                    Text("Google を使用してログイン")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.trailing, 32)
                                }
                                .frame(height: 50)
                                .background(Color.white)
                                .cornerRadius(25)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            
                            // Appleログイン
                            Button(action: {
                                handleStyledAppleSignIn()
                            }) {
                                HStack {
                                    Image(systemName: "apple.logo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.white)
                                        .padding(.leading, 12)
                                    
                                    Text("Apple を使用してログイン")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.trailing, 32)
                                }
                                .frame(height: 50)
                                .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                                .cornerRadius(25)
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                            
                            // メールアドレスログイン
                            NavigationLink(destination: EmailLoginView()) {
                                Text("メールアドレスでログイン")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.top, 20)
                                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 1, y: 1)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                        
                        // プライバシーポリシー等の小さい文字
                        Text("続行することで、Hear2getherの利用規約と\nプライバシーポリシーに同意したことになります。")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 1, y: 1)
                            .frame(height: 100)
                        
                        Spacer()
                    }
                }
                .opacity(contentOpacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.6)) {
                        contentOpacity = 1
                    }
                }
            }
            // ログイン成功時の遷移先 - チュートリアル表示の修正
            .navigationDestination(isPresented: $showNext) {
                AppleWatchConnectionView()
                    .onAppear {
                        // チュートリアル表示状態をログに出力（デバッグ用）
                        print("AppleWatchConnectionView表示: チュートリアル表示状態 = \(showTutorial)")
                    }
                    .sheet(isPresented: $showTutorial) {
                        TutorialView()
                            .onDisappear {
                                // チュートリアル閉じたらフラグをリセット
                                showTutorial = false
                            }
                    }
            }
            // エラーアラート
            .alert("エラー", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Firebase Authentication 関連の関数
    
    /// 共通の認証結果処理関数 - 初期データ構造の設定を追加
    private func handleAuthResult(_ authResult: AuthDataResult?, _ error: Error?) {
        if let error = error {
            print("認証エラー: \(error.localizedDescription)")
            errorMessage = "認証エラー: \(error.localizedDescription)"
            showAlert = true
            return
        }
        
        if let user = authResult?.user {
            // 新規ユーザーかどうかを確認
            let isNewUser = authResult?.additionalUserInfo?.isNewUser ?? false
            
            // 新規ユーザーの場合はFirebaseデータ構造を初期化
            if isNewUser {
                // ユーザーのプロフィール情報を取得
                let displayName = user.displayName
                let profileImageURL = user.photoURL?.absoluteString
                
                // 初期データ構造を設定
                initializeUserDataStructure(
                    for: user,
                    isNewUser: true,
                    displayName: displayName,
                    profileImageURL: profileImageURL
                )
            } else {

                validateUserDataStructure(for: user)
            }
            
            // チュートリアル表示フラグを初期化
            showTutorial = false
            
            // UserDefaultsで初回ログインチェック
            let defaults = UserDefaults.standard
            let key = "hasLoggedInBefore_\(user.uid)"
            let hasLoggedInBefore = defaults.bool(forKey: key)
            
            if isNewUser || !hasLoggedInBefore {
                print("初回ログインユーザー: チュートリアルを表示します (UID: \(user.uid))")
                defaults.set(true, forKey: key)
                // 同期を強制
                defaults.synchronize()
                
                showTutorial = true
            } else {
                print("既存ユーザー: チュートリアルをスキップします (UID: \(user.uid))")
                showTutorial = false
            }
        }
        
        // 次の画面へ遷移
        DispatchQueue.main.async {
            self.showNext = true
        }
    }
    
    
    /// Googleサインイン処理 - 修正版
    private func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("Firebase の clientID が取得できません")
            return
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let rootViewController = UIApplication.shared.rootViewController() else {
            print("rootViewController が取得できません")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController, hint: nil, additionalScopes: []) { result, error in
            if let error = error {
                print("Googleサインインエラー: \(error.localizedDescription)")
                self.errorMessage = "Googleログイン失敗: \(error.localizedDescription)"
                self.showAlert = true
                return
            }
            
            guard let user = result?.user else {
                print("Googleサインイン: ユーザー情報の取得に失敗")
                self.errorMessage = "ユーザー情報を取得できませんでした"
                self.showAlert = true
                return
            }

            let idToken = user.idToken!.tokenString
            let accessToken = user.accessToken.tokenString

            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            Auth.auth().signIn(with: credential) { authResult, error in
                // 共通の認証結果処理関数を使用
                self.handleAuthResult(authResult, error)
                
                // 新規ユーザーの場合はプロフィール画像をアップロード
                if let authResult = authResult {
                    let user = authResult.user  // 単純な代入でOK
                        if authResult.additionalUserInfo?.isNewUser == true {
                            self.uploadDefaultImage(for: user.uid) { downloadURLString in
                                if let downloadURLString = downloadURLString {
                                    self.ref.child("Username").child(user.uid)
                                        .updateChildValues(["Uimage": downloadURLString])
                                }
                            }
                        }
                    }
            }
        }
    }
    
    /// カスタムスタイルのAppleサインイン処理 - 修正版
    private func handleStyledAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        
        // デリゲートをプロパティに保存して、メモリから解放されないようにする
        appleSignInDelegate = AppleSignInDelegate(onCompletion: { result in
            switch result {
            case .success(let authorization):
                if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                   let nonce = self.currentNonce,
                   let appleIDToken = appleIDCredential.identityToken,
                   let idTokenString = String(data: appleIDToken, encoding: .utf8) {
                    
                    let credential = OAuthProvider.credential(
                        providerID: .apple,
                        idToken: idTokenString,
                        rawNonce: nonce
                    )
                    
                    // Firebaseで認証する
                    Auth.auth().signIn(with: credential) { authResult, error in
                        // 共通の認証結果処理関数を使用
                        self.handleAuthResult(authResult, error)
                        
                        // プロフィール情報の更新は成功した場合のみ行う
                        if let authResult = authResult {
                            let user = authResult.user
                            // 新規ユーザーの場合はデフォルト画像をアップロード
                            if authResult.additionalUserInfo?.isNewUser == true {
                                self.uploadDefaultImage(for: user.uid) { downloadURLString in
                                    if let downloadURLString = downloadURLString {
                                        self.ref.child("Username").child(user.uid)
                                            .updateChildValues(["Uimage": downloadURLString])
                                        
                                        // ユーザープロファイル更新
                                        let changeRequest = user.createProfileChangeRequest()
                                        changeRequest.photoURL = URL(string: downloadURLString)
                                        changeRequest.commitChanges { error in
                                            if let error = error {
                                                print("プロファイル更新エラー: \(error.localizedDescription)")
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Appleから氏名情報を取得
                            if let fullName = appleIDCredential.fullName {
                                let displayName = "\(fullName.givenName ?? "") \(fullName.familyName ?? "")"
                                    .trimmingCharacters(in: .whitespaces)
                                if !displayName.isEmpty {
                                    let changeRequest = user.createProfileChangeRequest()
                                    changeRequest.displayName = displayName
                                    changeRequest.commitChanges { error in
                                        if let error = error {
                                            print("ユーザープロファイル更新エラー: \(error.localizedDescription)")
                                        } else {
                                            // Realtime DBに保存
                                            self.ref.child("Username").child(user.uid)
                                                .updateChildValues(["UName": displayName])
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    self.errorMessage = "Apple認証情報の取得に失敗しました"
                    self.showAlert = true
                }
            case .failure(let error):
                // より詳細なエラーメッセージを提供
                if let authError = error as? ASAuthorizationError {
                    switch authError.code {
                    case .canceled:
                        self.errorMessage = "認証がキャンセルされました"
                    case .failed:
                        self.errorMessage = "認証に失敗しました"
                    case .invalidResponse:
                        self.errorMessage = "無効な応答が返されました"
                    case .notHandled:
                        self.errorMessage = "認証リクエストが処理されませんでした"
                    case .unknown:
                        self.errorMessage = "不明なエラーが発生しました"
                    default:
                        self.errorMessage = error.localizedDescription
                    }
                } else {
                    self.errorMessage = error.localizedDescription
                }
                
                self.showAlert = true
            }
        })
        
        // presentationProviderを@Stateのプロパティに保存する
        if presentationProvider == nil {
            presentationProvider = ApplePresentationProvider()
        }
        controller.presentationContextProvider = presentationProvider
        
        controller.delegate = appleSignInDelegate
        controller.performRequests()
    }
    
    /// デフォルト画像アップロード関数
    func uploadDefaultImage(for uid: String, completion: @escaping (String?) -> Void) {
        guard let defaultImage = UIImage(named: "Default_icon") else {
            completion(nil)
            return
        }
        guard let imageData = defaultImage.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        
        let storageRef = Storage.storage().reference().child("profile_images/\(uid).jpg")
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("デフォルト画像アップロード失敗: \(error.localizedDescription)")
                completion(nil)
                return
            }
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("ダウンロードURL取得失敗: \(error.localizedDescription)")
                    completion(nil)
                } else if let downloadURL = url {
                    completion(downloadURL.absoluteString)
                } else {
                    completion(nil)
                }
            }
        }
    }
}

// 改良したメールログイン画面
struct EmailLoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showNext: Bool = false
    @State private var showTutorial: Bool = false // チュートリアル表示フラグを追加
    @Environment(\.dismiss) var dismiss
    
    // エラー表示用
    @State private var showAlert: Bool = false
    @State private var errorMessage: String = ""
    
    // 処理中フラグ
    @State private var isProcessing: Bool = false
    
    // テーマカラー
    private let primaryColor = Color(red: 0.95, green: 0.2, blue: 0.3)
    private let textColor = Color(red: 0.2, green: 0.2, blue: 0.2)
    
    // Firebase Realtimeデータベース参照 - 遅延初期化
    private var ref: DatabaseReference {
        return Database.database().reference()
    }
    
    var body: some View {
        ZStack {
            // 背景グラデーション - シンプル化して制約問題を回避
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.2, blue: 0.3),
                    Color(red: 0.85, green: 0.2, blue: 0.5),
                    Color(red: 0.7, green: 0.3, blue: 0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // メインコンテンツ - 固定配置でスクロールビューを回避
            VStack(spacing: 30) {
                // 戻るボタン
                HStack {
                    Button(action: {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.2))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                Text("メールアドレスでログイン")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                
                // メールアドレスフィールド
                VStack(alignment: .leading, spacing: 8) {
                    Text("メールアドレス")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    TextField("your.email@example.com", text: $email)
                        .font(.system(size: 16))
                        .foregroundColor(textColor)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white)
                        .cornerRadius(25)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress) // iOS自動入力サポート
                }
                .padding(.horizontal, 20)
                
                // パスワードフィールド
                VStack(alignment: .leading, spacing: 8) {
                    Text("パスワード")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    SecureField("パスワードを入力", text: $password)
                        .font(.system(size: 16))
                        .foregroundColor(textColor)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white)
                        .cornerRadius(25)
                        .textContentType(.password) // iOS自動入力サポート
                }
                .padding(.horizontal, 20)
                
                // パスワードリセットボタン - シンプル化
                Button(action: {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    if !email.isEmpty {
                        sendPasswordReset()
                    } else {
                        errorMessage = "パスワードリセットにはメールアドレスが必要です"
                        showAlert = true
                    }
                }) {
                    Text("パスワードをお忘れですか？")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                .padding(.top, 5)
                
                Spacer()
                
                // ログインボタン - 処理中インジケーター付き
                Button(action: {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    signInWithEmail()
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 10)
                        }
                        
                        Text("ログイン")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isProcessing ? primaryColor.opacity(0.7) : primaryColor)
                    .cornerRadius(25)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .disabled(isProcessing)
                .padding(.horizontal, 20)
                
                // 新規登録リンク
                HStack {
                    Text("アカウントをお持ちでない方は")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                    
                    NavigationLink(destination: RegistrationView()) {
                        Text("新規登録")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
        }
        // タップでキーボードを閉じる
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        // チュートリアル表示の修正
        .navigationDestination(isPresented: $showNext) {
            AppleWatchConnectionView()
                .onAppear {
                    print("EmailLoginView: チュートリアル表示状態 = \(showTutorial)")
                }
                .sheet(isPresented: $showTutorial) {
                    TutorialView()
                        .onDisappear {
                            showTutorial = false
                        }
                }
        }
        .alert(isShowingError ? "エラー" : "お知らせ", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    // エラーメッセージかどうかを判定
    private var isShowingError: Bool {
        return !errorMessage.contains("送信しました")
    }
    
    /// パスワードリセットメール送信
    private func sendPasswordReset() {
        guard !email.isEmpty else {
            errorMessage = "メールアドレスを入力してください"
            showAlert = true
            return
        }
        
        isProcessing = true
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            isProcessing = false
            
            if let error = error {
                errorMessage = "パスワードリセットメールの送信に失敗しました: \(error.localizedDescription)"
                showAlert = true
            } else {
                errorMessage = "パスワードリセットメールを送信しました。メールをご確認ください。"
                showAlert = true
            }
        }
    }
    
    /// メール/パスワード認証 - 修正版
    private func signInWithEmail() {
        // 入力バリデーション
        guard !email.isEmpty else {
            errorMessage = "メールアドレスを入力してください"
            showAlert = true
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "パスワードを入力してください"
            showAlert = true
            return
        }
        
        // メールフォーマット検証
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        guard emailPred.evaluate(with: email) else {
            errorMessage = "有効なメールアドレスを入力してください"
            showAlert = true
            return
        }
        
        // 処理中フラグをセット
        isProcessing = true
        
        // Firebase認証
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            // 処理中フラグをリセット
            isProcessing = false
            
            if let error = error {
                print("メールサインインエラー: \(error.localizedDescription)")
                
                // エラータイプに基づいたユーザーフレンドリーなメッセージ
                let errorCode = AuthErrorCode(_bridgedNSError: error as NSError)?.code
                switch errorCode {
                case .wrongPassword:
                    errorMessage = "パスワードが間違っています"
                case .userNotFound:
                    errorMessage = "このメールアドレスのアカウントが見つかりません"
                case .invalidEmail:
                    errorMessage = "無効なメールアドレスです"
                case .networkError:
                    errorMessage = "ネットワークエラーが発生しました。接続を確認してください。"
                default:
                    errorMessage = "ログインに失敗しました: \(error.localizedDescription)"
                }
                showAlert = true
                return
            }
            
            // EmailLoginViewのsignInWithEmailメソッド内の該当部分を修正
            if let authResult = authResult {
                let user = authResult.user
                
                // 新規ユーザーかどうかを確認
                let isNewUser = authResult.additionalUserInfo?.isNewUser ?? false

                // チュートリアル表示条件を確認
                // チュートリアル表示フラグを初期化
                showTutorial = false
                
                // UserDefaultsで初回ログインチェック
                let defaults = UserDefaults.standard
                let key = "hasLoggedInBefore_\(user.uid)"
                let hasLoggedInBefore = defaults.bool(forKey: key)
                
                if isNewUser || !hasLoggedInBefore {
                    print("メールログイン: 初回ユーザー: チュートリアルを表示します (UID: \(user.uid))")
                    defaults.set(true, forKey: key)
                    // 同期を強制
                    defaults.synchronize()
                    
                    showTutorial = true
                    
                    // 初期データ構造を設定 - initializeUserDataStructure関数を使用
                    initializeUserDataStructure(
                        for: user,
                        isNewUser: true,
                        displayName: user.displayName,
                        profileImageURL: user.photoURL?.absoluteString
                    )
                } else {
                    print("メールログイン: 既存ユーザー: チュートリアルをスキップします (UID: \(user.uid))")
                    showTutorial = false
                    
                    // 既存ユーザーの場合はデータ構造の整合性を確認（グローバル関数を使用）
                    validateUserDataStructure(for: user)
                }
            }
            // ログイン成功時に次画面へ遷移
            DispatchQueue.main.async {
                showNext = true
            }
        }
        
        // 認証リクエストのタイムアウト処理
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if isProcessing {
                isProcessing = false
                errorMessage = "接続がタイムアウトしました。インターネット接続を確認してください。"
                showAlert = true
            }
        }
    }
}

// チュートリアル画面
struct TutorialView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var currentPage = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $currentPage) {
                // ページ1
                ScrollView {
                    VStack {
                        Spacer()

                        Text("心拍数の確認")
                            .font(.largeTitle)
                            .bold()
                            .padding(.top)

                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 300)
                                .cornerRadius(12)
                            
                            Image(systemName: "heart.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.red)
                        }
                        .padding()

                        Text("このアプリでは心拍の記録を行います。\nあなたの心拍数を確認し、振動で感じることができます。")
                            .padding()

                        Spacer(minLength: 50)

                        Button(action: {
                            withAnimation {
                                currentPage = 1  // 次のページ
                            }
                        }) {
                            Text("次へ")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 50)
                    }
                    .frame(minHeight: UIScreen.main.bounds.height)
                }
                .tag(0)

                // ページ2
                ScrollView {
                    VStack {
                        Spacer()
                        
                        Text("QRコードで友達追加")
                            .font(.largeTitle)
                            .bold()
                            .padding(.top)

                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 300)
                                .cornerRadius(12)
                            
                            Image(systemName: "qrcode")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.blue)
                        }
                        .padding()

                        Text("QRコードをスキャンして友達を追加できます。\n追加した友達と心拍数を共有しましょう。")
                            .padding()

                        Spacer(minLength: 50)

                        Button(action: {
                            withAnimation {
                                currentPage = 2
                            }
                        }) {
                            Text("次へ")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 50)
                    }
                    .frame(minHeight: UIScreen.main.bounds.height)
                }
                .tag(1)

                // ページ3
                ScrollView {
                    VStack {
                        Spacer()

                        Text("振動の設定")
                            .font(.largeTitle)
                            .bold()
                            .padding(.top)

                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 300)
                                .cornerRadius(12)
                            
                            Image(systemName: "slider.horizontal.3")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.green)
                        }
                        .padding()

                        Text("心拍数は振動で感じることができます。\n振動の強さは設定メニューで調整できます。")
                            .padding()

                        Spacer(minLength: 50)

                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("始める")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 50)
                    }
                    .frame(minHeight: UIScreen.main.bounds.height)
                }
                .tag(2)
            }
            .tabViewStyle(PageTabViewStyle())
            .navigationBarItems(trailing: Button(action: {
                // 「スキップ」ボタンでチュートリアル終了
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("スキップ")
                    .foregroundColor(.blue)
            })
        }
    }
}



// MARK: - Appleサインイン用の nonce 生成と SHA256 ハッシュ関数
private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: Array<Character> =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
        let randoms: [UInt8] = (0 ..< 16).map { _ in
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess {
                fatalError("ランダム生成に失敗: OSStatus \(errorCode)")
            }
            return random
        }

        randoms.forEach { random in
            if remainingLength == 0 { return }
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }
    return result
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}

// MARK: - Apple Sign-In デリゲート（カスタムボタン用）
class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    var onCompletion: (Result<ASAuthorization, Error>) -> Void
    
    init(onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.onCompletion = onCompletion
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onCompletion(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onCompletion(.failure(error))
    }
}

// MARK: - Apple Sign-In プレゼンテーションプロバイダー
class ApplePresentationProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // 最新のAPI（iOS 15以降）を使用してウィンドウを取得
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}

// MARK: - UIApplication 拡張：rootViewController の取得
extension UIApplication {
    func rootViewController() -> UIViewController? {
        guard let windowScene = connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return nil }
        return window.rootViewController
    }
}

// Firebase Auth エラーコードの拡張
extension AuthErrorCode {
    var description: String {
        switch self {
        case .emailAlreadyInUse:
            return "このメールアドレスは既に使用されています"
        case .userNotFound:
            return "ユーザーが見つかりませんでした"
        case .userDisabled:
            return "このアカウントは無効になっています"
        case .invalidEmail, .invalidSender, .invalidRecipientEmail:
            return "メールアドレスの形式が正しくありません"
        case .networkError:
            return "ネットワークエラーが発生しました"
        case .weakPassword:
            return "パスワードが脆弱です。より強力なパスワードを設定してください"
        case .wrongPassword:
            return "パスワードが間違っています"
        default:
            return "不明なエラーが発生しました"
        }
    }
}

// MARK: - プレビュー
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
