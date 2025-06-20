//
//  Engine.swift
//  Hear2gether
//
//  Created by Applied Haptics Laboratory on 2025/02/07.
//

import SwiftUI
import SpriteKit

/// テトリミノの種類
enum TetriminoType: CaseIterable {
    case I, O, T, S, Z, J, L
}

/// テトリミノの回転別形状 (ローカル座標) を返す
///
/// ポイント:
/// - すべての形状について、(0,0)が一番下のマスになるように定義
/// - Iミノの場合、横向き(回転0)は [ (0,0), (1,0), (2,0), (3,0) ]
///   縦向き(回転1)は [ (0,0), (0,1), (0,2), (0,3) ] のように
///   「最大 y=3」で済むような形にしておく
func shapeFor(type: TetriminoType) -> [[CGPoint]] {
    switch type {
    case .I:
        return [
            // 回転0 (横)
            [CGPoint(x: 0, y: 0),
             CGPoint(x: 1, y: 0),
             CGPoint(x: 2, y: 0),
             CGPoint(x: 3, y: 0)],
            // 回転1 (縦)
            [CGPoint(x: 0, y: 0),
             CGPoint(x: 0, y: 1),
             CGPoint(x: 0, y: 2),
             CGPoint(x: 0, y: 3)],
            // 回転2 = 回転0 と同じ
            [CGPoint(x: 0, y: 0),
             CGPoint(x: 1, y: 0),
             CGPoint(x: 2, y: 0),
             CGPoint(x: 3, y: 0)],
            // 回転3 = 回転1 と同じ
            [CGPoint(x: 0, y: 0),
             CGPoint(x: 0, y: 1),
             CGPoint(x: 0, y: 2),
             CGPoint(x: 0, y: 3)]
        ]
    case .O:
        return [
            [CGPoint(x: 0, y: 0),
             CGPoint(x: 1, y: 0),
             CGPoint(x: 0, y: 1),
             CGPoint(x: 1, y: 1)]
        ]
    case .T:
        return [
            // 回転0
            [CGPoint(x: 0, y: 0),
             CGPoint(x: 1, y: 0),
             CGPoint(x: 2, y: 0),
             CGPoint(x: 1, y: 1)],
            // 回転1
            [CGPoint(x: 0, y: 0),
             CGPoint(x: 0, y: 1),
             CGPoint(x: 0, y: 2),
             CGPoint(x: 1, y: 1)],
            // 回転2
            [CGPoint(x: 0, y: 1),
             CGPoint(x: 1, y: 1),
             CGPoint(x: 2, y: 1),
             CGPoint(x: 1, y: 0)],
            // 回転3
            [CGPoint(x: 1, y: 0),
             CGPoint(x: 1, y: 1),
             CGPoint(x: 1, y: 2),
             CGPoint(x: 0, y: 1)]
        ]
    case .S:
        return [
            // 回転0
            [CGPoint(x: 1, y: 0),
             CGPoint(x: 2, y: 0),
             CGPoint(x: 0, y: 1),
             CGPoint(x: 1, y: 1)],
            // 回転1
            [CGPoint(x: 0, y: 0),
             CGPoint(x: 0, y: 1),
             CGPoint(x: 1, y: 1),
             CGPoint(x: 1, y: 2)],
            // 回転2
            [CGPoint(x: 1, y: 1),
             CGPoint(x: 2, y: 1),
             CGPoint(x: 0, y: 2),
             CGPoint(x: 1, y: 2)],
            // 回転3
            [CGPoint(x: 1, y: 0),
             CGPoint(x: 1, y: 1),
             CGPoint(x: 2, y: 1),
             CGPoint(x: 2, y: 2)]
        ]
    case .Z:
        return [
            // 回転0
            [CGPoint(x: 0, y: 0),
             CGPoint(x: 1, y: 0),
             CGPoint(x: 1, y: 1),
             CGPoint(x: 2, y: 1)],
            // 回転1
            [CGPoint(x: 1, y: 0),
             CGPoint(x: 1, y: 1),
             CGPoint(x: 0, y: 1),
             CGPoint(x: 0, y: 2)],
            // 回転2
            [CGPoint(x: 0, y: 1),
             CGPoint(x: 1, y: 1),
             CGPoint(x: 1, y: 2),
             CGPoint(x: 2, y: 2)],
            // 回転3
            [CGPoint(x: 1, y: 1),
             CGPoint(x: 1, y: 2),
             CGPoint(x: 0, y: 2),
             CGPoint(x: 0, y: 3)]
        ]
    case .J:
        return [
            // 回転0
            [CGPoint(x: 0, y: 0),
             CGPoint(x: 0, y: 1),
             CGPoint(x: 1, y: 1),
             CGPoint(x: 2, y: 1)],
            // 回転1
            [CGPoint(x: 0, y: 2),
             CGPoint(x: 1, y: 0),
             CGPoint(x: 1, y: 1),
             CGPoint(x: 1, y: 2)],
            // 回転2
            [CGPoint(x: 0, y: 0),
             CGPoint(x: 1, y: 0),
             CGPoint(x: 2, y: 0),
             CGPoint(x: 2, y: 1)],
            // 回転3
            [CGPoint(x: 0, y: 0),
             CGPoint(x: 0, y: 1),
             CGPoint(x: 0, y: 2),
             CGPoint(x: 1, y: 0)]
        ]
    case .L:
        return [
            // 回転0
            [CGPoint(x: 0, y: 1),
             CGPoint(x: 1, y: 1),
             CGPoint(x: 2, y: 1),
             CGPoint(x: 2, y: 0)],
            // 回転1
            [CGPoint(x: 0, y: 0),
             CGPoint(x: 0, y: 1),
             CGPoint(x: 0, y: 2),
             CGPoint(x: 1, y: 2)],
            // 回転2
            [CGPoint(x: 0, y: 1),
             CGPoint(x: 1, y: 1),
             CGPoint(x: 2, y: 1),
             CGPoint(x: 0, y: 0)],
            // 回転3
            [CGPoint(x: 0, y: 0),
             CGPoint(x: 1, y: 0),
             CGPoint(x: 1, y: 1),
             CGPoint(x: 1, y: 2)]
        ]
    }
}

