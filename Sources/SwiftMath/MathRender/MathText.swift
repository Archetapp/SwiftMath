//
//  MathText.swift
//  SwiftMath
//
//  A SwiftUI view that renders mixed text and LaTeX content.
//  Supports inline ($...$) and display ($$...$$) math delimiters.
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Component Types

/// Represents a parsed component of text - either plain text or a math equation.
public struct MathComponent: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let text: String
    public let type: ComponentType

    public enum ComponentType: Equatable, Sendable {
        case text
        case inlineMath      // $...$
        case displayMath     // $$...$$
        case blockMath       // \[...\]
        case parenMath       // \(...\)

        var isInline: Bool {
            switch self {
            case .text, .inlineMath, .parenMath:
                return true
            case .displayMath, .blockMath:
                return false
            }
        }

        var isMath: Bool {
            self != .text
        }
    }

    /// The raw LaTeX without delimiters
    public var mathContent: String {
        text
    }
}

// MARK: - Parser

/// Parses text containing mixed content and LaTeX delimiters.
public struct MathParser: Sendable {

    /// Delimiter definitions in order of precedence (longer delimiters first)
    private static let delimiters: [Delimiter] = [
        Delimiter(left: "$$", right: "$$", type: .displayMath),
        Delimiter(left: "\\[", right: "\\]", type: .blockMath),
        Delimiter(left: "\\(", right: "\\)", type: .parenMath),
        Delimiter(left: "$", right: "$", type: .inlineMath)
    ]

    private struct Delimiter: Sendable {
        let left: String
        let right: String
        let type: MathComponent.ComponentType
    }

    /// Parses input text into an array of components.
    public static func parse(_ input: String) -> [MathComponent] {
        var components: [MathComponent] = []
        var remaining = input[...]
        var textBuffer = ""

        while !remaining.isEmpty {
            var foundDelimiter = false

            // Try each delimiter type
            for delimiter in delimiters {
                if remaining.hasPrefix(delimiter.left) {
                    // Check for escape sequence
                    if !textBuffer.isEmpty && textBuffer.last == "\\" {
                        // Escaped delimiter, treat as text
                        textBuffer.removeLast()
                        textBuffer += delimiter.left
                        remaining = remaining.dropFirst(delimiter.left.count)
                        foundDelimiter = true
                        break
                    }

                    // Flush any accumulated text
                    if !textBuffer.isEmpty {
                        components.append(MathComponent(text: textBuffer, type: .text))
                        textBuffer = ""
                    }

                    // Find the closing delimiter
                    let afterOpening = remaining.dropFirst(delimiter.left.count)
                    if let closeRange = afterOpening.range(of: delimiter.right) {
                        let mathContent = String(afterOpening[..<closeRange.lowerBound])
                        components.append(MathComponent(text: mathContent, type: delimiter.type))
                        remaining = afterOpening[closeRange.upperBound...]
                    } else {
                        // No closing delimiter found, treat as text
                        textBuffer += delimiter.left
                        remaining = afterOpening
                    }
                    foundDelimiter = true
                    break
                }
            }

            if !foundDelimiter {
                textBuffer.append(remaining.removeFirst())
            }
        }

        // Flush remaining text
        if !textBuffer.isEmpty {
            components.append(MathComponent(text: textBuffer, type: .text))
        }

        return components
    }
}

// MARK: - SwiftUI Views

#if os(iOS)

/// A SwiftUI view that renders mixed text and LaTeX math expressions.
public struct MathText: View {
    private let components: [MathComponent]
    private var fontSize: CGFloat
    private var textColor: Color
    private var textAlignment: MTTextAlignment
    private var mathFont: MathFont
    private var isBold: Bool

    public init(_ text: String) {
        self.components = MathParser.parse(text)
        self.fontSize = 17
        self.textColor = .primary
        self.textAlignment = .left
        self.mathFont = .xitsFont  // XITS is similar to STIX used by MathJax
        self.isBold = false
    }

    private init(components: [MathComponent], fontSize: CGFloat, textColor: Color, textAlignment: MTTextAlignment, mathFont: MathFont, isBold: Bool) {
        self.components = components
        self.fontSize = fontSize
        self.textColor = textColor
        self.textAlignment = textAlignment
        self.mathFont = mathFont
        self.isBold = isBold
    }

