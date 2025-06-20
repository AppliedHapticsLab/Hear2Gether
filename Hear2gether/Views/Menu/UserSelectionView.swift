import SwiftUI
import FirebaseAuth
import FirebaseDatabase
import Kingfisher
import AVFoundation

// MARK: - データモデル
struct PermittedUser: Identifiable, Equatable {
    let id: String
    var name: String = "Loading"
    var imageURL: String = ""
    var heartRate: Int = 0
    var isSelected: Bool = false  // 削除用選択状態
}

struct DummySharedData {
    var Userid: String = "dummyUser123"
    var PermittedUser: [String] = []      // 既に許可済みのユーザーID配列
    var scannedCode: [String?] = []       // スキャン済みのQRコード文字列の配列
}

// MARK: - UserSelectionView
struct UserSelectionView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    // 許可されているユーザーの情報
    @State private var permittedUsers: [PermittedUser] = []
    
    // Firebase observer 用ハンドル
    @State private var permittedUsersHandle: DatabaseHandle?
    // 各ユーザーの Username ノード監視ハンドル（キー：ユーザーID）
    @State private var userInfoHandles: [String: DatabaseHandle] = [:]
    // 各ユーザーの HeartRate ノード監視ハンドル（キー：ユーザーID）
    @State private var heartRateHandles: [String: DatabaseHandle] = [:]
    
    // 検索用テキスト
    @State private var searchText: String = ""
    // QRコード画面表示用フラグ
    @State private var isShowingQRScreen = false
    // 削除モード状態
    @State private var isDeleteMode = false
    // 削除確認用のアラートフラグ
    @State private var showDeleteConfirmation = false
    
    // フィルタ済みかつ名前順（アルファベット順）にソートされたユーザー配列
    var filteredUsers: [PermittedUser] {
        let filtered = searchText.isEmpty ? permittedUsers : permittedUsers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    // 選択されたユーザー数
    var selectedUserCount: Int {
        return permittedUsers.filter { $0.isSelected }.count
    }
    
    var body: some View {
        ZStack {
            // 背景色
            ColorManager.backgroundColor
                .ignoresSafeArea()
            
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
                            
                            Text("友達リスト")
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
                
                // 検索欄とQRコードスキャン/削除モードボタン
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ColorManager.subtleTextColor)
                        .padding(.leading, 12)
                    
                    TextField("ユーザー名検索", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(ColorManager.textColor)
                        .disabled(isDeleteMode) // 削除モード中は検索を無効化
                    
                    if isDeleteMode {
                        // 削除モード終了ボタン
                        Button(action: {
                            withAnimation {
                                isDeleteMode = false
                                // 選択状態をリセット
                                for i in 0..<permittedUsers.count {
                                    permittedUsers[i].isSelected = false
                                }
                            }
                        }) {
                            Text("キャンセル")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ColorManager.subtleTextColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(ColorManager.cardColor))
                        }
                    } else {
                        // 削除モード開始ボタン
                        Button(action: {
                            withAnimation {
                                isDeleteMode = true
                            }
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.title3)
                                .foregroundColor(Color.red.opacity(0.8))
                                .padding(8)
                                .background(Circle().fill(ColorManager.cardColor))
                        }
                        
                        // QRコードスキャンボタン
                        Button(action: {
                            isShowingQRScreen = true
                        }) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title3)
                                .foregroundColor(ColorManager.primaryColor)
                                .padding(8)
                                .background(Circle().fill(ColorManager.cardColor))
                        }
                    }
                }
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(ColorManager.cardColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ColorManager.subtleTextColor.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 25)
                .sheet(isPresented: $isShowingQRScreen) {
                    QRCodeView()
                        .environmentObject(authViewModel)
                }
                
                Spacer().frame(height: 20)
                
                // 削除モード時の選択状態表示とアクションボタン
                if isDeleteMode && !permittedUsers.isEmpty {
                    HStack {
                        Text("\(selectedUserCount)人選択中")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ColorManager.textColor)
                        
                        Spacer()
                        
                        Button(action: {
                            if selectedUserCount > 0 {
                                showDeleteConfirmation = true
                            }
                        }) {
                            Text("削除")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedUserCount > 0 ? Color.red : Color.gray)
                                )
                        }
                        .disabled(selectedUserCount == 0)
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 10)
                }
                
                if permittedUsers.isEmpty {
                    // ユーザーがいない場合の表示
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 60))
                            .foregroundColor(ColorManager.subtleTextColor.opacity(0.6))
                        
                        Text("まだ友達がいません")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(ColorManager.subtleTextColor)
                        
                        Text("QRコードをスキャンして友達を追加しましょう")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(ColorManager.subtleTextColor.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            isShowingQRScreen = true
                        }) {
                            HStack {
                                Image(systemName: "qrcode.viewfinder")
                                Text("QRコードスキャン")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ColorManager.backgroundColor)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ColorManager.primaryColor)
                            )
                        }
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                    .padding(.bottom, 100) // タブバー用余白
                } else {
                    // 許可ユーザーの一覧表示
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredUsers.indices, id: \.self) { index in
                                let user = filteredUsers[index]
                                // 削除モードと通常モードで異なるビュー
                                if isDeleteMode {
                                    // 削除モード時のユーザー行
                                    Button(action: {
                                        // ユーザーの選択状態を切り替え
                                        if let originalIndex = permittedUsers.firstIndex(where: { $0.id == user.id }) {
                                            permittedUsers[originalIndex].isSelected.toggle()
                                        }
                                    }) {
                                        HStack(spacing: 15) {
                                            // 選択チェックマーク
                                            ZStack {
                                                Circle()
                                                    .stroke(user.isSelected ? ColorManager.primaryColor : ColorManager.subtleTextColor.opacity(0.3), lineWidth: 2)
                                                    .frame(width: 24, height: 24)
                                                
                                                if user.isSelected {
                                                    Circle()
                                                        .fill(ColorManager.primaryColor)
                                                        .frame(width: 16, height: 16)
                                                }
                                            }
                                            
                                            // プロフィール画像
                                            if let url = URL(string: user.imageURL), !user.imageURL.isEmpty {
                                                KFImage(url)
                                                    .placeholder {
                                                        Circle()
                                                            .fill(ColorManager.cardColor)
                                                            .overlay(
                                                                ProgressView()
                                                                    .progressViewStyle(CircularProgressViewStyle(tint: ColorManager.subtleTextColor))
                                                            )
                                                    }
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 50, height: 50)
                                                    .clipShape(Circle())
                                                    .overlay(
                                                        Circle()
                                                            .stroke(ColorManager.subtleTextColor.opacity(0.3), lineWidth: 1)
                                                    )
                                            } else {
                                                Circle()
                                                    .fill(ColorManager.cardColor)
                                                    .frame(width: 50, height: 50)
                                                    .overlay(
                                                        Image(systemName: "person.fill")
                                                            .foregroundColor(ColorManager.subtleTextColor)
                                                    )
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(user.name)
                                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                                    .foregroundColor(ColorManager.textColor)
                                                
                                                HStack(spacing: 5) {
                                                    Image(systemName: "heart.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(ColorManager.primaryColor)
                                                    
                                                    Text("\(user.heartRate) BPM")
                                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                                        .foregroundColor(ColorManager.subtleTextColor)
                                                }
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(ColorManager.cardColor)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(user.isSelected ? ColorManager.primaryColor : ColorManager.subtleTextColor.opacity(0.1), lineWidth: user.isSelected ? 2 : 1)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                } else {
                                    // 通常モード時のユーザー行
                                    NavigationLink(destination: GameSelectionView(selectedUser: user.name, userImageURL: user.imageURL, userUID: user.id)) {
                                        HStack(spacing: 15) {
                                            // プロフィール画像
                                            if let url = URL(string: user.imageURL), !user.imageURL.isEmpty {
                                                KFImage(url)
                                                    .placeholder {
                                                        Circle()
                                                            .fill(ColorManager.cardColor)
                                                            .overlay(
                                                                ProgressView()
                                                                    .progressViewStyle(CircularProgressViewStyle(tint: ColorManager.subtleTextColor))
                                                            )
                                                    }
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 50, height: 50)
                                                    .clipShape(Circle())
                                                    .overlay(
                                                        Circle()
                                                            .stroke(ColorManager.subtleTextColor.opacity(0.3), lineWidth: 1)
                                                    )
                                            } else {
                                                Circle()
                                                    .fill(ColorManager.cardColor)
                                                    .frame(width: 50, height: 50)
                                                    .overlay(
                                                        Image(systemName: "person.fill")
                                                            .foregroundColor(ColorManager.subtleTextColor)
                                                    )
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(user.name)
                                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                                    .foregroundColor(ColorManager.textColor)
                                                
                                                HStack(spacing: 5) {
                                                    Image(systemName: "heart.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(ColorManager.primaryColor)
                                                    
                                                    Text("\(user.heartRate) BPM")
                                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                                        .foregroundColor(ColorManager.subtleTextColor)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(ColorManager.subtleTextColor.opacity(0.6))
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(ColorManager.cardColor)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(ColorManager.subtleTextColor.opacity(0.1), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, 25)
                        .padding(.bottom, 100) // タブバー用余白
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .alert("友達を削除", isPresented: $showDeleteConfirmation) {
                Button("キャンセル", role: .cancel) { }
                Button("削除", role: .destructive) {
                    deleteSelectedFriends()
                }
            } message: {
                Text("\(selectedUserCount)人の友達を削除しますか？\nこの操作は元に戻せません。")
            }
        }
        .onAppear {
            setupPermittedUsersObservers()
        }
        .onDisappear {
            removeAllObservers()
        }
    }
    
    // MARK: - Firebase監視設定
    private func setupPermittedUsersObservers() {
        guard let currentUser = authViewModel.currentUser else { return }
        let uid = currentUser.uid
        let ref = Database.database().reference()
        
        // "AcceptUser/<currentUID>/permittedUser" の監視
        permittedUsersHandle = ref.child("AcceptUser").child(uid).child("permittedUser")
            .observe(.value) { snapshot in
                var updatedIDs: Set<String> = []
                // snapshot の各子要素をループ（キーは許可されたユーザーのUID、値は Bool）
                for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                    if let allowed = child.value as? Bool, allowed {
                        updatedIDs.insert(child.key)
                    }
                }
                
                DispatchQueue.main.async {
                    // 現在の permittedUsers 配列から、許可状態が false になったユーザーを削除
                    permittedUsers.removeAll { !updatedIDs.contains($0.id) }
                    
                    // 新たに許可されたユーザーについては、追加と監視の設定
                    for newID in updatedIDs {
                        // すでにリストに存在していなければ追加
                        if !permittedUsers.contains(where: { $0.id == newID }) {
                            let newUser = PermittedUser(id: newID)
                            permittedUsers.append(newUser)
                            // 各ユーザーの情報を監視
                            observeUserInfo(for: newID)
                            observeHeartRate(for: newID)
                        }
                    }
                }
            }
    }
    
    // 各ユーザーの UName と Uimage を監視
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
    
    // 各ユーザーの心拍数（Heartbeat/Watch1/HeartRate）を監視
    private func observeHeartRate(for permittedUID: String) {
        let ref = Database.database().reference()
        let handle = ref.child("Userdata").child(permittedUID)
            .child("Heartbeat").child("Watch1").child("HeartRate")
            .observe(.value) { snapshot in
                var rate: Int = 0
                if let intRate = snapshot.value as? Int {
                    rate = intRate
                } else if let strRate = snapshot.value as? String, let intVal = Int(strRate) {
                    rate = intVal
                }
                DispatchQueue.main.async {
                    if let index = permittedUsers.firstIndex(where: { $0.id == permittedUID }) {
                        permittedUsers[index].heartRate = rate
                    }
                }
            }
        heartRateHandles[permittedUID] = handle
    }
    
    // 選択した友達を削除する処理
    private func deleteSelectedFriends() {
        guard let currentUser = authViewModel.currentUser else { return }
        let currentUID = currentUser.uid
        
        // 選択されたすべてのユーザーを取得
        let selectedUsers = permittedUsers.filter { $0.isSelected }
        
        // 各ユーザーを削除処理
        for user in selectedUsers {
            let friendUID = user.id
            let ref = Database.database().reference()
            
            // 1. 自身の permissions ノードから friendUID のエントリを削除
            ref.child("AcceptUser").child(currentUID)
                .child("permissions").child(friendUID).removeValue { error, _ in
                    if let error = error {
                        print("permissions 削除エラー: \(error.localizedDescription)")
                    } else {
                        print("自身の permissions から \(friendUID) を削除")
                    }
                }
                
            // 2. 自身の permittedUser ノードから friendUID のエントリを削除
            ref.child("AcceptUser").child(currentUID)
                .child("permittedUser").child(friendUID).removeValue { error, _ in
                    if let error = error {
                        print("自身の permittedUser 削除エラー: \(error.localizedDescription)")
                    } else {
                        print("自身の permittedUser から \(friendUID) を削除")
                    }
                }
            
            // 3. 相手側の permissions ノードから自身のUIDのエントリを削除
            ref.child("AcceptUser").child(friendUID)
                .child("permissions").child(currentUID).removeValue { error, _ in
                    if let error = error {
                        print("相手の permissions 削除エラー: \(error.localizedDescription)")
                    } else {
                        print("相手の permissions から \(currentUID) を削除")
                    }
                }
            
            // 4. 相手側の permittedUser ノードから自身のUIDのエントリを削除
            ref.child("AcceptUser").child(friendUID)
                .child("permittedUser").child(currentUID).removeValue { error, _ in
                    if let error = error {
                        print("相手の permittedUser 削除エラー: \(error.localizedDescription)")
                    } else {
                        print("相手の permittedUser から \(currentUID) を削除")
                    }
                }
            
            // 5. 監視を解除
            removeObservers(for: friendUID)
        }
        
        // 4. UIから削除（Firebaseの監視が解除されると自動的に更新されるはずだが、念のため手動で更新）
        DispatchQueue.main.async {
            permittedUsers.removeAll { $0.isSelected }
            
            // 削除モードを終了
            withAnimation {
                isDeleteMode = false
            }
        }
    }
    
    // 特定ユーザーの監視を解除
    private func removeObservers(for uid: String) {
        let ref = Database.database().reference()
        
        // ユーザー情報の監視解除
        if let handle = userInfoHandles[uid] {
            ref.child("Username").child(uid).removeObserver(withHandle: handle)
            userInfoHandles.removeValue(forKey: uid)
        }
        
        // 心拍数の監視解除
        if let handle = heartRateHandles[uid] {
            ref.child("Userdata").child(uid)
                .child("Heartbeat").child("Watch1").child("HeartRate")
                .removeObserver(withHandle: handle)
            heartRateHandles.removeValue(forKey: uid)
        }
    }
    
    // 全ての observer を解除する
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
        for (permittedUID, handle) in heartRateHandles {
            ref.child("Userdata").child(permittedUID)
                .child("Heartbeat").child("Watch1").child("HeartRate")
                .removeObserver(withHandle: handle)
        }
        userInfoHandles.removeAll()
        heartRateHandles.removeAll()
    }
}

// MARK: - プレビュー用
struct UserSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        UserSelectionView()
            .environmentObject(AuthViewModel())
            .preferredColorScheme(.dark)
    }
}
// MARK: - QRCodeView
// QRコードの表示とスキャンの切り替え画面
struct QRCodeView: View {
    // 環境オブジェクトから認証情報を取得（ログイン中のユーザー情報）
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // 表示／読み込み画面の切り替えフラグ（true: 表示モード / false: スキャンモード）
    @State var Switchflag: Bool = true
    // 読み込んだQRコードのデータ（友達用UIDが入る前提）
    @State var ReadData: String? = ""
    // スキャン結果のメッセージ表示用フラグ
    @State var Successcode: Bool = false
    // スキャン結果メッセージ
    @State var QRtext: String = ""
    // QRコードキャッシュ
    @State private var cachedQRCode: UIImage?
    
    // モーダルを閉じるための環境変数
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // 背景色
            ColorManager.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ヘッダー部分
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(ColorManager.textColor)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(ColorManager.cardColor)
                            )
                    }
                    
                    Spacer()
                    
                    Text(Switchflag ? "QRコード表示" : "QRコードスキャン")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(ColorManager.textColor)
                    
                    Spacer()
                    
                    // バランスを取るための空のスペース
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                }
                .padding(.top, 50) // ステータスバー分の余白
                .padding(.horizontal, 25)
                .padding(.bottom, 20)

                // メインコンテンツ
                if Switchflag {
                    // QRコード表示モード
                    VStack(spacing: 24) {
                        Text("自分のQRコード")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(ColorManager.textColor)
                            .padding(.bottom, 10)
                        
                        // QRコード表示エリア
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(ColorManager.cardColor)
                                .frame(width: 320, height: 320)
                                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                            
                            if let qrCode = cachedQRCode {
                                Image(uiImage: qrCode)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 260, height: 260)
                                    .background(Color.white)
                                    .cornerRadius(16)
                            } else {
                                VStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: ColorManager.primaryColor))
                                        .scaleEffect(1.5)
                                    
                                    Text("QRコードを生成中...")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(ColorManager.subtleTextColor)
                                        .padding(.top, 20)
                                }
                                .onAppear {
                                    // 現在ログインしているユーザーのUIDでQRコード生成
                                    if let currentUID = authViewModel.currentUser?.uid {
                                        generateAndCacheQRCode(from: currentUID)
                                    }
                                }
                            }
                        }
                        
                        Text("このQRコードを友達にスキャンしてもらいましょう")
                            .font(.system(size: 16))
                            .foregroundColor(ColorManager.subtleTextColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                            .padding(.top, 20)
                    }
                    .padding(.top, 50)
                    .padding(.bottom, 30)
                } else {
                    // QRコードスキャンモード
                    ZStack {
                        QRCodeScannerView(scannedCode: $ReadData) {
                            // スキャンが完了したら処理を実施
                            if let friendUID = ReadData, !friendUID.isEmpty {
                                // 自身のUIDを取得
                                guard let currentUID = authViewModel.currentUser?.uid else {
                                    QRtext = "認証情報が見つかりません"
                                    Successcode = true
                                    return
                                }
                                // 同じUIDの場合はエラー表示
                                if currentUID == friendUID {
                                    QRtext = "同じユーザーは追加できません"
                                    Successcode = true
                                } else {
                                    let ref = Database.database().reference()
                                    // まず自身の permissions ノードにすでに登録されているか確認
                                    ref.child("AcceptUser").child(currentUID)
                                        .child("permissions").child(friendUID)
                                        .observeSingleEvent(of: .value) { snapshot in
                                            if let isRegistered = snapshot.value as? Bool, isRegistered == true {
                                                // すでに登録済みの場合
                                                QRtext = "既に登録されています"
                                                Successcode = true
                                            } else {
                                                // 登録されていない場合、登録処理を実施
                                                
                                                // 1. 自身の permissions ノードに friendUID を true で書き込み
                                                ref.child("AcceptUser").child(currentUID)
                                                    .child("permissions").child(friendUID)
                                                    .setValue(true) { error, _ in
                                                        if let error = error {
                                                            print("permissions 書き込みエラー: \(error.localizedDescription)")
                                                        } else {
                                                            print("自身の permissions に \(friendUID) を追加")
                                                        }
                                                    }
                                                
                                                // 2. 相手側の permittedUser ノードに自身の UID を true で書き込み
                                                ref.child("AcceptUser").child(friendUID)
                                                    .child("permittedUser").child(currentUID)
                                                    .setValue(true) { error, _ in
                                                        if let error = error {
                                                            print("permittedUser 書き込みエラー: \(error.localizedDescription)")
                                                        } else {
                                                            print("相手の permittedUser に \(currentUID) を追加")
                                                        }
                                                    }
                                                
                                                // 3. 相手側の permissions ノードに自身の UID を true で書き込み（追加）
                                                ref.child("AcceptUser").child(friendUID)
                                                    .child("permissions").child(currentUID)
                                                    .setValue(true) { error, _ in
                                                        if let error = error {
                                                            print("相手の permissions 書き込みエラー: \(error.localizedDescription)")
                                                        } else {
                                                            print("相手の permissions に \(currentUID) を追加")
                                                        }
                                                    }
                                                
                                                // 4. 自身の permittedUser ノードに相手の UID を true で書き込み（追加）
                                                ref.child("AcceptUser").child(currentUID)
                                                    .child("permittedUser").child(friendUID)
                                                    .setValue(true) { error, _ in
                                                        if let error = error {
                                                            print("自身の permittedUser 書き込みエラー: \(error.localizedDescription)")
                                                        } else {
                                                            print("自身の permittedUser に \(friendUID) を追加")
                                                        }
                                                    }
                                                
                                                QRtext = "フレンド登録が完了しました"
                                                Successcode = true
                                            }
                                        }
                                }
                            } else {
                                QRtext = "無効なQRコードです"
                                Successcode = true
                            }
                        }
                        
                        // スキャンガイド表示
                        VStack {
                            Spacer()
                            
                            Text("友達のQRコードをスキャンしてください")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.black.opacity(0.6))
                                )
                                .padding(.bottom, 80)
                        }
                    }
                    .alert(QRtext, isPresented: $Successcode) {
                        Button("OK") {
                            Successcode = false
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                
                Spacer()
                
                // 切り替えボタン部分
                HStack(spacing: 0) {
                    // 表示モードボタン
                    Button(action: {
                        withAnimation {
                            Switchflag = true
                        }
                    }) {
                        VStack(spacing: 12) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 30))
                                .foregroundColor(Switchflag ? ColorManager.primaryColor : ColorManager.subtleTextColor)
                            
                            Text("表示")
                                .font(.system(size: 16, weight: Switchflag ? .bold : .medium))
                                .foregroundColor(Switchflag ? ColorManager.primaryColor : ColorManager.subtleTextColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Switchflag ? ColorManager.cardColor : Color.clear)
                                .opacity(Switchflag ? 1 : 0)
                        )
                    }
                    
                    // スキャンモードボタン
                    Button(action: {
                        withAnimation {
                            Switchflag = false
                        }
                    }) {
                        VStack(spacing: 12) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 30))
                                .foregroundColor(!Switchflag ? ColorManager.primaryColor : ColorManager.subtleTextColor)
                            
                            Text("スキャン")
                                .font(.system(size: 16, weight: !Switchflag ? .bold : .medium))
                                .foregroundColor(!Switchflag ? ColorManager.primaryColor : ColorManager.subtleTextColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(!Switchflag ? ColorManager.cardColor : Color.clear)
                                .opacity(!Switchflag ? 1 : 0)
                        )
                    }
                }
                .padding(.horizontal, 25)
                .padding(.bottom, 30)
                .background(
                    Rectangle()
                        .fill(ColorManager.backgroundColor.opacity(0.95))
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
                )
            }
            .onAppear {
                cachedQRCode = loadQRCodeFromCache()
                if cachedQRCode == nil,
                   let currentUID = authViewModel.currentUser?.uid {
                    generateAndCacheQRCode(from: currentUID)
                }
            }
        }
    }
    
    // MARK: - QRコード生成・キャッシュ処理
    private func generateAndCacheQRCode(from string: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let image = generateQRCode(from: string)
            DispatchQueue.main.async {
                self.cachedQRCode = image
                saveQRCodeToCache(image, for: string)
            }
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        // エラー訂正レベルを設定（例："M"）
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        if let outputImage = filter.outputImage,
           let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgimg)
        }
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
    
    private func saveQRCodeToCache(_ image: UIImage, for uid: String) {
        if let data = image.pngData() {
            UserDefaults.standard.set(data, forKey: "cachedQRCode_\(uid)")
        }
    }
    
    private func loadQRCodeFromCache() -> UIImage? {
        if let currentUID = authViewModel.currentUser?.uid,
           let data = UserDefaults.standard.data(forKey: "cachedQRCode_\(currentUID)") {
            return UIImage(data: data)
        }
        return nil
    }
}