/// テトリミノの構造体
struct Tetrimino {
    var type: TetriminoType
    var rotationIndex: Int
    var position: CGPoint  // ボード上 (x, y) グリッド単位
    var shapes: [[CGPoint]]
    
    var currentShape: [CGPoint] {
        shapes[rotationIndex % shapes.count]
    }
}

/// ★ 追加機能 ★
/// マルチプレイヤー等で盤面の状態を外部に通知するためのコールバックを定義
/// board の状態は [[UIColor?]] で管理（nilなら空セル）
class TetrisGameScene: SKScene, ObservableObject {
    
    // 盤面サイズ・ブロックサイズ
    let numColumns = 10
    let numRows = 20
    var blockSize: CGFloat = 20.0
    
    // スコア・ゲームオーバー状態（SwiftUI連携用）
    @Published var score: Int = 0
    @Published var isGameOver: Bool = false
    
    // 盤面（nilなら空セル）
    var board: [[UIColor?]] = []
    
    // 現在落下中のピース
    var currentPiece: Tetrimino?
    
    // タイマー
    var gameTimer: Timer?
    let dropTimeInterval: TimeInterval = 0.5
    
    // ★ 追加機能 ★ コールバック定義
    var onLinesCleared: ((Int) -> Void)?
    var onGameOver: (() -> Void)?
    var onFieldUpdated: (([[UIColor?]]) -> Void)?
    
    override init(size: CGSize) {
        super.init(size: size)
        // 空の盤面を作成
        board = Array(repeating: Array(repeating: nil, count: numColumns), count: numRows)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        drawGrid()
    }
    
