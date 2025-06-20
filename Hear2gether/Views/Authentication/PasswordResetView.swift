import SwiftUI
import FirebaseAuth

// パスワードリセット画面 - モダンデザイン適用
struct PasswordResetView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email: String = ""
    @State private var errorMessage: String = ""
    @State private var showErrorAlert: Bool = false
    @State private var showSuccessAlert: Bool = false
    
    // アニメーション用
    @State private var contentOpacity: Double = 0
    
    // テーマカラー
    private let primaryColor = Color(red: 0.95, green: 0.2, blue: 0.3)
    
    var body: some View {
        ZStack {
            // モダンな背景
            ModernBackgroundView()
            
            VStack(spacing: 25) {
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
                    
                    Text("パスワード再設定")
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
                
                Spacer()
                
                // アイコンとメッセージ
                VStack(spacing: 20) {
                    // アイコン
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "key.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                    
                    Text("パスワードをリセット")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("登録したメールアドレスにパスワード\n再設定用のリンクを送信します")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .opacity(contentOpacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.6)) {
                        contentOpacity = 1
                    }
                }
                
                Spacer()
                
                // メールフォームとボタン
                VStack(spacing: 25) {
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
                    
                    Button(action: {
                        sendPasswordReset()
                    }) {
                        Text("リセットメールを送信")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(primaryColor)
                            .cornerRadius(25)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // ヘルプテキスト
                    HStack {
                        Text("ログイン画面に戻る")
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
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
                .opacity(contentOpacity)
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
            Text("パスワードリセット用のメールを送信しました。メールをご確認ください。")
        }
    }
    
    private func sendPasswordReset() {
        guard !email.isEmpty else {
            errorMessage = "メールアドレスを入力してください。"
            showErrorAlert = true
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            } else {
                showSuccessAlert = true
            }
        }
    }
}


struct PasswordResetView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordResetView()
    }
}
