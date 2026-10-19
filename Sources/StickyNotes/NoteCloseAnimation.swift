import AppKit
import QuartzCore

/// Plays the "crush the note into a ball and throw it into the Dock's trash"
/// animation when a note window closes. The real panel closes immediately; this
/// class owns a transient, mouse-transparent panel that animates an offscreen
/// snapshot of the note:
///
/// 1. *Crush* — the snapshot shrinks into a squashed ball with a slight wobble.
/// 2. *Throw* — the ball is tossed in an arc toward the Dock's trash icon,
///    spinning as it flies, shrinking and fading out as it drops in.
@MainActor
final class NoteCloseAnimation {
    /// Keeps running animations alive; `finish()` removes the instance again.
    private static var running: [NoteCloseAnimation] = []

    private static let crushDuration: CFTimeInterval = 0.45
    private static let fallDuration: CFTimeInterval = 0.85
    /// Ball diameter as a fraction of the note's shorter side.
    private static let ballFraction: CGFloat = 0.30
    /// Rotation reached at the end of the crush, in radians.
    private static let crushAngle: CGFloat = -0.55
    /// Extra rotation while flying, in radians (negative = counter-clockwise).
    private static let spinAngle: CGFloat = -10.5

    /// The note's window frame in screen coordinates at close time.
    private let noteFrame: NSRect
    private let ballDiameter: CGFloat
    /// Center where the crushed ball rests, a touch below the note's center.
    private let throwStart: NSPoint
    private let trashPoint: NSPoint
    private let startTime = CACurrentMediaTime()
    private let panel: NSPanel
    private let paperView: NSImageView
    private var timer: Timer?

    /// Starts the animation.
    static func play(snapshot: NSImage, frame: NSRect, screen: NSScreen?) {
        let animation = NoteCloseAnimation(snapshot: snapshot, frame: frame, screen: screen)
        running.append(animation)
        animation.start()
    }

    private init(snapshot: NSImage, frame: NSRect, screen: NSScreen?) {
        noteFrame = frame
        throwStart = NSPoint(x: frame.midX, y: frame.midY - 6)
        ballDiameter = min(frame.width, frame.height) * NoteCloseAnimation.ballFraction
        trashPoint = NoteCloseAnimation.trashTarget(on: screen)

        let view = NSImageView(frame: NSRect(origin: .zero, size: frame.size))
        view.image = snapshot
        view.imageScaling = .scaleAxesIndependently
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        view.layer?.cornerCurve = .continuous
        paperView = view

        panel = NSPanel(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        panel.title = "StickyPoof"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = view
    }

    private func start() {
        panel.orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let elapsed = CACurrentMediaTime() - startTime
        // Views are repositioned every frame; implicit layer animations must
        // not fight the frame loop.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if elapsed < NoteCloseAnimation.crushDuration {
            crush(progress: elapsed / NoteCloseAnimation.crushDuration)
        } else if elapsed < NoteCloseAnimation.crushDuration + NoteCloseAnimation.fallDuration {
            throwBall(progress: (elapsed - NoteCloseAnimation.crushDuration) / NoteCloseAnimation.fallDuration)
        } else {
            finish()
        }
        CATransaction.commit()
    }

    /// Shrinks the note into a squashed ball in place.
    private func crush(progress p: CGFloat) {
        let e = NoteCloseAnimation.easeInOut(p)
        let width = noteFrame.width + (ballDiameter - noteFrame.width) * e
        let height = noteFrame.height + (ballDiameter - noteFrame.height) * e
        let squash = 0.14 * sin(.pi * e)
        let size = NSSize(width: width * (1 + squash), height: height * (1 - squash))
        setFrame(
            center: NSPoint(x: noteFrame.midX, y: noteFrame.midY - 6 * e),
            size: size
        )
        paperView.layer?.cornerRadius = min(size.width, size.height) / 2 * e
        paperView.layer?.setAffineTransform(
            CGAffineTransform(rotationAngle: NoteCloseAnimation.crushAngle * e)
        )
    }

    /// Throws the ball in a high arc toward the trash with a steady spin, then
    /// shrinks and fades it out as it drops into the bin.
    private func throwBall(progress p: CGFloat) {
        let dx = trashPoint.x - throwStart.x
        let dy = trashPoint.y - throwStart.y
        // How high the toss rises above a straight line to the bin.
        let lift = min(140, max(70, abs(dx) * 0.28))
        let center = NSPoint(
            x: throwStart.x + dx * p,
            y: throwStart.y + dy * p * p + lift * 4 * p * (1 - p)
        )
        let shrink = 1 - 0.35 * max(0, (p - 0.8) / 0.2)
        setFrame(
            center: center,
            size: NSSize(width: ballDiameter * shrink, height: ballDiameter * shrink)
        )
        paperView.layer?.cornerRadius = ballDiameter * shrink / 2
        paperView.layer?.setAffineTransform(
            CGAffineTransform(rotationAngle: NoteCloseAnimation.crushAngle + NoteCloseAnimation.spinAngle * p)
        )
        panel.alphaValue = p < 0.85 ? 1 : max(0, 1 - (p - 0.85) / 0.15)
    }

    private func setFrame(center: NSPoint, size: NSSize) {
        panel.setFrame(
            NSRect(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2,
                width: size.width,
                height: size.height
            ),
            display: true
        )
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        panel.orderOut(nil)
        panel.close()
        NoteCloseAnimation.running.removeAll { $0 === self }
    }

    // MARK: - Trash geometry

    /// Best guess at the Dock's trash icon: the trash is the Dock's last item, so
    /// aim at the end of the Dock on whichever screen edge it sits on. When the
    /// Dock is auto-hidden, aim at the empty bottom-right corner instead.
    private static func trashTarget(on screen: NSScreen?) -> NSPoint {
        guard let s = screen ?? NSScreen.main else { return NSPoint(x: 900, y: 80) }
        let full = s.frame
        let visible = s.visibleFrame

        if visible.minY > full.minY + 1 {            // Dock at the bottom
            let dockHeight = visible.minY - full.minY
            return NSPoint(x: full.maxX - max(38, dockHeight * 0.75), y: full.minY + dockHeight * 0.5)
        }
        if visible.minX > full.minX + 1 {            // Dock on the left
            let dockWidth = visible.minX - full.minX
            return NSPoint(x: full.minX + dockWidth * 0.5, y: full.minY + max(38, dockWidth * 0.75))
        }
        if visible.maxX < full.maxX - 1 {            // Dock on the right
            let dockWidth = full.maxX - visible.maxX
            return NSPoint(x: full.maxX - dockWidth * 0.5, y: full.minY + max(38, dockWidth * 0.75))
        }
        if visible.maxY < full.maxY - 1 {            // Dock at the top
            let dockHeight = full.maxY - visible.maxY
            return NSPoint(x: full.maxX - max(38, dockHeight * 0.75), y: full.maxY - dockHeight * 0.5)
        }
        return NSPoint(x: full.maxX - 70, y: full.minY + 45)   // Auto-hidden Dock
    }

    // MARK: - Easing

    private static func easeInOut(_ p: CGFloat) -> CGFloat {
        p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
    }
}