    // ゲーム開始/再開
    func startGame() {
        score = 0
        isGameOver = false
        board = Array(repeating: Array(repeating: nil, count: numColumns), count: numRows)
        removeAllChildren()
        
        // ブロックサイズ再計算
        blockSize = size.width / CGFloat(numColumns)
        
        drawGrid()
        spawnNewPiece()
        
        // 盤面更新の通知
        onFieldUpdated?(board)
        
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(timeInterval: dropTimeInterval,
                                         target: self,
                                         selector: #selector(gameLoop),
                                         userInfo: nil,
                                         repeats: true)
    }
    
    @objc func gameLoop() {
        movePieceDown()
    }
    
    func spawnNewPiece() {
        let randomType = TetriminoType.allCases.randomElement()!
        let shapes = shapeFor(type: randomType)
        
        // 出現位置: 横は中央、縦は上から4マス下げた位置
        let startX = numColumns / 2 - 2
        let startY = numRows - 4
        
        let newPiece = Tetrimino(type: randomType,
                                 rotationIndex: 0,
                                 position: CGPoint(x: startX, y: startY),
                                 shapes: shapes)
        currentPiece = newPiece
        
        // 初期位置が無効なら即ゲームオーバー
        if !isValidPosition(piece: newPiece) {
            gameOver()
        } else {
            drawCurrentPiece()
        }
    }
    
    // MARK: - 操作
    
    func movePieceLeft() {
        guard var piece = currentPiece else { return }
        piece.position.x -= 1
        if isValidPosition(piece: piece) {
            currentPiece = piece
            drawCurrentPiece()
        }
    }
    
    func movePieceRight() {
        guard var piece = currentPiece else { return }
        piece.position.x += 1
        if isValidPosition(piece: piece) {
            currentPiece = piece
            drawCurrentPiece()
        }
    }
    
    func movePieceDown() {
        guard var piece = currentPiece else { return }
        piece.position.y -= 1
        if isValidPosition(piece: piece) {
            currentPiece = piece
            drawCurrentPiece()
        } else {
            // 衝突または底についた場合
            lockPiece()
            clearLines()
            spawnNewPiece()
        }
    }
    
    func rotatePiece() {
        guard var piece = currentPiece else { return }
        piece.rotationIndex += 1
        if isValidPosition(piece: piece) {
            currentPiece = piece
            drawCurrentPiece()
        } else {
            // 回転が無効なら元に戻す（壁蹴り未実装）
            piece.rotationIndex -= 1
        }
    }
    
    func hardDropPiece() {
        guard var piece = currentPiece else { return }
        while isValidPosition(piece: piece) {
            piece.position.y -= 1
        }
        piece.position.y += 1
        
        // ハードドロップ時の光エフェクト
        applyGlowEffect(to: piece, strength: 0.8)
        currentPiece = piece
        drawCurrentPiece()
        
        lockPiece()
        clearLines()
        spawnNewPiece()
    }
    
    func applyGlowEffect(to piece: Tetrimino, strength: CGFloat) {
        let effectNode = SKNode()
        effectNode.name = "glowEffect"
        
        let glowColor = colorFor(type: piece.type).withAlphaComponent(strength)
        let glowLineWidth = strength * 5
        let fadeDuration = strength > 0.6 ? 0.3 : 0.15
        
        for block in piece.currentShape {
            let blockNode = SKShapeNode(rectOf: CGSize(width: blockSize, height: blockSize), cornerRadius: 5)
            blockNode.fillColor = glowColor
            blockNode.strokeColor = .white
            blockNode.lineWidth = glowLineWidth
            blockNode.position = CGPoint(x: (piece.position.x + block.x) * blockSize + blockSize / 2,
                                         y: (piece.position.y + block.y) * blockSize + blockSize / 2)
            effectNode.addChild(blockNode)
        }
        addChild(effectNode)
        
        let fadeOut = SKAction.fadeOut(withDuration: fadeDuration)
        let remove = SKAction.removeFromParent()
        effectNode.run(SKAction.sequence([fadeOut, remove]))
    }
    
