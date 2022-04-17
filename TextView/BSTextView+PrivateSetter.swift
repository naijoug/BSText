//
//  BSText+PrivateSet.swift
//  BSText
//
//  Created by naijoug on 2022/4/16.
//

import UIKit

// MARK: - Private Setter

extension BSTextView {
    
    func _setText(_ text: String?) {
        if _text == text {
            return
        }
        willChangeValue(forKey: "text")
        _text = text ?? ""
        didChangeValue(forKey: "text")
        accessibilityLabel = _text
    }
    
    func _setFont(_ font: UIFont?) {
        if _font == font {
            return
        }
        willChangeValue(forKey: "font")
        _font = font ?? BSTextView._defaultFont
        didChangeValue(forKey: "font")
    }
    
    func _setTextColor(_ textColor: UIColor?) {
        if _textColor === textColor {
            return
        }
        if _textColor != nil && textColor != nil {
            if CFGetTypeID(_textColor!.cgColor) == CFGetTypeID(textColor!.cgColor) && CFGetTypeID(_textColor!.cgColor) == CGColor.typeID {
                if _textColor == textColor {
                    return
                }
            }
        }
        willChangeValue(forKey: "textColor")
        _textColor = textColor
        didChangeValue(forKey: "textColor")
    }
    
    func _setTextAlignment(_ textAlignment: NSTextAlignment) {
        if _textAlignment == textAlignment {
            return
        }
        willChangeValue(forKey: "textAlignment")
        _textAlignment = textAlignment
        didChangeValue(forKey: "textAlignment")
    }
    
    func _setDataDetectorTypes(_ dataDetectorTypes: UIDataDetectorTypes) {
        if _dataDetectorTypes == dataDetectorTypes {
            return
        }
        willChangeValue(forKey: "dataDetectorTypes")
        _dataDetectorTypes = dataDetectorTypes
        didChangeValue(forKey: "dataDetectorTypes")
    }
    
    func _setLinkTextAttributes(_ linkTextAttributes: [NSAttributedString.Key : Any]?) {
        let dic1 = _linkTextAttributes as NSDictionary?, dic2 = linkTextAttributes as NSDictionary?
        if dic1 == dic2 || dic1?.isEqual(dic2) ?? false {
            return
        }
        willChangeValue(forKey: "linkTextAttributes")
        _linkTextAttributes = linkTextAttributes
        didChangeValue(forKey: "linkTextAttributes")
    }
    
    func _setHighlightTextAttributes(_ highlightTextAttributes: [NSAttributedString.Key : Any]?) {
        let dic1 = _highlightTextAttributes as NSDictionary?, dic2 = highlightTextAttributes as NSDictionary?
        if dic1 == dic2 || dic1?.isEqual(dic2) ?? false {
            return
        }
        willChangeValue(forKey: "highlightTextAttributes")
        _highlightTextAttributes = highlightTextAttributes
        didChangeValue(forKey: "highlightTextAttributes")
    }
    
    func _setTextParser(_ textParser: TextParser?) {
        if _textParser === textParser || _textParser?.isEqual(textParser) ?? false {
            return
        }
        willChangeValue(forKey: "textParser")
        _textParser = textParser
        didChangeValue(forKey: "textParser")
    }
    
    func _setAttributedText(_ attributedText: NSAttributedString?) {
        if _attributedText == attributedText {
            return
        }
        willChangeValue(forKey: "attributedText")
        _attributedText = attributedText ?? NSMutableAttributedString()
        didChangeValue(forKey: "attributedText")
    }
    
    func _setTextContainerInset(_ textContainerInset: UIEdgeInsets) {
        if _textContainerInset == textContainerInset {
            return
        }
        willChangeValue(forKey: "textContainerInset")
        _textContainerInset = textContainerInset
        didChangeValue(forKey: "textContainerInset")
    }
    
    func _setExclusionPaths(_ exclusionPaths: [UIBezierPath]?) {
        if _exclusionPaths == exclusionPaths {
            return
        }
        willChangeValue(forKey: "exclusionPaths")
        _exclusionPaths = exclusionPaths
        didChangeValue(forKey: "exclusionPaths")
    }
    
    func _setVerticalForm(_ verticalForm: Bool) {
        if _verticalForm == verticalForm {
            return
        }
        willChangeValue(forKey: "isVerticalForm")
        _verticalForm = verticalForm
        didChangeValue(forKey: "isVerticalForm")
    }
    
    func _setLinePositionModifier(_ linePositionModifier: TextLinePositionModifier?) {
        if _linePositionModifier === linePositionModifier {
            return
        }
        willChangeValue(forKey: "linePositionModifier")
        _linePositionModifier = linePositionModifier
        didChangeValue(forKey: "linePositionModifier")
    }
    
    func _setSelectedRange(_ selectedRange: NSRange) {
        if NSEqualRanges(_selectedRange, selectedRange) {
            return
        }
        willChangeValue(forKey: "selectedRange")
        _selectedRange = selectedRange
        didChangeValue(forKey: "selectedRange")
        
        _outerDelegate?.textViewDidChangeSelection?(self)
    }
    
    func _setTypingAttributes(_ typingAttributes: [NSAttributedString.Key : Any]?) {
        let dic1 = _typingAttributes as NSDictionary?, dic2 = typingAttributes as NSDictionary?
        if dic1 == dic2 || dic1?.isEqual(dic2) ?? false {
            return
        }
        willChangeValue(forKey: "typingAttributes")
        _typingAttributes = typingAttributes
        didChangeValue(forKey: "typingAttributes")
    }
    
}
