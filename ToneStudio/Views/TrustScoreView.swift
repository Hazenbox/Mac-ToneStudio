import Cocoa

final class TrustScoreView: NSView {
    
    // MARK: - Properties
    
    private var score: TrustScore?
    private var isExpanded: Bool = false
    
    private let scoreCircle = NSView()
    private let scoreLabel = NSTextField(labelWithString: "")
    private let certifiedLabel = NSTextField(labelWithString: "")
    private let expandButton = NSButton()
    private let breakdownContainer = NSView()
    
    // MARK: - Colors
    
    private static let excellentColor = NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)   // Green
    private static let goodColor = NSColor(red: 0.4, green: 0.75, blue: 0.4, alpha: 1)         // Light green
    private static let warningColor = NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1)       // Yellow
    private static let dangerColor = NSColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1)        // Red
    private static let cardBG = NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)
    private static let textPrimary = NSColor.white
    private static let textSecondary = NSColor(white: 0.6, alpha: 1)
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = Self.cardBG.cgColor
        layer?.cornerRadius = 12
    }
    
    // MARK: - Public API
    
    func configure(with trustScore: TrustScore) {
        self.score = trustScore
        subviews.forEach { $0.removeFromSuperview() }
        buildUI()
    }
    
    var collapsedHeight: CGFloat { 60 }
    var expandedHeight: CGFloat { 200 }
    
    func toggleExpanded() {
        isExpanded.toggle()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            breakdownContainer.animator().alphaValue = isExpanded ? 1 : 0
            breakdownContainer.animator().isHidden = !isExpanded
            
            let newHeight = isExpanded ? expandedHeight : collapsedHeight
            frame = NSRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: newHeight)
        }
        
        let image = NSImage(systemSymbolName: isExpanded ? "chevron.up" : "chevron.down", accessibilityDescription: nil)
        expandButton.image = image
    }
    
    // MARK: - UI Building
    
    private func buildUI() {
        guard let score = score else { return }
        
        let padding: CGFloat = 12
        let width = bounds.width
        
        // Header row: score circle + labels + expand button
        buildScoreCircle(score: score.overall, at: NSPoint(x: padding, y: bounds.height - padding - 36))
        buildLabels(score: score, at: NSPoint(x: padding + 44, y: bounds.height - padding - 36))
        buildExpandButton(at: NSPoint(x: width - padding - 24, y: bounds.height - padding - 30))
        
        // Breakdown container (initially hidden)
        buildBreakdownContainer(score: score)
    }
    
    private func buildScoreCircle(score: Int, at origin: NSPoint) {
        let size: CGFloat = 36
        scoreCircle.frame = NSRect(x: origin.x, y: origin.y, width: size, height: size)
        scoreCircle.wantsLayer = true
        scoreCircle.layer?.cornerRadius = size / 2
        scoreCircle.layer?.backgroundColor = colorForScore(score).cgColor
        addSubview(scoreCircle)
        
        scoreLabel.stringValue = "\(score)"
        scoreLabel.font = .systemFont(ofSize: 14, weight: .bold)
        scoreLabel.textColor = .white
        scoreLabel.alignment = .center
        scoreLabel.isBordered = false
        scoreLabel.isEditable = false
        scoreLabel.backgroundColor = .clear
        scoreLabel.frame = NSRect(x: 0, y: (size - 16) / 2, width: size, height: 16)
        scoreCircle.addSubview(scoreLabel)
    }
    
    private func buildLabels(score: TrustScore, at origin: NSPoint) {
        let statusText = score.certified ? "certified" : (score.overall >= 70 ? "review recommended" : "issues found")
        let statusColor = score.certified ? Self.excellentColor : (score.overall >= 70 ? Self.warningColor : Self.dangerColor)
        
        certifiedLabel.stringValue = statusText
        certifiedLabel.font = .systemFont(ofSize: 12, weight: .medium)
        certifiedLabel.textColor = statusColor
        certifiedLabel.isBordered = false
        certifiedLabel.isEditable = false
        certifiedLabel.backgroundColor = .clear
        certifiedLabel.frame = NSRect(x: origin.x, y: origin.y + 18, width: 150, height: 16)
        addSubview(certifiedLabel)
        
        let detailLabel = NSTextField(labelWithString: "trust score • \(score.totalViolations) issues")
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = Self.textSecondary
        detailLabel.isBordered = false
        detailLabel.isEditable = false
        detailLabel.backgroundColor = .clear
        detailLabel.frame = NSRect(x: origin.x, y: origin.y, width: 150, height: 14)
        addSubview(detailLabel)
    }
    
    private func buildExpandButton(at origin: NSPoint) {
        expandButton.frame = NSRect(x: origin.x, y: origin.y, width: 24, height: 24)
        expandButton.isBordered = false
        expandButton.bezelStyle = .shadowlessSquare
        expandButton.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Expand")
        expandButton.contentTintColor = Self.textSecondary
        expandButton.target = self
        expandButton.action = #selector(expandTapped)
        addSubview(expandButton)
    }
    
    @objc private func expandTapped() {
        toggleExpanded()
    }
    
    private func buildBreakdownContainer(score: TrustScore) {
        let padding: CGFloat = 12
        breakdownContainer.frame = NSRect(x: padding, y: padding, width: bounds.width - padding * 2, height: 120)
        breakdownContainer.wantsLayer = true
        breakdownContainer.isHidden = true
        breakdownContainer.alphaValue = 0
        addSubview(breakdownContainer)
        
        let categories: [(String, Int)] = [
            ("gender neutrality", score.breakdown.genderNeutrality),
            ("inclusivity", score.breakdown.inclusivity),
            ("cultural sensitivity", score.breakdown.culturalSensitivity),
            ("accessibility", score.breakdown.accessibility),
            ("compliance", score.breakdown.compliance),
            ("style consistency", score.breakdown.styleConsistency),
            ("brand alignment", score.breakdown.brandAlignment),
            ("readability", score.breakdown.readability)
        ]
        
        let rowHeight: CGFloat = 14
        let rowSpacing: CGFloat = 2
        var yOffset = breakdownContainer.bounds.height - rowHeight
        
        for (name, value) in categories {
            buildBreakdownRow(name: name, value: value, at: NSPoint(x: 0, y: yOffset))
            yOffset -= (rowHeight + rowSpacing)
        }
    }
    
    private func buildBreakdownRow(name: String, value: Int, at origin: NSPoint) {
        let labelWidth: CGFloat = 110
        let barWidth: CGFloat = breakdownContainer.bounds.width - labelWidth - 40
        
        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = .systemFont(ofSize: 10)
        nameLabel.textColor = Self.textSecondary
        nameLabel.isBordered = false
        nameLabel.isEditable = false
        nameLabel.backgroundColor = .clear
        nameLabel.frame = NSRect(x: origin.x, y: origin.y, width: labelWidth, height: 12)
        breakdownContainer.addSubview(nameLabel)
        
        // Progress bar background
        let barBG = NSView(frame: NSRect(x: labelWidth, y: origin.y + 2, width: barWidth, height: 8))
        barBG.wantsLayer = true
        barBG.layer?.cornerRadius = 4
        barBG.layer?.backgroundColor = NSColor(white: 0.25, alpha: 1).cgColor
        breakdownContainer.addSubview(barBG)
        
        // Progress bar fill
        let fillWidth = barWidth * CGFloat(value) / 100
        let barFill = NSView(frame: NSRect(x: labelWidth, y: origin.y + 2, width: fillWidth, height: 8))
        barFill.wantsLayer = true
        barFill.layer?.cornerRadius = 4
        barFill.layer?.backgroundColor = colorForScore(value).cgColor
        breakdownContainer.addSubview(barFill)
        
        // Value label
        let valueLabel = NSTextField(labelWithString: "\(value)")
        valueLabel.font = .systemFont(ofSize: 10, weight: .medium)
        valueLabel.textColor = colorForScore(value)
        valueLabel.isBordered = false
        valueLabel.isEditable = false
        valueLabel.backgroundColor = .clear
        valueLabel.alignment = .right
        valueLabel.frame = NSRect(x: labelWidth + barWidth + 4, y: origin.y, width: 30, height: 12)
        breakdownContainer.addSubview(valueLabel)
    }
    
    private func colorForScore(_ score: Int) -> NSColor {
        if score >= 90 { return Self.excellentColor }
        if score >= 70 { return Self.goodColor }
        if score >= 50 { return Self.warningColor }
        return Self.dangerColor
    }
}

// MARK: - Compact Trust Badge (for inline display)

final class TrustBadgeView: NSView {
    
    private let scoreLabel = NSTextField(labelWithString: "")
    private var score: Int = 0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = bounds.height / 2
        
        scoreLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        scoreLabel.textColor = .white
        scoreLabel.alignment = .center
        scoreLabel.isBordered = false
        scoreLabel.isEditable = false
        scoreLabel.backgroundColor = .clear
        addSubview(scoreLabel)
    }
    
    func configure(score: Int) {
        self.score = score
        
        let color: NSColor
        if score >= 90 {
            color = NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)
        } else if score >= 70 {
            color = NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1)
        } else {
            color = NSColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1)
        }
        
        layer?.backgroundColor = color.cgColor
        scoreLabel.stringValue = "\(score)"
        scoreLabel.frame = bounds
    }
}