    // MARK: - ピース固定 & ライン消去
    
    func lockPiece() {
        guard let piece = currentPiece else { return }
        for block in piece.currentShape {
            let x = Int(piece.position.x + block.x)
            let y = Int(piece.position.y + block.y)
            // ボード上の有効な範囲でのみ配置
            if x >= 0 && x < numColumns && y >= 0 && y < numRows {
                board[y][x] = colorFor(type: piece.type)
            }
        }
        currentPiece = nil
        
        // 固定後の盤面更新を通知
        onFieldUpdated?(board)
    }
    
    func clearLines() {
        var linesCleared = 0
        // 下から上に向けてチェック（board[0]が最下段）
        for row in (0..<numRows).reversed() {
            if isFullRow(row: row) {
                removeRow(row: row)
                linesCleared += 1
            }
        }
        
        if linesCleared > 0 {
            let scoreTable = [0, 100, 300, 500, 800]
            if linesCleared < scoreTable.count {
                score += scoreTable[linesCleared]
            } else {
                score += 1000
            }
            // ライン消去を通知
            onLinesCleared?(linesCleared)
        }
        drawBoard()
        onFieldUpdated?(board)
    }
    
    func isFullRow(row: Int) -> Bool {
        for col in 0..<numColumns {
            if board[row][col] == nil {
                return false
            }
        }
        return true
    }
    
    func removeRow(row: Int) {
        // 下段から上段へシフト（最下行は board[0] として扱う）
        for r in row..<(numRows - 1) {
            board[r] = board[r + 1]
        }
        board[numRows - 1] = Array(repeating: nil, count: numColumns)
    }
    
    // MARK: - 位置判定
    
    func isValidPosition(piece: Tetrimino) -> Bool {
        for block in piece.currentShape {
            let x = Int(piece.position.x + block.x)
            let y = Int(piece.position.y + block.y)
            // 範囲外チェック
            if x < 0 || x >= numColumns { return false }
            if y < 0 || y >= numRows { return false }
            // 既にブロックがある場合
            if board[y][x] != nil {
                return false
            }
        }
        return true
    }
    
    // MARK: - 描画処理
    
