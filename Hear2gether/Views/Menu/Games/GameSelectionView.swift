import SwiftUI
import FirebaseAuth
import FirebaseDatabase
import Kingfisher

struct GameSelectionView: View {
    var selectedUser: String
    var userImageURL: String?  // ユーザー画像のURL
    var userUID: String        // 選択された友達のUID

    // グリッド用の2カラム設定
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    // ログイン中のユーザー情報は環境オブジェクトから取得
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // Apple Watch への転送が完了しているかの状態
    @State private var isTransfered: Bool = false
    @State private var showTransferAnimation: Bool = false
    
    // 待機画面への遷移用の状態
    @State private var selectedGame: GameType?
    @State private var showWaitingRoom: Bool = false
    
    // 未実装機能のアラート表示用
    @State private var showUnimplementedAlert: Bool = false
    @State private var unimplementedFeatureName: String = ""
    
    // 実装済みのゲーム
    private let implementedGames: [GameType] = [.heartRate, .tetris]

    var body: some View {
        ZStack {
            // 背景色を黒に設定
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                Spacer()
                // ユーザープロフィールセクション
                VStack(spacing: 16) {
                    // プロフィール画像
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 130, height: 130)
                        
                        if let imageURL = userImageURL,
                           let url = URL(string: imageURL),
                           !imageURL.isEmpty {
                            KFImage(url)
                                .placeholder {
                                    ProgressView()
                                        .foregroundColor(.white)
                                }
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        } else {
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.white)
                        }
                    }
                    .shadow(color: Color.white.opacity(0.2), radius: 10, x: 0, y: 0)
                    
