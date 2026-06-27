import AppKit
import SwiftUI

struct KeyboardCaptureView: NSViewRepresentable {
    let onKey: (KeyInput) -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKey = onKey
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onKey = onKey
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

@MainActor
final class KeyCaptureNSView: NSView {
    var onKey: ((KeyInput) -> Void)?
    private var shiftIsPressed = false
    private var keyMonitor: Any?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installKeyMonitorIfNeeded()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        guard newWindow == nil, let keyMonitor else {
            return
        }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }

    override func keyDown(with event: NSEvent) {
        _ = handleKeyDown(event)
    }

    override func keyUp(with event: NSEvent) {
        _ = handleKeyUp(event)
    }

    override func flagsChanged(with event: NSEvent) {
        _ = handleFlagsChanged(event)
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else {
            return
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            guard let self, event.window == self.window else {
                return event
            }

            switch event.type {
            case .keyDown:
                return self.handleKeyDown(event) ? nil : event
            case .keyUp:
                return self.handleKeyUp(event) ? nil : event
            case .flagsChanged:
                return self.handleFlagsChanged(event) ? nil : event
            default:
                return event
            }
        }
    }

    @discardableResult
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let key = keyName(for: event)
        guard !key.isEmpty else { return false }
        onKey?(KeyInput(key: key, isRepeat: event.isARepeat, phase: .down))
        return true
    }

    @discardableResult
    private func handleKeyUp(_ event: NSEvent) -> Bool {
        let key = keyName(for: event)
        guard !key.isEmpty else { return false }
        onKey?(KeyInput(key: key, isRepeat: false, phase: .up))
        return true
    }

    @discardableResult
    private func handleFlagsChanged(_ event: NSEvent) -> Bool {
        let isPressed = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift)
        guard isPressed != shiftIsPressed else {
            return false
        }
        shiftIsPressed = isPressed
        if isPressed {
            onKey?(KeyInput(key: "shift", isRepeat: false, phase: .down))
        } else {
            onKey?(KeyInput(key: "shift", isRepeat: false, phase: .up))
        }
        return true
    }

    private func keyName(for event: NSEvent) -> String {
        switch event.keyCode {
        case 123:
            return "left"
        case 124:
            return "right"
        case 125:
            return "down"
        case 126:
            return "up"
        case 49:
            return "space"
        case 36:
            return "return"
        case 53:
            return "escape"
        case 56, 60:
            return "shift"
        default:
            return event.charactersIgnoringModifiers?.lowercased() ?? ""
        }
    }
}
