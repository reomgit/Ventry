import SwiftUI

/// Captures mouse events on macOS and forwards them down the responder chain so SwiftUI
/// gestures (like drag/drop) can still work.
struct MouseEventCaptureView: NSViewRepresentable {
    let onMouseDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        CaptureNSView(onMouseDown: onMouseDown)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? CaptureNSView else { return }
        view.onMouseDown = onMouseDown
    }

    private final class CaptureNSView: NSView {
        var onMouseDown: (NSEvent) -> Void

        init(onMouseDown: @escaping (NSEvent) -> Void) {
            self.onMouseDown = onMouseDown
            super.init(frame: .zero)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            self
        }

        override func mouseDown(with event: NSEvent) {
            onMouseDown(event)
            nextResponder?.mouseDown(with: event)
        }

        override func mouseDragged(with event: NSEvent) {
            nextResponder?.mouseDragged(with: event)
        }

        override func mouseUp(with event: NSEvent) {
            nextResponder?.mouseUp(with: event)
        }

        override func rightMouseDown(with event: NSEvent) {
            nextResponder?.rightMouseDown(with: event)
        }

        override func rightMouseUp(with event: NSEvent) {
            nextResponder?.rightMouseUp(with: event)
        }
    }
}