    public var body: some View {
        if hasDisplayMath {
            // Vertical layout for display math
            VStack(alignment: horizontalAlignment, spacing: 8) {
                ForEach(groupedComponents) { group in
                    if group.isInlineGroup {
                        inlineContent(for: group.components)
                    } else if let component = group.components.first {
                        mathView(for: component)
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                    }
                }
            }
        } else {
            // Inline layout for text with inline math only
            inlineContent(for: components)
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private func inlineContent(for components: [MathComponent]) -> some View {
        // Use a flow layout that wraps content
        FlowLayout(spacing: 2) {
            ForEach(flattenedInlineElements(from: components)) { element in
                switch element.content {
                case .text(let text):
                    Text(text)
                        .font(.system(size: fontSize))
                        .foregroundColor(textColor)
                case .math(let latex):
                    MathLabelView(
                        latex: latex,
                        fontSize: fontSize,
                        textColor: UIColor(textColor),
                        mode: .text,
                        mathFont: mathFont,
                        isBold: isBold
                    )
                }
            }
        }
    }

    private func flattenedInlineElements(from components: [MathComponent]) -> [InlineElement] {
        var elements: [InlineElement] = []
        for component in components {
            if component.type == .text {
                // Split text by whitespace to allow word-level wrapping
                let words = component.text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isWhitespace })
                for (index, word) in words.enumerated() {
                    if !word.isEmpty {
                        elements.append(InlineElement(content: .text(String(word))))
                    }
                    // Add space between words (except after last word)
                    if index < words.count - 1 {
                        elements.append(InlineElement(content: .text(" ")))
                    }
                }
            } else {
                elements.append(InlineElement(content: .math(component.mathContent)))
            }
        }
        return elements
    }

    @ViewBuilder
    private func mathView(for component: MathComponent) -> some View {
        MathLabelView(
            latex: component.mathContent,
            fontSize: fontSize * 1.2, // Display math slightly larger
            textColor: UIColor(textColor),
            mode: .display,
            mathFont: mathFont,
            isBold: isBold
        )
    }

    // MARK: - Helpers

    private var hasDisplayMath: Bool {
        components.contains { !$0.type.isInline }
    }

    private var horizontalAlignment: HorizontalAlignment {
        switch textAlignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    private var frameAlignment: Alignment {
        switch textAlignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    private var groupedComponents: [ComponentGroup] {
        var groups: [ComponentGroup] = []
        var currentInlineComponents: [MathComponent] = []

        for component in components {
            if component.type.isInline {
                currentInlineComponents.append(component)
            } else {
                if !currentInlineComponents.isEmpty {
                    groups.append(ComponentGroup(components: currentInlineComponents, isInlineGroup: true))
                    currentInlineComponents = []
                }
                groups.append(ComponentGroup(components: [component], isInlineGroup: false))
            }
        }

        if !currentInlineComponents.isEmpty {
            groups.append(ComponentGroup(components: currentInlineComponents, isInlineGroup: true))
        }

        return groups
    }

    // MARK: - Modifiers

    public func fontSize(_ size: CGFloat) -> MathText {
        MathText(components: components, fontSize: size, textColor: textColor, textAlignment: textAlignment, mathFont: mathFont, isBold: isBold)
    }

    public func foregroundColor(_ color: Color) -> MathText {
        MathText(components: components, fontSize: fontSize, textColor: color, textAlignment: textAlignment, mathFont: mathFont, isBold: isBold)
    }

    public func textAlignment(_ alignment: MTTextAlignment) -> MathText {
        MathText(components: components, fontSize: fontSize, textColor: textColor, textAlignment: alignment, mathFont: mathFont, isBold: isBold)
    }

    public func mathFont(_ font: MathFont) -> MathText {
        MathText(components: components, fontSize: fontSize, textColor: textColor, textAlignment: textAlignment, mathFont: font, isBold: isBold)
    }

    public func bold(_ enabled: Bool = true) -> MathText {
        MathText(components: components, fontSize: fontSize, textColor: textColor, textAlignment: textAlignment, mathFont: mathFont, isBold: enabled)
    }
}

// MARK: - Supporting Types

private struct ComponentGroup: Identifiable {
    let id = UUID()
    let components: [MathComponent]
    let isInlineGroup: Bool
}

private struct InlineElement: Identifiable {
    let id = UUID()
    let content: Content

    enum Content {
        case text(String)
        case math(String)
    }
}

/// A simple flow layout for inline content
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return (CGSize(width: totalWidth, height: currentY + lineHeight), positions)
    }
}

/// SwiftUI wrapper that pre-calculates size for MTMathUILabel
private struct MathLabelView: View {
    let latex: String
    let fontSize: CGFloat
    let textColor: UIColor
    let mode: MTMathUILabelMode
    let mathFont: MathFont
    let isBold: Bool