struct QRCodeView_Previews: PreviewProvider {
    static var previews: some View {
        QRCodeView()
            .environmentObject(AuthViewModel())
            .preferredColorScheme(.dark)
    }
}

// MARK: - QRCodeScannerView
struct QRCodeScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    var completion: () -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        // Coordinator を delegate として設定
        vc.metadataDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        // 更新処理は不要
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let parent: QRCodeScannerView
        
        init(parent: QRCodeScannerView) {
            self.parent = parent
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first,
               let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
               let stringValue = readableObject.stringValue {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                DispatchQueue.main.async {
                    self.parent.scannedCode = stringValue
                    self.parent.completion()
                }
            }
        }
    }
}

// MARK: - ScannerViewController
class ScannerViewController: UIViewController {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    // スキャンエリアを示すガイドビューを追加
    private let scannerOverlayView = ScannerOverlayView()
    
    // delegate を設定するためのプロパティ
    var metadataDelegate: AVCaptureMetadataOutputObjectsDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        
        // セッションの生成
        captureSession = AVCaptureSession()
        
        // 解像度設定（高品質）
        captureSession.sessionPreset = .high
        
        // 事前に previewLayer を生成しておく（captureSession は既に作成済み）
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.bounds
        
        // デフォルトの背面カメラを利用
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            failed()
            return
        }
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            failed()
            return
        }
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }
        
        // メタデータ出力の設定
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            // delegate を設定
            metadataOutput.setMetadataObjectsDelegate(metadataDelegate, queue: DispatchQueue.main)
            // QRコードの認識を有効化
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            failed()
            return
        }
        
        // カメラプレビューの表示
        view.layer.addSublayer(previewLayer)
        
        // スキャンエリアオーバーレイを追加
        scannerOverlayView.frame = view.bounds
        view.addSubview(scannerOverlayView)
        
        // トーチボタンを追加（ライトのON/OFF）
        addTorchButton()
        
        // 認識範囲を設定（オーバーレイでスキャン領域を示したエリアに合わせる）
        // プレビューレイヤーにスキャンエリアを合わせる
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let metadataOutput = self.captureSession.outputs.first as? AVCaptureMetadataOutput else { return }
            
            // スキャンエリアの計算（画面中央の正方形）
            let scanRect = self.scannerOverlayView.scanRect
            
            // プレビューレイヤー座標系に変換
            metadataOutput.rectOfInterest = self.previewLayer.metadataOutputRectConverted(fromLayerRect: scanRect)
        }
        
        captureSession.startRunning()
    }
    
    // トーチボタンの追加
    private func addTorchButton() {
        let torchButton = UIButton(type: .system)
        torchButton.setImage(UIImage(systemName: "flashlight.off.fill"), for: .normal)
        torchButton.tintColor = UIColor.white
        torchButton.backgroundColor = UIColor.darkGray.withAlphaComponent(0.6)
        torchButton.layer.cornerRadius = 25
        torchButton.frame = CGRect(x: view.bounds.width - 60, y: view.bounds.height - 120, width: 50, height: 50)
        torchButton.addTarget(self, action: #selector(toggleTorch), for: .touchUpInside)
        view.addSubview(torchButton)
    }
    
    // トーチのON/OFF切り替え
    @objc private func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.torchMode == .off {
                try device.setTorchModeOn(level: 1.0)
                // ボタンの見た目を更新
                if let torchButton = view.subviews.first(where: { $0 is UIButton }) as? UIButton {
                    torchButton.setImage(UIImage(systemName: "flashlight.on.fill"), for: .normal)
                }
            } else {
                device.torchMode = .off
                // ボタンの見た目を更新
                if let torchButton = view.subviews.first(where: { $0 is UIButton }) as? UIButton {
                    torchButton.setImage(UIImage(systemName: "flashlight.off.fill"), for: .normal)
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            print("トーチの設定エラー: \(error.localizedDescription)")
        }
    }
    
    func failed() {
        let alert = UIAlertController(title: "スキャンに対応していません",
                                      message: "お使いのデバイスはQRコードの読み取りに対応していません。",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
        captureSession = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.layer.bounds
        scannerOverlayView.frame = view.bounds
        
        // トーチボタンの位置を更新
        if let torchButton = view.subviews.first(where: { $0 is UIButton }) as? UIButton {
            torchButton.frame = CGRect(x: view.bounds.width - 60, y: view.bounds.height - 120, width: 50, height: 50)
        }
    }
}

// MARK: - ScannerOverlayView
class ScannerOverlayView: UIView {
    // スキャンエリアの設定
    private let cornerLength: CGFloat = 30
    private let cornerWidth: CGFloat = 5
    private let scannerSize: CGFloat = 250
    
    // スキャン矩形を外部から取得できるようにする
    var scanRect: CGRect {
        let x = (bounds.width - scannerSize) / 2
        let y = (bounds.height - scannerSize) / 2
        return CGRect(x: x, y: y, width: scannerSize, height: scannerSize)
    }
    
    // アニメーション用のラインビュー
    private let scanLine = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        
        // スキャンラインの初期化
        scanLine.backgroundColor = UIColor(red: 0.95, green: 0.2, blue: 0.3, alpha: 0.8) // ColorManager.primaryColor に合わせた色
        addSubview(scanLine)
        
        // アニメーションの開始
        startScanLineAnimation()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // オーバーレイの背景色（半透明黒）
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        context.fill(rect)
        
        // スキャンエリアの座標を計算
        let x = (rect.width - scannerSize) / 2
        let y = (rect.height - scannerSize) / 2
        
        // スキャンエリアをくり抜く（透明にする）
        let scannerRect = CGRect(x: x, y: y, width: scannerSize, height: scannerSize)
        context.addRect(scannerRect)
        context.setBlendMode(.clear)
        context.fill(scannerRect)
        context.setBlendMode(.normal)
        
        // スキャンエリアの角を描画
        context.setStrokeColor(UIColor(red: 0.95, green: 0.2, blue: 0.3, alpha: 1.0).cgColor)
        context.setLineWidth(cornerWidth)
        
        // 左上の角
        context.move(to: CGPoint(x: x, y: y + cornerLength))
        context.addLine(to: CGPoint(x: x, y: y))
        context.addLine(to: CGPoint(x: x + cornerLength, y: y))
        
        // 右上の角
        context.move(to: CGPoint(x: x + scannerSize - cornerLength, y: y))
        context.addLine(to: CGPoint(x: x + scannerSize, y: y))
        context.addLine(to: CGPoint(x: x + scannerSize, y: y + cornerLength))
        
        // 右下の角
        context.move(to: CGPoint(x: x + scannerSize, y: y + scannerSize - cornerLength))
        context.addLine(to: CGPoint(x: x + scannerSize, y: y + scannerSize))
        context.addLine(to: CGPoint(x: x + scannerSize - cornerLength, y: y + scannerSize))
        
        // 左下の角
        context.move(to: CGPoint(x: x + cornerLength, y: y + scannerSize))
        context.addLine(to: CGPoint(x: x, y: y + scannerSize))
        context.addLine(to: CGPoint(x: x, y: y + scannerSize - cornerLength))
        
        context.strokePath()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // スキャンラインの位置とサイズを更新
        let x = (bounds.width - scannerSize) / 2
        let y = (bounds.height - scannerSize) / 2
        scanLine.frame = CGRect(x: x, y: y, width: scannerSize, height: 2)
        
        // アニメーションの再開始
        startScanLineAnimation()
    }
    
    private func startScanLineAnimation() {
        // 既存のアニメーションをリセット
        scanLine.layer.removeAllAnimations()
        
        // スキャンラインの初期位置を設定
        let x = (bounds.width - scannerSize) / 2
        let y = (bounds.height - scannerSize) / 2
        scanLine.frame = CGRect(x: x, y: y, width: scannerSize, height: 2)
        
        // アニメーションの設定
        UIView.animate(withDuration: 2.0, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut], animations: {
            // スキャンラインをスキャンエリアの下端まで移動
            self.scanLine.frame = CGRect(x: x, y: y + self.scannerSize - 2, width: self.scannerSize, height: 2)
        })
    }
}
