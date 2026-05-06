//
//  FindBar.swift
//  md-preview
//

import Cocoa

/// Slim bar shown beneath the toolbar while searching: match count,
/// previous / next chevrons, and a Done button.
final class FindBar: NSView {

    static let preferredHeight: CGFloat = 36

    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onDone: (() -> Void)?
    var onModeChanged: ((SearchMode) -> Void)?

    private let modeControl = NSSegmentedControl()
    private let countLabel = NSTextField(labelWithString: "")
    private let navigationControl = NSSegmentedControl()
    private let doneButton = NSButton(title: "Done", target: nil, action: nil)
    private let bottomSeparator = NSBox()

    private enum NavigationSegment: Int {
        case previous = 0
        case next = 1
    }

    private enum ModeSegment: Int {
        case contains = 0
        case beginsWith = 1
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    func update(matchCount: Int, currentIndex: Int) {
        if matchCount == 0 {
            countLabel.stringValue = "Not found"
        } else {
            countLabel.stringValue = "\(currentIndex) of \(matchCount)"
        }
        let hasMatches = matchCount > 0
        navigationControl.setEnabled(hasMatches, forSegment: NavigationSegment.previous.rawValue)
        navigationControl.setEnabled(hasMatches, forSegment: NavigationSegment.next.rawValue)
    }

    private func setUp() {
        countLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alignment = .right
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        configureModeControl()
        configureNavigationControl()

        doneButton.bezelStyle = .rounded
        doneButton.controlSize = .regular
        doneButton.target = self
        doneButton.action = #selector(doneTapped)
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        let leadingStack = NSStackView(views: [modeControl])
        leadingStack.orientation = .horizontal
        leadingStack.spacing = 8
        leadingStack.alignment = .centerY
        leadingStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(leadingStack)

        let trailingStack = NSStackView(views: [countLabel, navigationControl, doneButton])
        trailingStack.orientation = .horizontal
        trailingStack.spacing = 12
        trailingStack.alignment = .centerY
        trailingStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trailingStack)

        // macOS 26 dropped the system-drawn separators around titlebar
        // accessories, so we draw our own bottom rule. macOS 15 still draws
        // them, so hiding ours avoids a doubled line there.
        let needsManualSeparator: Bool = {
            if #available(macOS 26.0, *) { return true }
            return false
        }()

        bottomSeparator.boxType = .separator
        bottomSeparator.translatesAutoresizingMaskIntoConstraints = false
        bottomSeparator.isHidden = !needsManualSeparator
        addSubview(bottomSeparator)

        NSLayoutConstraint.activate([
            leadingStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            leadingStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            trailingStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            trailingStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            bottomSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomSeparator.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomSeparator.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func configureModeControl() {
        modeControl.segmentStyle = .automatic
        modeControl.trackingMode = .selectOne
        modeControl.segmentCount = 2
        modeControl.setLabel("Contains", forSegment: ModeSegment.contains.rawValue)
        modeControl.setLabel("Begins With", forSegment: ModeSegment.beginsWith.rawValue)
        modeControl.selectedSegment = ModeSegment.contains.rawValue
        modeControl.target = self
        modeControl.action = #selector(modeTapped(_:))
        modeControl.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureNavigationControl() {
        let previous = NSImage(systemSymbolName: "chevron.left",
                               accessibilityDescription: "Previous match") ?? NSImage()
        let next = NSImage(systemSymbolName: "chevron.right",
                           accessibilityDescription: "Next match") ?? NSImage()
        previous.isTemplate = true
        next.isTemplate = true

        navigationControl.segmentStyle = .rounded
        navigationControl.trackingMode = .momentary
        navigationControl.segmentCount = 2
        navigationControl.setImage(previous, forSegment: NavigationSegment.previous.rawValue)
        navigationControl.setImage(next, forSegment: NavigationSegment.next.rawValue)
        navigationControl.setImageScaling(.scaleProportionallyDown,
                                          forSegment: NavigationSegment.previous.rawValue)
        navigationControl.setImageScaling(.scaleProportionallyDown,
                                          forSegment: NavigationSegment.next.rawValue)
        navigationControl.target = self
        navigationControl.action = #selector(navigationTapped(_:))
        navigationControl.translatesAutoresizingMaskIntoConstraints = false
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Self.preferredHeight)
    }

    @objc private func navigationTapped(_ sender: NSSegmentedControl) {
        switch NavigationSegment(rawValue: sender.selectedSegment) {
        case .previous: onPrevious?()
        case .next: onNext?()
        case .none: break
        }
    }

    @objc private func modeTapped(_ sender: NSSegmentedControl) {
        let mode: SearchMode = sender.selectedSegment == ModeSegment.beginsWith.rawValue
            ? .beginsWith
            : .contains
        onModeChanged?(mode)
    }

    @objc private func doneTapped() { onDone?() }
}