    var body: some View {
        let size = calculateSize()
        MathLabelRepresentable(
            latex: latex,
            fontSize: fontSize,
            textColor: textColor,
            mode: mode,
            mathFont: mathFont
        )
        .frame(width: size.width, height: size.height)
    }

    private func calculateSize() -> CGSize {
        // Create a temporary label to measure the content
        let label = MTMathUILabel()
        label.labelMode = mode
        if let font = MTFontManager.fontManager.font(withName: mathFont.rawValue, size: fontSize) {
            label.font = font
        }
        label.latex = latex
        label.fontSize = fontSize

        let size = label.sizeThatFits(.zero)
        // Add generous padding to prevent clipping of superscripts (like degree symbols)
        // Superscripts extend above the normal ascent, so we need extra top padding
        let verticalPadding: CGFloat = fontSize * 0.5  // Scale with font size
        let horizontalPadding: CGFloat = fontSize * 0.2
        return CGSize(
            width: max(size.width + horizontalPadding, 1),
            height: max(size.height + verticalPadding, 1)
        )
    }
}

/// The actual UIViewRepresentable for MTMathUILabel
private struct MathLabelRepresentable: UIViewRepresentable {
    let latex: String
    let fontSize: CGFloat
    let textColor: UIColor
    let mode: MTMathUILabelMode
    let mathFont: MathFont

    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.labelMode = mode
        label.clipsToBounds = false
        label.backgroundColor = .clear
        if let font = MTFontManager.fontManager.font(withName: mathFont.rawValue, size: fontSize) {
            label.font = font
        }
        label.latex = latex
        label.fontSize = fontSize
        label.textColor = textColor
        return label
    }

    func updateUIView(_ uiView: MTMathUILabel, context: Context) {
        if let font = MTFontManager.fontManager.font(withName: mathFont.rawValue, size: fontSize) {
            uiView.font = font
        }
        uiView.latex = latex
        uiView.fontSize = fontSize
        uiView.textColor = textColor
        uiView.labelMode = mode
    }
}

#elseif os(macOS)

/// A SwiftUI view that renders mixed text and LaTeX math expressions (macOS).
public struct MathText: View {
    private let components: [MathComponent]
    private var fontSize: CGFloat
    private var textColor: Color
    private var textAlignment: MTTextAlignment
    private var mathFont: MathFont
    private var isBold: Bool

    public init(_ text: String) {
        self.components = MathParser.parse(text)
        self.fontSize = 17
        self.textColor = .primary
        self.textAlignment = .left
        self.mathFont = .xitsFont
        self.isBold = false
    }

    private init(components: [MathComponent], fontSize: CGFloat, textColor: Color, textAlignment: MTTextAlignment, mathFont: MathFont, isBold: Bool) {
        self.components = components
        self.fontSize = fontSize
        self.textColor = textColor
        self.textAlignment = textAlignment
        self.mathFont = mathFont
        self.isBold = isBold
    }

    public var body: some View {
        if hasDisplayMath {
            VStack(alignment: horizontalAlignment, spacing: 8) {
                ForEach(groupedComponents) { group in
                    if group.isInlineGroup {
                        inlineContent(for: group.components)
                    } else if let component = group.components.first {
                        mathView(for: component)
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                    }
                }
            }
        } else {
            inlineContent(for: components)
        }
    }

    @ViewBuilder
    private func inlineContent(for components: [MathComponent]) -> some View {
        MacFlowLayout(spacing: 2) {
            ForEach(flattenedInlineElements(from: components)) { element in
                switch element.content {
                case .text(let text):
                    Text(text)
                        .font(.system(size: fontSize))
                        .foregroundColor(textColor)
                case .math(let latex):
                    MacMathLabelView(
                        latex: latex,
                        fontSize: fontSize,
                        textColor: NSColor(textColor),
                        mode: .text,
                        mathFont: mathFont,
                        isBold: isBold
                    )
                }
            }
        }
    }

