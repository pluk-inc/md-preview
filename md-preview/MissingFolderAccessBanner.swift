//
//  MissingFolderAccessBanner.swift
//  md-preview
//

import Cocoa

/// Slim notification bar shown above the document when relative assets need
/// access to the document's parent folder.
final class MissingFolderAccessBanner: NSView {

    var onAllow: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let messageLabel = NSTextField(labelWithString: "")
    private let allowButton = NSButton(title: "Allow Access", target: nil, action: nil)
    private let dismissButton = NSButton()
    private let topSeparator = NSBox()
    private let bottomSeparator = NSBox()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    func update(folderName: String) {
        messageLabel.stringValue = "“\(folderName)” contains files this document references. Allow access to display them."
    }

    private func setUp() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        icon.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false

        messageLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
        messageLabel.textColor = .labelColor
        messageLabel.lineBreakMode = .byTruncatingMiddle
        messageLabel.maximumNumberOfLines = 1
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        allowButton.bezelStyle = .rounded
        allowButton.controlSize = .regular
        allowButton.target = self
        allowButton.action = #selector(allowTapped)
        allowButton.keyEquivalent = "\r"
        allowButton.translatesAutoresizingMaskIntoConstraints = false

        dismissButton.bezelStyle = .accessoryBar
        dismissButton.isBordered = false
        dismissButton.image = NSImage(systemSymbolName: "xmark",
                                      accessibilityDescription: "Dismiss")
        dismissButton.imagePosition = .imageOnly
        dismissButton.imageScaling = .scaleProportionallyDown
        dismissButton.contentTintColor = .secondaryLabelColor
        dismissButton.target = self
        dismissButton.action = #selector(dismissTapped)
        dismissButton.toolTip = "Dismiss"
        dismissButton.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [icon, messageLabel, allowButton, dismissButton])
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        // macOS 26 dropped the system-drawn separators around titlebar
        // accessories, so we draw our own. On macOS 15 AppKit still draws
        // them, so ours would stack and look bolder — hide them there.
        let needsManualSeparators: Bool = {
            if #available(macOS 26.0, *) { return true }
            return false
        }()

        topSeparator.boxType = .separator
        topSeparator.translatesAutoresizingMaskIntoConstraints = false
        topSeparator.isHidden = !needsManualSeparators
        addSubview(topSeparator)

        bottomSeparator.boxType = .separator
        bottomSeparator.translatesAutoresizingMaskIntoConstraints = false
        bottomSeparator.isHidden = !needsManualSeparators
        addSubview(bottomSeparator)

        NSLayoutConstraint.activate([
            topSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),
            topSeparator.topAnchor.constraint(equalTo: topAnchor),
            topSeparator.heightAnchor.constraint(equalToConstant: 1),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: topSeparator.bottomAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomSeparator.topAnchor, constant: -8),

            bottomSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomSeparator.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomSeparator.heightAnchor.constraint(equalToConstant: 1),

            dismissButton.widthAnchor.constraint(equalToConstant: 22),
            dismissButton.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    @objc private func allowTapped() {
        onAllow?()
    }

    @objc private func dismissTapped() {
        onDismiss?()
    }
}
