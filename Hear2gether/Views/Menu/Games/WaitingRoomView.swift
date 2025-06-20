import SwiftUI
import FirebaseDatabase
import FirebaseAuth
import Kingfisher
import UIKit

struct WaitingRoomView: View {
    var gameType: GameType
    var selectedUser: String
    var userImageURL: String?
    var userUID: String
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var roomID: String = ""
    @State private var isWaiting: Bool = true
    @State private var otherUserJoined: Bool = false
    @State private var timeElapsed: Int = 0
    @State private var showCancelAlert: Bool = false
    @State private var animationScale: CGFloat = 1.0
    
    // 画面遷移用の状態変数
    @State private var navigateToTetris = false
    @State private var navigateToOthello = false
    @State private var navigateToCardGame = false
    @State private var navigateToHeartRate = false
    
    @State private var displayName: String = ""
    @State private var profileImageURL: String? = nil
    
    // Firebase の observer 用ハンドル
    @State private var usernameHandle: DatabaseHandle?
    @State private var heartRateHandle: DatabaseHandle?
    @State private var recordStartHandle: DatabaseHandle?
    @State private var roomStatusHandle: DatabaseHandle?
    
    // タイマー
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色を黒に設定
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 24) {
                    
                    Spacer()
                    
                    // 待機中の表示
                    VStack(spacing: 30) {
                        // ユーザープロフィール
                        HStack(spacing: 40) {
                            // 自分のプロフィール
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 80, height: 80)
                                    
                                    if let url = URL(string: profileImageURL ?? "") {
                                        KFImage(url)
                                            .placeholder {
                                                ProgressView()
                                                    .foregroundColor(.white)
                                            }
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 75, height: 75)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 2)
                                            )
                                    } else {
                                        Image(systemName: "person.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 35, height: 35)
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                Text(displayName.isEmpty ? "あなた" : displayName)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            // VS表示
                            Text("VS")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.5), radius: 10, x: 0, y: 0)
                            
                            // 相手のプロフィール
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 80, height: 80)
                                    
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
                                            .frame(width: 75, height: 75)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 2)
                                            )
                                    } else {
                                        Image(systemName: "person.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 35, height: 35)
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                Text(selectedUser)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // 待機アニメーション
                        VStack(spacing: 16) {
                            if isWaiting {
                                Text("\(selectedUser)の参加を待っています...")
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(10)
                                
                                
                                // 波紋エフェクト
                                ZStack {
                                    ForEach(0..<3) { i in
                                        Circle()
                                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                            .scaleEffect(animationScale + CGFloat(i) * 0.2)
                                            .opacity(1.0 - (animationScale - 1.0) - CGFloat(i) * 0.2)
                                            .animation(
                                                Animation.easeInOut(duration: 1.5)
                                                    .repeatForever(autoreverses: false)
                                                    .delay(0.3 * Double(i)),
                                                value: animationScale
                                            )
                                    }
                                    
         
                                }
                                .frame(width: 100, height: 200)
                                .onAppear {
                                    animationScale = 1.5
                                }
                                
                                Text("待機時間: \(formatTime(timeElapsed))")
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(.gray)
                                    .padding(.top, 8)
                            } else if otherUserJoined {
                                Text("ゲームを開始します！")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                                    .padding(.bottom, 20)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // キャンセルボタン
                    Button(action: {
                        showCancelAlert = true
                    }) {
                        Text("キャンセル")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color(hex: "333333"))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $navigateToTetris) {
                TetrisView(roomID: roomID, opponentName: selectedUser)
                    .environmentObject(authViewModel)
                    .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(isPresented: $navigateToOthello) {
                OthelloView(roomID: roomID, opponentName: selectedUser)
                    .environmentObject(authViewModel)
                    .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(isPresented: $navigateToCardGame) {
                CardGameView(roomID: roomID, opponentName: selectedUser)
                    .environmentObject(authViewModel)
                    .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(isPresented: $navigateToHeartRate) {
                HeartRateOnlyView(roomID: roomID, selectedUser: selectedUser, userUID: userUID)
                    .environmentObject(authViewModel)
                    .navigationBarBackButtonHidden(true)
            }
            .onAppear {
                // ユーザー情報の取得
                getUserInfo()
            }
            .onReceive(timer) { _ in
                if isWaiting {
                    timeElapsed += 1
                }
            }
            .alert("待機をキャンセルしますか？", isPresented: $showCancelAlert) {
                Button("いいえ", role: .cancel) {}
                Button("はい", role: .destructive) {
                    cleanupGameRoom()
                    dismiss()
                }
            }
            .onChange(of: otherUserJoined) {
                    // 相手が参加したらゲーム画面へ遷移する処理
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        navigateToGameScreen()
                    }
            }
            .onDisappear {
                // クリーンアップ
                removeObservers()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func getUserInfo() {
        guard let user = authViewModel.currentUser else { return }
        let uid = user.uid
        let ref = Database.database().reference()
        
        // ユーザー情報の監視
        usernameHandle = ref.child("Username").child(uid)
            .observe(.value) { snapshot in
                if let dict = snapshot.value as? [String: Any] {
                    self.displayName = dict["UName"] as? String ?? ""
                    self.profileImageURL = dict["Uimage"] as? String
                    
                    // ユーザー情報取得後にルームを作成または確認
                    self.createOrJoinGameRoom()
                }
            }
    }
    
    private func createOrJoinGameRoom() {
        guard let currentUser = authViewModel.currentUser else { return }
        let currentUID = currentUser.uid
        
        // 常にUIDを使用する
        let myUID = currentUID
        let theirUID = userUID

        // 両方のパターンのルームID
        let roomID1 = "\(myUID)_\(theirUID)"
        let roomID2 = "\(theirUID)_\(myUID)"
        
        let ref = Database.database().reference()
        
        // 既存のルームを確認
        checkExistingRoom(ref: ref, possibleRoomIDs: [roomID1, roomID2]) { existingRoomID in
            if let existingRoomID = existingRoomID {
                // 既存のルームがある場合は、そのルームIDを使用
                self.roomID = existingRoomID
                print("既存のルームを使用: \(self.roomID)")
                
                // ここで gameType を更新
                ref.child("GameRooms").child(self.roomID).updateChildValues(["gameType": gameType.rawValue])
                
                // ルームのステータスを確認
                ref.child("GameRooms").child(self.roomID).observeSingleEvent(of: .value) { snapshot in
                    if let roomData = snapshot.value as? [String: Any] {
                        let status = roomData["status"] as? String ?? ""
                        
                        // ステータスに応じた処理
                        if status == "cancelled" {
                            // 作成者が再入室した場合は待機状態に戻す
                            ref.child("GameRooms").child(self.roomID).child("status").setValue("waiting")
                            ref.child("GameRooms").child(self.roomID).child("updatedAt").setValue(Int(Date().timeIntervalSince1970))
                            self.setupRoomStatusObserver()
                            self.sendGameInvitation()
                            
                        } else if status == "waiting" {
                            // 招待された側が入室した場合
                            ref.child("GameRooms").child(self.roomID).child("status").setValue("ready")
                            ref.child("GameRooms").child(self.roomID).child("updatedAt").setValue(Int(Date().timeIntervalSince1970))
                            
                            // 相手が入室したことを自分自身に通知
                            DispatchQueue.main.async {
                                self.isWaiting = false
                                self.otherUserJoined = true
                            }
                        } else if status == "ready" {
                            // 既にreadyの場合（相手が先に入室している）
                            DispatchQueue.main.async {
                                self.isWaiting = false
                                self.otherUserJoined = true
                            }
                        }
                    }
                }
            } else {
                // 既存のルームがない場合は新規作成（一貫性のためにmyName_theirNameの形式を使用）
                self.roomID = roomID1
                
                // ゲームルームデータを作成
                let roomData: [String: Any] = [
                    "creatorUID": currentUID,
                    "creatorName": displayName.isEmpty ? "Unknown" : displayName,
                    "invitedUID": userUID,
                    "invitedName": selectedUser,
                    "gameType": gameType.rawValue,
                    "status": "waiting",
                    "updatedAt": Int(Date().timeIntervalSince1970)
                ]
                
                // Firebaseにルームを上書き
                ref.child("GameRooms").child(self.roomID).setValue(roomData) { error, _ in
                    if let error = error {
                        print("ゲームルーム作成エラー: \(error.localizedDescription)")
                    } else {
                        print("ゲームルーム作成完了: \(self.roomID)")
                        
                        // ルームステータスの監視を設定
                        self.setupRoomStatusObserver()
                        
                        // 招待されたユーザーに通知を送る
                        self.sendGameInvitation()
                    }
                }
            }
        }
    }
    
    // 既存のルームをチェックする関数
    private func checkExistingRoom(ref: DatabaseReference, possibleRoomIDs: [String], completion: @escaping (String?) -> Void) {
        var checkedCount = 0
        var foundRoomID: String? = nil
        
        for roomID in possibleRoomIDs {
            ref.child("GameRooms").child(roomID).observeSingleEvent(of: .value) { snapshot in
                checkedCount += 1
                
                if snapshot.exists() {
                    foundRoomID = roomID
                }
                
                // すべてのルームをチェックした後に結果を返す
                if checkedCount == possibleRoomIDs.count {
                    completion(foundRoomID)
                }
            }
        }
    }
    
    private func sendGameInvitation() {
        guard let currentUser = authViewModel.currentUser else { return }
        
        let ref = Database.database().reference()
        let notification = [
            "type": "gameInvitation",
            "senderUID": currentUser.uid,
            "senderName": displayName.isEmpty ? "不明なユーザー" : displayName,
            "gameType": gameType.rawValue,
            "roomID": roomID,
            "timestamp": Int(Date().timeIntervalSince1970)
        ] as [String : Any]
        
        // 通知を相手のユーザーに送る
        ref.child("Notifications").child(userUID).childByAutoId().setValue(notification)
    }
    
    private func setupRoomStatusObserver() {
        if roomID.isEmpty { return }
        
        let ref = Database.database().reference()
        
        // 既存のオブザーバーを削除
        if let handle = roomStatusHandle {
            ref.child("GameRooms").child(roomID).child("status").removeObserver(withHandle: handle)
        }
        
        // ルームステータスの変更を監視
        roomStatusHandle = ref.child("GameRooms").child(roomID).child("status").observe(.value) { snapshot in
            if let status = snapshot.value as? String {
                print("ルームステータス変更: \(status)")
                
                if status == "ready" {
                    // 相手が参加した
                    DispatchQueue.main.async {
                        print("相手が参加しました。otherUserJoined を true に設定します")
                        self.isWaiting = false
                        self.otherUserJoined = true
                        print("otherUserJoined: \(self.otherUserJoined)")
                    }
                } else if status == "cancelled" {
                    // 相手がキャンセルした
                    DispatchQueue.main.async {
                        self.showCancelledAlert()
                    }
                }
            }
        }
    }
    
    private func showCancelledAlert() {
        // すでに処理中の場合はアラートを表示しない
        if !isWaiting && !otherUserJoined {
            return
        }
        
        // 待機状態をリセット
        isWaiting = false
        otherUserJoined = false
        
        // キャンセルアラートを表示
        let alert = UIAlertController(
            title: "ゲームがキャンセルされました",
            message: "相手がゲームをキャンセルしました。メイン画面に戻ります。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            // メイン画面に戻る
            dismiss()
        })
        
        // アラートを表示
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    private func cleanupGameRoom() {
        if roomID.isEmpty { return }
        
        // ゲームルームのステータスを "cancelled" に更新
        let ref = Database.database().reference()
        ref.child("GameRooms").child(roomID).child("status").setValue("cancelled")
    }
    
    private func removeObservers() {
        let ref = Database.database().reference()
        
        if let handle = usernameHandle {
            ref.child("Username").removeObserver(withHandle: handle)
        }
        
        if let handle = heartRateHandle {
            ref.removeObserver(withHandle: handle)
        }
        
        if let handle = recordStartHandle {
            ref.removeObserver(withHandle: handle)
        }
        
        if let handle = roomStatusHandle {
            ref.child("GameRooms").child(roomID).child("status").removeObserver(withHandle: handle)
        }
    }
    
    private func navigateToGameScreen() {
        print("navigateToGameScreen が呼び出されました。ゲームタイプ: \(gameType.rawValue)")
        // ゲームタイプに応じて適切な遷移フラグを設定
        switch gameType {
        case .tetris:
            navigateToTetris = true
        case .othello:
            navigateToOthello = true
        case .cardGame:
            navigateToCardGame = true
        case .heartRate:
            navigateToHeartRate = true
        }
    }
}

// MARK: - Game Type Enum
enum GameType: String {
    case tetris = "テトリス"
    case othello = "オセロ"
    case cardGame = "トランプ"
    case heartRate = "心拍表示"
    
    var title: String {
        switch self {
        case .tetris:
            return "テトリス"
        case .othello:
            return "オセロ"
        case .cardGame:
            return "トランプ"
        case .heartRate:
            return "心拍表示"
        }
    }
}


struct WaitingRoomView_Previews: PreviewProvider {
    static var previews: some View {
        WaitingRoomView(
            gameType: .tetris,
            selectedUser: "Alice",
            userImageURL: "https://test-dff46-default-rtdb.firebaseio.com/Username/6YaJ3UEyp5SVUOch1DYdNobQAFD2/Uimage",
            userUID: "friendUID123"
        )
        .environmentObject(AuthViewModel())
    }
}
