import SpriteKit
import TetrisCore

final class TetrisScene: SKScene {
    private let columns = Board.visibleWidth
    private let rows = Board.visibleHeight

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0, y: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0, y: 0)
    }

    func render(state: GameState, showsGhost: Bool = true) {
        removeAllChildren()
        drawGrid()
        drawLockedBlocks(board: state.board)
        if let activePiece = state.activePiece {
            if showsGhost {
                drawGhost(piece: ghostPiece(for: activePiece, board: state.board))
            }
            draw(piece: activePiece, alpha: 1.0)
        }
    }

    private func drawGrid() {
        let cellSize = cellSize
        for x in 0...columns {
            let path = CGMutablePath()
            let px = CGFloat(x) * cellSize
            path.move(to: CGPoint(x: px, y: 0))
            path.addLine(to: CGPoint(x: px, y: CGFloat(rows) * cellSize))
            addGridLine(path)
        }

        for y in 0...rows {
            let path = CGMutablePath()
            let py = CGFloat(y) * cellSize
            path.move(to: CGPoint(x: 0, y: py))
            path.addLine(to: CGPoint(x: CGFloat(columns) * cellSize, y: py))
            addGridLine(path)
        }
    }

    private func drawLockedBlocks(board: Board) {
        for y in 0..<rows {
            for x in 0..<columns {
                if let type = board.block(at: Cell(x: x, y: y)) {
                    drawBlock(at: Cell(x: x, y: y), type: type, alpha: 1.0)
                }
            }
        }
    }

    private func draw(piece: Piece, alpha: CGFloat) {
        for cell in piece.cells where (0..<rows).contains(cell.y) {
            drawBlock(at: cell, type: piece.type, alpha: alpha)
        }
    }

    private func drawGhost(piece: Piece) {
        for cell in piece.cells where (0..<rows).contains(cell.y) {
            drawBlock(at: cell, type: piece.type, alpha: 0.23)
        }
    }

    private func drawBlock(at cell: Cell, type: PieceType, alpha: CGFloat) {
        let size = cellSize
        let rect = CGRect(
            x: CGFloat(cell.x) * size + 1,
            y: CGFloat(cell.y) * size + 1,
            width: size - 2,
            height: size - 2
        )
        let node = SKShapeNode(rect: rect, cornerRadius: 2)
        node.fillColor = nsColor(for: type).withAlphaComponent(alpha)
        node.strokeColor = .white.withAlphaComponent(alpha * 0.22)
        node.lineWidth = 1
        addChild(node)
    }

    private func ghostPiece(for piece: Piece, board: Board) -> Piece {
        var ghost = piece
        while board.canPlace(ghost.movedBy(dx: 0, dy: -1)) {
            ghost = ghost.movedBy(dx: 0, dy: -1)
        }
        return ghost
    }

    private func addGridLine(_ path: CGPath) {
        let line = SKShapeNode(path: path)
        line.strokeColor = .white.withAlphaComponent(0.08)
        line.lineWidth = 1
        addChild(line)
    }

    private var cellSize: CGFloat {
        min(size.width / CGFloat(columns), size.height / CGFloat(rows))
    }

    private func nsColor(for type: PieceType) -> NSColor {
        switch type {
        case .i:
            return NSColor(red: 0.15, green: 0.82, blue: 0.94, alpha: 1)
        case .o:
            return NSColor(red: 0.96, green: 0.82, blue: 0.18, alpha: 1)
        case .t:
            return NSColor(red: 0.66, green: 0.38, blue: 0.92, alpha: 1)
        case .s:
            return NSColor(red: 0.28, green: 0.82, blue: 0.38, alpha: 1)
        case .z:
            return NSColor(red: 0.92, green: 0.24, blue: 0.28, alpha: 1)
        case .j:
            return NSColor(red: 0.22, green: 0.42, blue: 0.94, alpha: 1)
        case .l:
            return NSColor(red: 0.95, green: 0.55, blue: 0.20, alpha: 1)
        }
    }
}