    private func flattenedInlineElements(from components: [MathComponent]) -> [MacInlineElement] {
        var elements: [MacInlineElement] = []
        for component in components {
            if component.type == .text {
                let words = component.text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isWhitespace })
                for (index, word) in words.enumerated() {
                    if !word.isEmpty {
                        elements.append(MacInlineElement(content: .text(String(word))))
                    }
                    if index < words.count - 1 {
                        elements.append(MacInlineElement(content: .text(" ")))
                    }
                }
            } else {
                elements.append(MacInlineElement(content: .math(component.mathContent)))
            }
        }
        return elements
    }

    @ViewBuilder
    private func mathView(for component: MathComponent) -> some View {
        MacMathLabelView(
            latex: component.mathContent,
            fontSize: fontSize * 1.2,
            textColor: NSColor(textColor),
            mode: .display,
            mathFont: mathFont,
            isBold: isBold
        )
    }

    private var hasDisplayMath: Bool {
        components.contains { !$0.type.isInline }
    }

    private var horizontalAlignment: HorizontalAlignment {
        switch textAlignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    private var frameAlignment: Alignment {
        switch textAlignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    private var groupedComponents: [ComponentGroup] {
        var groups: [ComponentGroup] = []
        var currentInlineComponents: [MathComponent] = []

        for component in components {
            if component.type.isInline {
                currentInlineComponents.append(component)
            } else {
                if !currentInlineComponents.isEmpty {
                    groups.append(ComponentGroup(components: currentInlineComponents, isInlineGroup: true))
                    currentInlineComponents = []
                }
                groups.append(ComponentGroup(components: [component], isInlineGroup: false))
            }
        }

        if !currentInlineComponents.isEmpty {
            groups.append(ComponentGroup(components: currentInlineComponents, isInlineGroup: true))
        }

        return groups
    }

    public func fontSize(_ size: CGFloat) -> MathText {
        MathText(components: components, fontSize: size, textColor: textColor, textAlignment: textAlignment, mathFont: mathFont, isBold: isBold)
    }

    public func foregroundColor(_ color: Color) -> MathText {
        MathText(components: components, fontSize: fontSize, textColor: color, textAlignment: textAlignment, mathFont: mathFont, isBold: isBold)
    }

    public func textAlignment(_ alignment: MTTextAlignment) -> MathText {
        MathText(components: components, fontSize: fontSize, textColor: textColor, textAlignment: alignment, mathFont: mathFont, isBold: isBold)
    }

    public func mathFont(_ font: MathFont) -> MathText {
        MathText(components: components, fontSize: fontSize, textColor: textColor, textAlignment: textAlignment, mathFont: font, isBold: isBold)
    }

    public func bold(_ enabled: Bool = true) -> MathText {
        MathText(components: components, fontSize: fontSize, textColor: textColor, textAlignment: textAlignment, mathFont: mathFont, isBold: enabled)
    }
}

private struct ComponentGroup: Identifiable {
    let id = UUID()
    let components: [MathComponent]
    let isInlineGroup: Bool
}

private struct MacInlineElement: Identifiable {
    let id = UUID()
    let content: Content

    enum Content {
        case text(String)
        case math(String)
    }
}

private struct MacFlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return (CGSize(width: totalWidth, height: currentY + lineHeight), positions)
    }
}

/// SwiftUI wrapper that pre-calculates size for MTMathUILabel (macOS)
private struct MacMathLabelView: View {
    let latex: String
    let fontSize: CGFloat
    let textColor: NSColor
    let mode: MTMathUILabelMode
    let mathFont: MathFont
    let isBold: Bool

    var body: some View {
        let size = calculateSize()
        MacMathLabelRepresentable(
            latex: latex,
            fontSize: fontSize,
            textColor: textColor,
            mode: mode,
            mathFont: mathFont
        )
        .frame(width: size.width, height: size.height)
    }

    private func calculateSize() -> CGSize {
        let label = MTMathUILabel()
        label.labelMode = mode
        if let font = MTFontManager.fontManager.font(withName: mathFont.rawValue, size: fontSize) {
            label.font = font
        }
        label.latex = latex
        label.fontSize = fontSize

        let size = label.sizeThatFits(.zero)
        // Add generous padding to prevent clipping of superscripts (like degree symbols)
        let verticalPadding: CGFloat = fontSize * 0.5
        let horizontalPadding: CGFloat = fontSize * 0.2
        return CGSize(
            width: max(size.width + horizontalPadding, 1),
            height: max(size.height + verticalPadding, 1)
        )
    }
}

private struct MacMathLabelRepresentable: NSViewRepresentable {
    let latex: String
    let fontSize: CGFloat
    let textColor: NSColor
    let mode: MTMathUILabelMode
    let mathFont: MathFont

    func makeNSView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.labelMode = mode
        if let font = MTFontManager.fontManager.font(withName: mathFont.rawValue, size: fontSize) {
            label.font = font
        }
        label.latex = latex
        label.fontSize = fontSize
        label.textColor = textColor
        return label
    }

    func updateNSView(_ nsView: MTMathUILabel, context: Context) {
        if let font = MTFontManager.fontManager.font(withName: mathFont.rawValue, size: fontSize) {
            nsView.font = font
        }
        nsView.latex = latex
        nsView.fontSize = fontSize
        nsView.textColor = textColor
        nsView.labelMode = mode
    }
}

#endif
