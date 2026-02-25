import Cocoa

final class ComplianceReportView: NSView {
    
    // MARK: - Properties
    
    private var validationResult: ValidationResult?
    private var readabilityGrade: Double = 8.0
    
    // MARK: - Colors
    
    private static let cardBG = NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)
    private static let sectionBG = NSColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1)
    private static let textPrimary = NSColor.white
    private static let textSecondary = NSColor(white: 0.6, alpha: 1)
    private static let successColor = NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)
    private static let warningColor = NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1)
    private static let errorColor = NSColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1)
    private static let infoColor = NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1)
    
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
    
    func configure(with result: ValidationResult, readabilityGrade: Double) {
        self.validationResult = result
        self.readabilityGrade = readabilityGrade
        subviews.forEach { $0.removeFromSuperview() }
        buildUI()
    }
    
    // MARK: - UI Building
    
    private func buildUI() {
        guard let result = validationResult else { return }
        
        let padding: CGFloat = 16
        var yOffset = bounds.height - padding
        
        // Header with overall score
        yOffset = buildHeader(at: yOffset, padding: padding, result: result)
        
        // Summary section
        yOffset = buildSummarySection(at: yOffset, padding: padding, result: result)
        
        // Violations section
        if !result.violations.isEmpty {
            yOffset = buildViolationsSection(at: yOffset, padding: padding, violations: result.violations)
        }
        
        // Readability section
        yOffset = buildReadabilitySection(at: yOffset, padding: padding)
        
        // Recommendations section
        yOffset = buildRecommendationsSection(at: yOffset, padding: padding, result: result)
    }
    
    private func buildHeader(at y: CGFloat, padding: CGFloat, result: ValidationResult) -> CGFloat {
        let headerHeight: CGFloat = 60
        let headerY = y - headerHeight
        
        // Score circle
        let scoreSize: CGFloat = 50
        let scoreView = NSView(frame: NSRect(x: padding, y: headerY + 5, width: scoreSize, height: scoreSize))
        scoreView.wantsLayer = true
        scoreView.layer?.cornerRadius = scoreSize / 2
        scoreView.layer?.backgroundColor = colorForScore(result.score).cgColor
        addSubview(scoreView)
        
        let scoreLabel = makeLabel("\(result.score)", size: 18, weight: .bold, color: .white)
        scoreLabel.alignment = .center
        scoreLabel.frame = NSRect(x: 0, y: (scoreSize - 22) / 2, width: scoreSize, height: 22)
        scoreView.addSubview(scoreLabel)
        
        // Title and status
        let titleX = padding + scoreSize + 12
        
        let titleLabel = makeLabel("compliance report", size: 16, weight: .semibold, color: Self.textPrimary)
        titleLabel.frame = NSRect(x: titleX, y: headerY + 32, width: 200, height: 20)
        addSubview(titleLabel)
        
        let statusText = result.passed ? "passed" : "needs attention"
        let statusColor = result.passed ? Self.successColor : Self.errorColor
        let statusLabel = makeLabel(statusText, size: 13, weight: .medium, color: statusColor)
        statusLabel.frame = NSRect(x: titleX, y: headerY + 10, width: 150, height: 18)
        addSubview(statusLabel)
        
        return headerY - 8
    }
    
    private func buildSummarySection(at y: CGFloat, padding: CGFloat, result: ValidationResult) -> CGFloat {
        let sectionHeight: CGFloat = 80
        let sectionY = y - sectionHeight
        
        let section = NSView(frame: NSRect(x: padding, y: sectionY, width: bounds.width - padding * 2, height: sectionHeight))
        section.wantsLayer = true
        section.layer?.backgroundColor = Self.sectionBG.cgColor
        section.layer?.cornerRadius = 8
        addSubview(section)
        
        let sectionTitle = makeLabel("summary", size: 11, weight: .semibold, color: Self.textSecondary)
        sectionTitle.frame = NSRect(x: 12, y: sectionHeight - 24, width: 100, height: 14)
        section.addSubview(sectionTitle)
        
        // Stats row
        let statsY: CGFloat = 12
        let statWidth = (section.bounds.width - 24) / 4
        
        buildStatItem(in: section, at: NSPoint(x: 12, y: statsY), 
                      value: "\(result.errorCount)", label: "errors", 
                      color: result.errorCount > 0 ? Self.errorColor : Self.textSecondary)
        
        buildStatItem(in: section, at: NSPoint(x: 12 + statWidth, y: statsY), 
                      value: "\(result.warningCount)", label: "warnings", 
                      color: result.warningCount > 0 ? Self.warningColor : Self.textSecondary)
        
        buildStatItem(in: section, at: NSPoint(x: 12 + statWidth * 2, y: statsY), 
                      value: "\(result.infoCount)", label: "suggestions", 
                      color: Self.infoColor)
        
        buildStatItem(in: section, at: NSPoint(x: 12 + statWidth * 3, y: statsY), 
                      value: "\(result.autoFixableCount)", label: "auto-fixable", 
                      color: Self.successColor)
        
        return sectionY - 12
    }
    
    private func buildStatItem(in parent: NSView, at origin: NSPoint, value: String, label: String, color: NSColor) {
        let valueLabel = makeLabel(value, size: 20, weight: .bold, color: color)
        valueLabel.frame = NSRect(x: origin.x, y: origin.y + 16, width: 60, height: 24)
        parent.addSubview(valueLabel)
        
        let labelText = makeLabel(label, size: 10, weight: .regular, color: Self.textSecondary)
        labelText.frame = NSRect(x: origin.x, y: origin.y, width: 70, height: 14)
        parent.addSubview(labelText)
    }
    
    private func buildViolationsSection(at y: CGFloat, padding: CGFloat, violations: [Violation]) -> CGFloat {
        let maxViolations = min(5, violations.count)
        let rowHeight: CGFloat = 36
        let headerHeight: CGFloat = 30
        let sectionHeight = headerHeight + CGFloat(maxViolations) * rowHeight + 8
        let sectionY = y - sectionHeight
        
        let section = NSView(frame: NSRect(x: padding, y: sectionY, width: bounds.width - padding * 2, height: sectionHeight))
        section.wantsLayer = true
        section.layer?.backgroundColor = Self.sectionBG.cgColor
        section.layer?.cornerRadius = 8
        addSubview(section)
        
        let sectionTitle = makeLabel("issues found", size: 11, weight: .semibold, color: Self.textSecondary)
        sectionTitle.frame = NSRect(x: 12, y: sectionHeight - 24, width: 100, height: 14)
        section.addSubview(sectionTitle)
        
        var rowY = sectionHeight - headerHeight - rowHeight
        for violation in violations.prefix(maxViolations) {
            buildViolationRow(in: section, at: rowY, violation: violation)
            rowY -= rowHeight
        }
        
        if violations.count > maxViolations {
            let moreLabel = makeLabel("+ \(violations.count - maxViolations) more issues", size: 11, weight: .medium, color: Self.textSecondary)
            moreLabel.frame = NSRect(x: 12, y: 8, width: 150, height: 14)
            section.addSubview(moreLabel)
        }
        
        return sectionY - 12
    }
    
    private func buildViolationRow(in parent: NSView, at y: CGFloat, violation: Violation) {
        let iconSize: CGFloat = 16
        let iconColor: NSColor
        let iconName: String
        
        switch violation.severity {
        case .error:
            iconColor = Self.errorColor
            iconName = "xmark.circle.fill"
        case .warning:
            iconColor = Self.warningColor
            iconName = "exclamationmark.triangle.fill"
        case .info:
            iconColor = Self.infoColor
            iconName = "info.circle.fill"
        }
        
        let icon = NSImageView(frame: NSRect(x: 12, y: y + 10, width: iconSize, height: iconSize))
        icon.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        icon.contentTintColor = iconColor
        parent.addSubview(icon)
        
        let textLabel = makeLabel("\"\(violation.text)\"", size: 12, weight: .medium, color: Self.textPrimary)
        textLabel.frame = NSRect(x: 36, y: y + 18, width: parent.bounds.width - 48, height: 16)
        parent.addSubview(textLabel)
        
        let suggestionLabel = makeLabel(violation.suggestion, size: 10, weight: .regular, color: Self.textSecondary)
        suggestionLabel.frame = NSRect(x: 36, y: y + 2, width: parent.bounds.width - 48, height: 14)
        parent.addSubview(suggestionLabel)
    }
    
    private func buildReadabilitySection(at y: CGFloat, padding: CGFloat) -> CGFloat {
        let sectionHeight: CGFloat = 70
        let sectionY = y - sectionHeight
        
        let section = NSView(frame: NSRect(x: padding, y: sectionY, width: bounds.width - padding * 2, height: sectionHeight))
        section.wantsLayer = true
        section.layer?.backgroundColor = Self.sectionBG.cgColor
        section.layer?.cornerRadius = 8
        addSubview(section)
        
        let sectionTitle = makeLabel("readability", size: 11, weight: .semibold, color: Self.textSecondary)
        sectionTitle.frame = NSRect(x: 12, y: sectionHeight - 24, width: 100, height: 14)
        section.addSubview(sectionTitle)
        
        let gradeColor = readabilityGrade <= 8 ? Self.successColor : (readabilityGrade <= 10 ? Self.warningColor : Self.errorColor)
        let gradeText = String(format: "grade %.0f", readabilityGrade)
        let gradeLabel = makeLabel(gradeText, size: 16, weight: .bold, color: gradeColor)
        gradeLabel.frame = NSRect(x: 12, y: 12, width: 80, height: 20)
        section.addSubview(gradeLabel)
        
        let targetText = readabilityGrade <= 8 ? "meets target (grade 8)" : "target: grade 8 or lower"
        let targetLabel = makeLabel(targetText, size: 11, weight: .regular, color: Self.textSecondary)
        targetLabel.frame = NSRect(x: 100, y: 14, width: 180, height: 16)
        section.addSubview(targetLabel)
        
        return sectionY - 12
    }
    
    private func buildRecommendationsSection(at y: CGFloat, padding: CGFloat, result: ValidationResult) -> CGFloat {
        var recommendations: [String] = []
        
        if result.errorCount > 0 {
            recommendations.append("fix \(result.errorCount) error(s) - these violate brand guidelines")
        }
        if result.warningCount > 0 {
            recommendations.append("review \(result.warningCount) warning(s) for better clarity")
        }
        if result.autoFixableCount > 0 {
            recommendations.append("use quick fix to auto-correct \(result.autoFixableCount) issue(s)")
        }
        if readabilityGrade > 8 {
            recommendations.append("simplify sentences to improve readability")
        }
        if recommendations.isEmpty {
            recommendations.append("great job! content meets all guidelines")
        }
        
        let rowHeight: CGFloat = 24
        let headerHeight: CGFloat = 30
        let sectionHeight = headerHeight + CGFloat(recommendations.count) * rowHeight + 8
        let sectionY = y - sectionHeight
        
        let section = NSView(frame: NSRect(x: padding, y: sectionY, width: bounds.width - padding * 2, height: sectionHeight))
        section.wantsLayer = true
        section.layer?.backgroundColor = Self.sectionBG.cgColor
        section.layer?.cornerRadius = 8
        addSubview(section)
        
        let sectionTitle = makeLabel("recommendations", size: 11, weight: .semibold, color: Self.textSecondary)
        sectionTitle.frame = NSRect(x: 12, y: sectionHeight - 24, width: 120, height: 14)
        section.addSubview(sectionTitle)
        
        var rowY = sectionHeight - headerHeight - rowHeight + 4
        for recommendation in recommendations {
            let bullet = makeLabel("•", size: 12, weight: .bold, color: Self.successColor)
            bullet.frame = NSRect(x: 12, y: rowY, width: 12, height: 16)
            section.addSubview(bullet)
            
            let textLabel = makeLabel(recommendation, size: 11, weight: .regular, color: Self.textPrimary)
            textLabel.frame = NSRect(x: 26, y: rowY, width: section.bounds.width - 38, height: 16)
            section.addSubview(textLabel)
            
            rowY -= rowHeight
        }
        
        return sectionY - 12
    }
    
    // MARK: - Helpers
    
    private func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.isBordered = false
        label.isEditable = false
        label.backgroundColor = .clear
        return label
    }
    
    private func colorForScore(_ score: Int) -> NSColor {
        if score >= 90 { return Self.successColor }
        if score >= 70 { return Self.warningColor }
        return Self.errorColor
    }
}