                    // ユーザー名
                    Text(selectedUser)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.top, 20)
                
                /*
                // Apple Watch に転送ボタン
                Button(action: {
                    withAnimation {
                        showTransferAnimation = true
                    }
                    transferToAppleWatch()
                }) {
                    HStack {
                        Image(systemName: "applewatch")
                            .font(.system(size: 22, weight: .semibold))
                        
                        Text("Apple Watchに転送")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .padding(.leading, 4)
                    }
                    .foregroundColor(.black)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(
                        isTransfered ?
                            LinearGradient(gradient: Gradient(colors: [Color.gray, Color.gray.opacity(0.7)]), startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(gradient: Gradient(colors: [Color.white, Color.gray.opacity(0.7)]), startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(25)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: Color.white.opacity(0.2), radius: 5, x: 0, y: 0)
                }
                .disabled(isTransfered)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
                .overlay(
                    Group {
                        if showTransferAnimation && !isTransfered {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 10, height: 10)
                                .scaleEffect(showTransferAnimation ? 20 : 1)
                                .opacity(showTransferAnimation ? 0 : 1)
                                .animation(
                                    Animation.easeOut(duration: 1.0)
                                        .repeatCount(1, autoreverses: false)
                                        .delay(0.2),
                                    value: showTransferAnimation
                                )
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                                        showTransferAnimation = false
                                    }
                                }
                        }
                    }
                )
                
                 */
                // ゲーム選択セクションタイトル
                    Text("ゲーム選択")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 20)
                        .padding(.bottom, 5)
                
                // ゲーム選択グリッド - 未実装のゲームを無効化
                LazyVGrid(columns: columns, spacing: 20) {
                    Button(action: {
                        // ブロックパズル（実装済み）
                        selectedGame = .tetris
                        showWaitingRoom = true
                    }) {
                        GameButtonView(
                            iconName: "puzzlepiece.fill",
                            title: "ブロックパズル",
                            isImplemented: true
                        )
                    }
                    
                    Button(action: {
                        // ディスクゲーム（未実装）
                        unimplementedFeatureName = "ディスクゲーム"
                        showUnimplementedAlert = true
                    }) {
                        GameButtonView(
                            iconName: "circle.grid.cross.fill",
                            title: "ディスクゲーム",
                            isImplemented: false
                        )
                    }
                    .disabled(true)
                    
                    Button(action: {
                        // カードゲーム（未実装）
                        unimplementedFeatureName = "カードゲーム"
                        showUnimplementedAlert = true
                    }) {
                        GameButtonView(
                            iconName: "suit.club.fill",
                            title: "カードゲーム",
                            isImplemented: false
                        )
                    }
                    .disabled(true)
                    
                    Button(action: {
                        // 心拍表示（実装済み）
                        selectedGame = .heartRate
                        showWaitingRoom = true
                    }) {
                        GameButtonView(
                            iconName: "heart.fill",
                            title: "心拍表示",
                            isImplemented: true
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationDestination(isPresented: $showWaitingRoom) {
                if let gameType = selectedGame {
                    WaitingRoomView(
                        gameType: gameType,
                        selectedUser: selectedUser,
                        userImageURL: userImageURL,
                        userUID: userUID
                    )
                }
            }
        }
        .onAppear {
            checkIfTransferred()
        }
        .alert(isPresented: $showUnimplementedAlert) {
            Alert(
                title: Text("開発中の機能"),
                message: Text("\(unimplementedFeatureName)は現在開発中です。もうしばらくお待ちください。"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - 転送処理
    private func transferToAppleWatch() {
        guard let currentUser = authViewModel.currentUser else { return }
        let currentUID = currentUser.uid
        let ref = Database.database().reference()
        
        // 自身の "SelectUser" に友達のUIDを書き込み
        ref.child("Userdata").child(currentUID)
            .child("MyPreference").child("Vibration").child("SelectUser")
            .setValue(userUID) { error, _ in
                if let error = error {
                    print("SelectUser 更新エラー: \(error.localizedDescription)")
                } else {
                    // 続いて "SelectUserName" に友達の名前を書き込み
                    ref.child("Userdata").child(currentUID)
                        .child("MyPreference").child("Vibration").child("SelectUserName")
                        .setValue(selectedUser) { error, _ in
                            if let error = error {
                                print("SelectUserName 更新エラー: \(error.localizedDescription)")
                            } else {
                                print("Apple Watch 転送完了")
                                DispatchQueue.main.async {
                                    isTransfered = true
                                }
                            }
                        }
                }
            }
    }
    
    // MARK: - 転送状態の確認
    private func checkIfTransferred() {
        guard let currentUser = authViewModel.currentUser else { return }
        let currentUID = currentUser.uid
        let ref = Database.database().reference()
        ref.child("Userdata").child(currentUID)
            .child("MyPreference").child("Vibration").child("SelectUser")
            .observeSingleEvent(of: .value) { snapshot in
                if let value = snapshot.value as? String, value == userUID {
                    DispatchQueue.main.async {
                        isTransfered = true
                    }
                }
            }
    }
}

struct GameButtonView: View {
    var iconName: String
    var title: String
    var isImplemented: Bool = true
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: iconName)
                .resizable()
                .scaledToFit()
                .frame(height: 40)
                .foregroundColor(isImplemented ? .white : .gray.opacity(0.6))
                .padding(.top, 16)
            
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(isImplemented ? .white : .gray.opacity(0.6))
                .padding(.bottom, isImplemented ? 16 : 4)
            
            // 未実装の場合は「開発中」の表示を追加
            if !isImplemented {
                Text("開発中")
                    .font(.system(size: 12))
                    .foregroundColor(Color.red.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
                    .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: isImplemented
                                          ? [Color("333333"), Color("222222")]
                                          : [Color("222222").opacity(0.7), Color("111111").opacity(0.7)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isImplemented ? Color.white.opacity(0.1) : Color.gray.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: isImplemented ? Color.white.opacity(0.1) : Color.clear, radius: 5, x: 0, y: 2)
        .opacity(isImplemented ? 1.0 : 0.8)
    }
}

struct GameSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            GameSelectionView(selectedUser: "Alice",
                              userImageURL: "https://test-dff46-default-rtdb.firebaseio.com/Username/6YaJ3UEyp5SVUOch1DYdNobQAFD2/Uimage",
                              userUID: "friendUID123")
                .environmentObject(AuthViewModel())
        }
    }
}
