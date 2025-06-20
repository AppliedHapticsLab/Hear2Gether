import SwiftUI
import FirebaseAuth
import FirebaseDatabase
import FirebaseStorage

// 新規登録画面 - モダンデザイン適用
struct RegistrationView: View {
    @Environment(\.dismiss) var dismiss
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String = ""
    @State private var showErrorAlert: Bool = false
    @State private var showSuccessAlert: Bool = false
    
    // 画像選択関連
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker: Bool = false
    @State private var isUploading: Bool = false
    
    // アニメーション用
    @State private var contentOpacity: Double = 0
    
    // テーマカラー
    private let primaryColor = Color(red: 0.95, green: 0.2, blue: 0.3)
    
    var body: some View {
        ZStack {
            // モダンな背景
            ModernBackgroundView()
            
            // スクロール可能なコンテンツ
            ScrollView {
                VStack(spacing: 20) {
                    // 戻るボタンとタイトル
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        Text("アカウント作成")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // バランスを取るための透明な要素
                        Circle()
                            .frame(width: 36, height: 36)
                            .opacity(0)
                            .padding(.trailing, 20)
                    }
                    .padding(.top, 20)
                    
                    // アイコンとメッセージ
                    VStack(spacing: 15) {
                        // プロフィール画像選択ボタン
                        Button(action: {
                            showImagePicker = true
                        }) {
                            ZStack {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 3)
                                        )
                                        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                                } else {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            VStack {
                                                Image(systemName: "person.crop.circle.fill.badge.plus")
                                                    .font(.system(size: 40))
                                                    .foregroundColor(.white)
                                                
                                                Text("画像を選択")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                                    .padding(.top, 5)
                                            }
                                        )
                                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                                }
                            }
                        }
                        .sheet(isPresented: $showImagePicker) {
                            ImagePicker(image: $selectedImage, didFinishPicking: {
                                showImagePicker = false
                            })
                        }
                        
                        Text("Hear2getherへようこそ！")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("アカウントを作成して、心拍数を\n共有できる仲間とつながりましょう")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 20)
                    .opacity(contentOpacity)
                    
                    // 入力フォーム
                    VStack(spacing: 20) {
                        // ユーザー名
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ユーザー名")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 24)
                                
                                TextField("あなたの表示名", text: $username)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(25)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // メールアドレス
                        VStack(alignment: .leading, spacing: 8) {
                            Text("メールアドレス")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 24)
                                
                                TextField("your.email@example.com", text: $email)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(25)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .disableAutocorrection(true)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // パスワード
                        VStack(alignment: .leading, spacing: 8) {
                            Text("パスワード")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 24)
                                
                                SecureField("8文字以上の英数字", text: $password)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(25)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // パスワード(確認用)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("パスワード（確認用）")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 24)
                                
                                SecureField("同じパスワードを入力", text: $confirmPassword)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(25)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // 登録ボタン
                        Button(action: {
                            registerUser()
                        }) {
                            if isUploading {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("登録中...")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(primaryColor.opacity(0.7))
                                .cornerRadius(25)
                            } else {
                                Text("アカウントを作成")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(primaryColor)
                                    .cornerRadius(25)
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                        }
                        .disabled(isUploading)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // 利用規約
                        Text("アカウントを作成すると、Hear2getherの利用規約と\nプライバシーポリシーに同意したことになります。")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 10)
                        
                        // ログインへのリンク
                        HStack {
                            Text("すでにアカウントをお持ちですか？")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Button(action: {
                                dismiss()
                            }) {
                                Text("ログイン")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                    .opacity(contentOpacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 0.6)) {
                            contentOpacity = 1
                        }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("エラー", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("成功", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("アカウントの登録が完了しました。ログイン画面からログインしてください。")
        }
    }
    
    // RegistrationView.swift の registerUser メソッドの更新部分

    private func registerUser() {
        // 入力内容の簡単なバリデーション
        guard !username.isEmpty else {
            errorMessage = "ユーザー名を入力してください。"
            showErrorAlert = true
            return
        }
        
        guard !email.isEmpty else {
            errorMessage = "メールアドレスを入力してください。"
            showErrorAlert = true
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "パスワードを入力してください。"
            showErrorAlert = true
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "パスワードが一致しません。"
            showErrorAlert = true
            return
        }
        
        // アップロード中の状態を設定
        isUploading = true
        
        // Firebase の新規登録処理
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                isUploading = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
                return
            }
            
            // 登録成功時
            if let user = result?.user {
                let uid = user.uid
                
                // ユーザープロフィールの更新
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = username
                changeRequest.commitChanges { error in
                    if let error = error {
                        print("プロファイル更新エラー: \(error.localizedDescription)")
                    }
                }
                
                // プロフィール画像のアップロード処理
                if let selectedImage = selectedImage {
                    // 画像をアップロード
                    self.uploadProfileImage(image: selectedImage, uid: uid) { imageURL in
                        // Firebase初期データ構造の作成（画像URLを含む）
                        if let imageURL = imageURL {
                            // Firebase初期データ構造の設定（画像URLあり）
                            initializeUserDataStructure(
                                for: user,
                                isNewUser: true,
                                displayName: username,
                                profileImageURL: imageURL
                            )
                            
                            // Firebase Authのプロファイル更新
                            let changeRequest = user.createProfileChangeRequest()
                            changeRequest.photoURL = URL(string:imageURL)
                            changeRequest.commitChanges { error in
                                if let error = error {
                                    print("写真URL更新エラー: \(error.localizedDescription)")
                                }
                            }
                        } else {
                            // Firebase初期データ構造の設定（画像URLなし）
                            initializeUserDataStructure(
                                for: user,
                                isNewUser: true,
                                displayName: username,
                                profileImageURL: nil
                            )
                        }
                        
                        DispatchQueue.main.async {
                            self.isUploading = false
                            self.showSuccessAlert = true
                        }
                    }
                } else {
                    // 画像なしでFirebase初期データ構造の設定
                    initializeUserDataStructure(
                        for: user,
                        isNewUser: true,
                        displayName: username,
                        profileImageURL: nil
                    )
                    
                    DispatchQueue.main.async {
                        self.isUploading = false
                        self.showSuccessAlert = true
                    }
                }
            }
        }
    }
    
    // プロフィール画像をFirebase Storageにアップロード
    private func uploadProfileImage(image: UIImage, uid: String, completion: @escaping (String?) -> Void) {
        guard image.jpegData(compressionQuality: 0.8) != nil else {
            completion(nil)
            return
        }
        
        // まず画像を正方形にクロップ
        let croppedImage = cropToSquare(image: image)
        guard let croppedData = croppedImage.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        
        let storageRef = Storage.storage().reference().child("profile_images/\(uid).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        storageRef.putData(croppedData, metadata: metadata) { _, error in
            if let error = error {
                print("画像アップロードエラー: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("ダウンロードURL取得エラー: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                if let downloadURL = url {
                    completion(downloadURL.absoluteString)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    // 画像を正方形にクロップする関数
    private func cropToSquare(image: UIImage) -> UIImage {
        let originalWidth = image.size.width
        let originalHeight = image.size.height
        let squareLength = min(originalWidth, originalHeight)
        let x = (originalWidth - squareLength) / 2.0
        let y = (originalHeight - squareLength) / 2.0
        let cropRect = CGRect(x: x, y: y, width: squareLength, height: squareLength)
        
        if let cgImage = image.cgImage,
           let croppedCGImage = cgImage.cropping(to: cropRect) {
            return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        }
        return image
    }
}


struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        RegistrationView()
    }
}
