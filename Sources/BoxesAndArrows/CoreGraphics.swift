import Cocoa
import CoreGraphics

func measure(box: Box) -> CGSize {
    let attributedString = attributedString(for: box)
    let boundingRect = attributedString.boundingRect(
        with: .init(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
        options: .usesLineFragmentOrigin
    )
    return boundingRect.size
}

func attributedString(for box: Box) -> NSAttributedString {
    let font = NSFont.systemFont(ofSize: 16)
    let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    paragraphStyle.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .paragraphStyle: paragraphStyle,
    ]
    let attributedString = NSAttributedString(string: box.label, attributes: attributes)
    return attributedString
}

func draw(graph: Graph) -> NSImage {
    draw(width: graph.width.variable.value, height: graph.height.variable.value) { ctx, rect in
        NSColor.white.setFill()
        ctx.fill([rect])

        for box in graph.boxes.values {
            let attributedString = attributedString(for: box)
            attributedString.draw(at: box.frame.origin)
            ctx.addRect(box.frame)
            ctx.strokePath()
        }

        let connectionPointRegister = ConnectionPointRegister()
        for arrow in graph.arrows {
            let source = graph.boxes[arrow.source]!
            let target = graph.boxes[arrow.target]!
            var accessGrid = AccessGrid(
                graph: graph,
                sourceBox: source,
                targetBox: target,
                cellSize: 5
            )
            let path = accessGrid.path(
                from: source.frame,
                to: target.frame,
                connectionPointRegister: connectionPointRegister
            )
            guard let path = path,
                  let path0 = path.first,
                  case var pathTail = path.dropFirst(),
                  let path1 = pathTail.dropFirst().first
            else { continue }

            let lineStart: CGPoint
            let pp0 = accessGrid.point(at: path0)

            if path0.x == path1.x {
                // vertical
                if path0.y < path1.y {
                    // going down, will cross with bottom of box
                    lineStart = CGPoint(x: pp0.x, y: source.frame.maxY)
                    pathTail = pathTail.drop(while: { accessGrid.point(at: $0).y < lineStart.y })
                } else {
                    // going up, will cross with top of box
                    lineStart = CGPoint(x: pp0.x, y: source.frame.minY)
                    pathTail = pathTail.drop(while: { accessGrid.point(at: $0).y > lineStart.y })
                }
            } else {
                // horizontal
                if path0.x < path1.x {
                    // going right, will cross with right edge of box
                    lineStart = CGPoint(x: source.frame.maxX, y: pp0.y)
                    pathTail = pathTail.drop(while: { accessGrid.point(at: $0).x < lineStart.x })
                } else {
                    // going left, will cross with left edge of box
                    lineStart = CGPoint(x: source.frame.minX, y: pp0.y)
                    pathTail = pathTail.drop(while: { accessGrid.point(at: $0).x > lineStart.x })
                }
            }

            // target end of line
            guard let pathR0 = pathTail.last, let pathR1 = pathTail.dropLast().last else { continue }
            let pR0p = accessGrid.point(at: pathR0)
            let lineEnd: CGPoint
            if pathR0.x == pathR1.x {
                // vertical
                if pathR1.y < pathR0.y {
                    // second to last is above last, line goes down, will cross top of box
                    lineEnd = CGPoint(x: pR0p.x, y: target.frame.minY)
                    let lastAbove = pathTail.lastIndex(where: { accessGrid.point(at: $0).y < lineEnd.y }) ?? 0
                    pathTail = pathTail.prefix(upTo: lastAbove + 1)
                } else {
                    // second to last below last, line goes up, will cross bottom of box
                    lineEnd = CGPoint(x: pR0p.x, y: target.frame.maxY)
                    let lastBelow = pathTail.lastIndex(where: { accessGrid.point(at: $0).y > lineEnd.y }) ?? 0
                    pathTail = pathTail.prefix(upTo: lastBelow + 1)
                }
            } else {
                // horizontal
                if pathR1.x < pathR0.x {
                    // second to last left of last, line goes right, will cross left side of box
                    lineEnd = CGPoint(x: target.frame.minX, y: pR0p.y)
                    let lastLeft = pathTail.lastIndex(where: { accessGrid.point(at: $0).x < lineEnd.x }) ?? 0
                    pathTail = pathTail.prefix(upTo: lastLeft + 1)
                } else {
                    // second to last right of last, line goes left, will cross right side of box
                    lineEnd = CGPoint(x: target.frame.maxX, y: pR0p.y)
                    let lastRight = pathTail.lastIndex(where: { accessGrid.point(at: $0).x > lineEnd.x }) ?? 0
                    pathTail = pathTail.prefix(upTo: lastRight + 1)
                }
            }

            ctx.move(to: lineStart)
            for coordinate in pathTail {
                ctx.addLine(to: accessGrid.point(at: coordinate))
            }
            ctx.addLine(to: lineEnd)
            ctx.strokePath()
        }
    }
}

func draw(width: CGFloat, height: CGFloat, closure: @escaping (CGContext, CGRect) -> Void) -> NSImage {
    NSImage(size: NSSize(width: width, height: height), flipped: true) { rect in
        let graphicsContext = NSGraphicsContext.current!
        let context = graphicsContext.cgContext
        context.setStrokeColor(.black)

        closure(context, rect)
        return true
    }
}