    func drawGrid() {
        childNode(withName: "grid")?.removeFromParent()
        let gridNode = SKNode()
        gridNode.name = "grid"
        
        let lineColor = UIColor.darkGray
        let lineWidth: CGFloat = 0.5
        
        for col in 0...numColumns {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: CGFloat(col)*blockSize, y: 0))
            path.addLine(to: CGPoint(x: CGFloat(col)*blockSize, y: CGFloat(numRows)*blockSize))
            let shape = SKShapeNode(path: path.cgPath)
            shape.strokeColor = lineColor
            shape.lineWidth = lineWidth
            gridNode.addChild(shape)
        }
        for row in 0...numRows {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: CGFloat(row)*blockSize))
            path.addLine(to: CGPoint(x: CGFloat(numColumns)*blockSize, y: CGFloat(row)*blockSize))
            let shape = SKShapeNode(path: path.cgPath)
            shape.strokeColor = lineColor
            shape.lineWidth = lineWidth
            gridNode.addChild(shape)
        }
        addChild(gridNode)
    }
    
    func drawBoard() {
        childNode(withName: "boardNodes")?.removeFromParent()
        let boardNode = SKNode()
        boardNode.name = "boardNodes"
        
        for row in 0..<numRows {
            for col in 0..<numColumns {
                if let color = board[row][col] {
                    let blockNode = SKSpriteNode(color: color,
                                                 size: CGSize(width: blockSize, height: blockSize))
                    let xPos = CGFloat(col)*blockSize + blockSize/2
                    let yPos = CGFloat(row)*blockSize + blockSize/2
                    blockNode.position = CGPoint(x: xPos, y: yPos)
                    boardNode.addChild(blockNode)
                }
            }
        }
        addChild(boardNode)
    }
    
    func drawCurrentPiece() {
        childNode(withName: "currentPiece")?.removeFromParent()
        guard let piece = currentPiece else { return }
        
        let pieceNode = SKNode()
        pieceNode.name = "currentPiece"
        
        let color = colorFor(type: piece.type)
        for block in piece.currentShape {
            let blockNode = SKSpriteNode(color: color,
                                         size: CGSize(width: blockSize, height: blockSize))
            let xPos = (piece.position.x + block.x) * blockSize + blockSize/2
            let yPos = (piece.position.y + block.y) * blockSize + blockSize/2
            blockNode.position = CGPoint(x: xPos, y: yPos)
            pieceNode.addChild(blockNode)
        }
        addChild(pieceNode)
    }
    
    func colorFor(type: TetriminoType) -> UIColor {
        switch type {
        case .I: return .cyan
        case .O: return .yellow
        case .T: return .magenta
        case .S: return .green
        case .Z: return .red
        case .J: return .blue
        case .L: return .orange
        }
    }
    
    // MARK: - お邪魔ブロック処理 ★ 追加機能 ★
    
    /// 指定された行数分のお邪魔ブロック行を盤面に追加する
    /// - Parameter count: 追加するお邪魔行数
    func receiveGarbageLines(count: Int) {
        if count > 0 {
            for _ in 0..<count {
                // すでに最上段が埋まっていればゲームオーバー
                if isTopRowOccupied() {
                    gameOver()
                    return
                }
                // 下段から上段へシフト（board[0]が最下段とする）
                for row in 1..<numRows {
                    board[row - 1] = board[row]
                }
                // 最上段にお邪魔ブロック行を追加（ランダムに1セルを空にする）
                let holePosition = Int.random(in: 0..<numColumns)
                var garbageLine: [UIColor?] = Array(repeating: UIColor.gray, count: numColumns)
                garbageLine[holePosition] = nil  // 穴を作る
                board[numRows - 1] = garbageLine
            }
            drawBoard()
            onFieldUpdated?(board)
        }
    }
    
    /// 盤面最上段（board[numRows-1]）が埋まっているかをチェックする
    func isTopRowOccupied() -> Bool {
        for cell in board[numRows - 1] {
            if cell != nil {
                return true
            }
        }
        return false
    }
    
    // MARK: - ゲームオーバー処理
    
    func gameOver() {
        isGameOver = true
        currentPiece = nil
        gameTimer?.invalidate()
        gameTimer = nil
        onGameOver?()
    }
    
    func colorToInt(_ color: UIColor?) -> Int {
        guard let color = color else { return 0 }
        return color.toInt()
    }
    // 整数配列からフィールドを更新する関数（必要に応じて）
    func updateFieldFromIntArray(_ intField: [[Int]]) {
        for row in 0..<min(intField.count, board.count) {
            for col in 0..<min(intField[row].count, board[row].count) {
                let value = intField[row][col]
                if value == 0 {
                    board[row][col] = nil
                } else {
                    board[row][col] = intToColor(value)
                }
            }
        }
        drawBoard()
    }
    
    // 整数からUIColorに変換する関数
    func intToColor(_ value: Int) -> UIColor {
        switch value {
        case 0: return UIColor.clear
        case 1: return UIColor.cyan
        case 2: return UIColor.yellow
        case 3: return UIColor.magenta
        case 4: return UIColor.green
        case 5: return UIColor.red
        case 6: return UIColor.blue
        case 7: return UIColor.orange
        case 9: return UIColor.gray  // お邪魔ブロック
        default: return UIColor.white
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // 毎フレームの処理（必要に応じて実装）
    }
}
