//
//  BSTextView+UITextInput.swift
//  BSText
//
//  Created by naijoug on 2022/4/16.
//

import Foundation

// MARK: - UIKeyInput

extension BSTextView {
    
    open var hasText: Bool {
        return _innerText.length > 0
    }
    
    open func insertText(_ text: String) {
        if text == "" {
            return
        }
        if !NSEqualRanges(_lastTypeRange ?? NSMakeRange(0, 0), _selectedTextRange.asRange) {
            _saveToUndoStack()
            _resetRedoStack()
        }
        replace(_selectedTextRange, withText: text)
    }
    
    open func deleteBackward() {
        _updateIfNeeded()
        var range: NSRange = _selectedTextRange.asRange
        if range.location == 0 && range.length == 0 {
            return
        }
        state.typingAttributesOnce = false
        
        // test if there's 'TextBinding' before the caret
        if !state.deleteConfirm && range.length == 0 && range.location > 0 {
            var effectiveRange = NSRange(location: 0, length: 0)
            let binding = _innerText.attribute(NSAttributedString.Key(rawValue: TextAttribute.textBindingAttributeName), at: range.location - 1, longestEffectiveRange: &effectiveRange, in: NSRange(location: 0, length: _innerText.length)) as? TextBinding
            if binding != nil && binding?.deleteConfirm != nil {
                state.deleteConfirm = true
                _inputDelegate?.selectionWillChange(self)
                _selectedTextRange = TextRange(range: effectiveRange)
                _selectedTextRange = _correctedTextRange(_selectedTextRange)!
                _inputDelegate?.selectionDidChange(self)
                
                _updateOuterProperties()
                _updateSelectionView()
                return
            }
        }
        
        state.deleteConfirm = false
        if range.length == 0 {
            let extendRange = _innerLayout?.textRange(byExtending: _selectedTextRange.end, in: UITextLayoutDirection.left, offset: 1)
            if _isTextRangeValid(extendRange) {
                range = extendRange!.asRange
            }
        }
        if let lastTypeRange = _lastTypeRange, !NSEqualRanges(lastTypeRange, _selectedTextRange.asRange) {
            _saveToUndoStack()
            _resetRedoStack()
        }
        replace(TextRange(range: range), withText: "")
    }
    
}

// MARK: - UITextInput

extension BSTextView {
    
    // MARK: Methods for manipulating text
    
    open func text(in range: UITextRange) -> String? {
        guard var range = range as? TextRange else {
            return ""
        }
        guard let r = _correctedTextRange(range) else {
            return ""
        }
        range = r
        let tmpstr = _innerText.attributedSubstring(from: range.asRange)
        return tmpstr.string
    }
    
    open func replace(_ range: UITextRange, withText text: String) {
        
        var range = range as! TextRange
        let text = text
        
        if range.asRange.length == 0 && text == "" {
            return
        }
        range = _correctedTextRange(range)!
        
        if let d = _outerDelegate {
            if let should = d.textView?(self, shouldChangeTextIn: range.asRange, replacementText: text), should == false {
                return
            }
        }
        
        var useInnerAttributes = false
        if _innerText.length > 0 {
            if range.start.offset == 0 && range.end.offset == _innerText.length {
                if text == "" {
                    var attrs = _innerText.bs_attributes(at: 0)
                    for k in NSMutableAttributedString.bs_allDiscontinuousAttributeKeys() {
                        attrs?.removeValue(forKey: k)
                    }
                    _typingAttributesHolder.bs_attributes = attrs
                }
            }
        } else {
            // no text
            useInnerAttributes = true
        }
        var applyTypingAttributes = false
        if state.typingAttributesOnce {
            state.typingAttributesOnce = false
            if !useInnerAttributes {
                if range.asRange.length == 0 && text != "" {
                    applyTypingAttributes = true
                }
            }
        }
        
        state.selectedWithoutEdit = false
        state.deleteConfirm = false
        _endTouchTracking()
        _hideMenu()
        
        _replace(range, withText: text, notifyToDelegate: true)
        if useInnerAttributes {
            _innerText.bs_setAttributes(_typingAttributesHolder.bs_attributes)
        } else if applyTypingAttributes {
            let newRange = NSRange(location: range.asRange.location, length: text.length)
            for (key, obj) in _typingAttributesHolder.bs_attributes ?? [:] {
                self._innerText.bs_set(attribute: key, value: obj, range: newRange)
            }
        }
        _parseText()
        _updateOuterProperties()
        _update()
        
        if isFirstResponder {
            _scrollRangeToVisible(_selectedTextRange)
        }
        
        _outerDelegate?.textViewDidChange?(self)
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: BSTextView.textViewTextDidChangeNotification), object: self)
        
        _lastTypeRange = _selectedTextRange.asRange
    }
    
    // MARK: markedText
    
    /*
     Replace current markedText with the new markedText
     @param markedText     New marked text.
     @param selectedRange  The range from the '_markedTextRange'
     */
    public func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        let markedText = markedText ?? ""
        _updateIfNeeded()
        _endTouchTracking()
        _hideMenu()
        
        if let d = _outerDelegate {
            let r = markedTextRange as? TextRange
            let range = (r != nil) ? r!.asRange : NSRange(location: _selectedTextRange.end.offset, length: 0)
            
            if let should = d.textView?(self, shouldChangeTextIn: range, replacementText: markedText), should == false {
                return
            }
        }
        
        if !NSEqualRanges(_lastTypeRange!, _selectedTextRange.asRange) {
            _saveToUndoStack()
            _resetRedoStack()
        }
        
        var needApplyHolderAttribute = false
        if _innerText.length > 0 && (markedTextRange != nil) {
            _updateAttributesHolder()
        } else {
            needApplyHolderAttribute = true
        }
        
        if _selectedTextRange.asRange.length > 0 {
            replace(_selectedTextRange, withText: "")
        }
        
        _inputDelegate?.textWillChange(self)
        _inputDelegate?.selectionWillChange(self)
        
        if markedTextRange == nil {
            markedTextRange = TextRange(range: NSRange(location: _selectedTextRange.end.offset, length: markedText.length))
            let subRange = NSRange(location: _selectedTextRange.end.offset, length: 0)
            _innerText.replaceCharacters(in: subRange, with: markedText)
            _selectedTextRange = TextRange(range: NSRange(location: _selectedTextRange.start.offset + selectedRange.location, length: selectedRange.length))
        } else {
            markedTextRange = _correctedTextRange(markedTextRange as? TextRange)!
            let subRange = (markedTextRange as! TextRange).asRange
            _innerText.replaceCharacters(in: subRange, with: markedText)
            markedTextRange = TextRange(range: NSRange(location: (markedTextRange as! TextRange).start.offset, length: markedText.length))
            _selectedTextRange = TextRange(range: NSRange(location: (markedTextRange as! TextRange).start.offset + selectedRange.location, length: selectedRange.length))
        }
        
        _selectedTextRange = _correctedTextRange(_selectedTextRange)!
        markedTextRange = _correctedTextRange(markedTextRange as? TextRange)
        if (markedTextRange as! TextRange).asRange.length == 0 {
            markedTextRange = nil
        } else {
            if needApplyHolderAttribute {
                _innerText.setAttributes(_typingAttributesHolder.bs_attributes, range: (markedTextRange as! TextRange).asRange)
            }
            _innerText.bs_removeDiscontinuousAttributes(in: (markedTextRange as! TextRange).asRange)
        }
        
        _inputDelegate?.selectionDidChange(self)
        _inputDelegate?.textDidChange(self)
        
        _updateOuterProperties()
        _updateLayout()
        _updateSelectionView()
        _scrollRangeToVisible(_selectedTextRange)
        
        _outerDelegate?.textViewDidChange?(self)
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: BSTextView.textViewTextDidChangeNotification), object: self)
        
        _lastTypeRange = _selectedTextRange.asRange
    }
    
    public func unmarkText() {
        markedTextRange = nil
        _endTouchTracking()
        _hideMenu()
        if _parseText() {
            state.needUpdate = true
        }
        
        _updateIfNeeded()
        _updateOuterProperties()
        _updateSelectionView()
        _scrollRangeToVisible(_selectedTextRange)
    }
    
    // MARK: The end and beginning of the the text document
    
    public var beginningOfDocument: UITextPosition {
        return TextPosition(offset: 0)
    }
    
    public var endOfDocument: UITextPosition {
        return TextPosition(offset: _innerText.length)
    }
    
    // MARK: Methods for creating ranges and positions
    
    open func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let p = fromPosition as? TextPosition else {
            return nil
        }
        return TextRange(start: p, end: toPosition as! TextPosition)
    }
    
    public func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        if offset == 0 {
            return position
        }
        
        let location = (position as! TextPosition).offset
        var newLocation: Int = location + offset
        if newLocation < 0 || newLocation > _innerText.length {
            return nil
        }
        
        if newLocation != 0 && newLocation != _innerText.length {
            // fix emoji
            _updateIfNeeded()
            let extendRange: TextRange? = _innerLayout?.textRange(byExtending: TextPosition(offset: newLocation))
            if extendRange?.asRange.length ?? 0 > 0 {
                if offset < 0 {
                    newLocation = extendRange?.start.offset ?? 0
                } else {
                    newLocation = extendRange?.end.offset ?? 0
                }
            }
        }
        
        let p = TextPosition(offset: newLocation)
        return _correctedTextPosition(p)
    }
    
    public func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        _updateIfNeeded()
        let range: TextRange? = _innerLayout?.textRange(byExtending: position as? TextPosition, in: direction, offset: offset)
        
        var forward: Bool
        if _innerContainer.isVerticalForm {
            forward = direction == .left || direction == .down
        } else {
            forward = direction == .down || direction == .right
        }
        if !forward && offset < 0 {
            forward = !forward
        }
        
        var newPosition: TextPosition? = forward ? range?.end : range?.start
        if (newPosition?.offset)! > _innerText.length {
            newPosition = TextPosition(offset: _innerText.length, affinity: TextAffinity.backward)
        }
        
        return _correctedTextPosition(newPosition)
    }
    
    // MARK: Simple evaluation of positions
    
    public func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        return (position as? TextPosition)?.compare(other as? TextPosition) ?? .orderedAscending
    }
    
    public func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        return (toPosition as! TextPosition).offset - (from as! TextPosition).offset
    }
    
    // MARK: Layout questions
    
    public func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        let nsRange: NSRange? = (range as? TextRange)?.asRange
        if direction == .left || direction == .up {
            return TextPosition(offset: (nsRange?.location)!)
        } else {
            return TextPosition(offset: (nsRange?.location ?? 0) + (nsRange?.length ?? 0), affinity: TextAffinity.backward)
        }
    }
    
    public func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        _updateIfNeeded()
        let range: TextRange? = _innerLayout?.textRange(byExtending: (position as! TextPosition), in: direction, offset: 1)
        return _correctedTextRange(range)
    }
    
    // MARK: Writing direction
    
    public func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> UITextWritingDirection {
        
        guard var position = position as? TextPosition else {
            return .natural
        }
        _updateIfNeeded()
        
        guard let p = _correctedTextPosition(position) else {
            return .natural
        }
        position = p
        
        if _innerText.length == 0 {
            return .natural
        }
        var idx = position.offset
        if idx == _innerText.length {
            idx -= 1
        }
        
        let attrs = _innerText.bs_attributes(at: idx)
        let paraStyle = (attrs![NSAttributedString.Key.paragraphStyle]) as! CTParagraphStyle?
        if paraStyle != nil {
            let baseWritingDirection = UnsafeMutablePointer<CTWritingDirection>.allocate(capacity: 1)
            defer {
                baseWritingDirection.deallocate()
            }
            if CTParagraphStyleGetValueForSpecifier(paraStyle!, CTParagraphStyleSpecifier.baseWritingDirection, MemoryLayout<CTWritingDirection>.size, baseWritingDirection) {
                return (UITextWritingDirection(rawValue: Int(baseWritingDirection.pointee.rawValue)))!
            }
        }
        
        return .natural
    }
    
    public func setBaseWritingDirection(_ writingDirection: UITextWritingDirection, for range: UITextRange) {
        
        guard var range = range as? TextRange else {
            return
        }
        range = _correctedTextRange(range)!
        _innerText.bs_set(baseWritingDirection: NSWritingDirection(rawValue: writingDirection.rawValue)!, range: range.asRange)
        _commitUpdate()
    }
    
    // MARK: Geometry used to provide, for example, a correction rect
    
    public func firstRect(for range: UITextRange) -> CGRect {
        _updateIfNeeded()
        var rect: CGRect = _innerLayout!.firstRect(for: range as! TextRange)
        if rect.isNull {
            rect = CGRect.zero
        }
        return _convertRect(fromLayout: rect)
    }
    
    public func caretRect(for position: UITextPosition) -> CGRect {
        _updateIfNeeded()
        var caretRect: CGRect = _innerLayout!.caretRect(for: position as! TextPosition)
        if !caretRect.isNull {
            caretRect = _convertRect(fromLayout: caretRect)
            caretRect = caretRect.standardized
            if isVerticalForm {
                if caretRect.size.height == 0 {
                    caretRect.size.height = 2
                    caretRect.origin.y -= 2 * 0.5
                }
                if caretRect.origin.y < 0 {
                    caretRect.origin.y = 0
                } else if caretRect.origin.y + caretRect.size.height > bounds.size.height {
                    caretRect.origin.y = bounds.size.height - caretRect.size.height
                }
            } else {
                if caretRect.size.width == 0 {
                    caretRect.size.width = 2
                    caretRect.origin.x -= 2 * 0.5
                }
                if caretRect.origin.x < 0 {
                    caretRect.origin.x = 0
                } else if caretRect.origin.x + caretRect.size.width > bounds.size.width {
                    caretRect.origin.x = bounds.size.width - caretRect.size.width
                }
            }
            return TextUtilities.textCGRect(pixelRound: caretRect)
        }
        return CGRect.zero
    }
    
    public func selectionRects(for range: UITextRange?) -> [UITextSelectionRect] {
        _updateIfNeeded()
        guard let r = range as? TextRange else {
            return []
        }
        let rects = _innerLayout?.selectionRects(for: r)
        
        for rect in rects ?? [] {
            rect.rect = self._convertRect(fromLayout: rect.rect)
        }
        return rects ?? []
    }
    
    // MARK: Hit testing
    
    public func closestPosition(to point: CGPoint) -> UITextPosition? {
        var point = point
        _updateIfNeeded()
        point = _convertPoint(toLayout: point)
        let position = _innerLayout?.closestPosition(to: point)
        return _correctedTextPosition(position)
    }
    
    public func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        
        guard var range = range as? TextRange else {
            return nil
        }
        
        guard var pos = closestPosition(to: point) as? TextPosition else {
            return nil
        }
        
        range = _correctedTextRange(range)!
        if pos.compare(range.start) == .orderedAscending {
            pos = range.start
        } else if pos.compare(range.end) == .orderedDescending {
            pos = range.end
        }
        return pos
    }
    
    public func characterRange(at point: CGPoint) -> UITextRange? {
        var point = point
        _updateIfNeeded()
        point = _convertPoint(toLayout: point)
        let r = _innerLayout?.closestTextRange(at: point)
        return _correctedTextRange(r)
    }
}

// MARK: - UITextInput Optional

extension BSTextView {
    
    open func shouldChangeText(in range: UITextRange, replacementText text: String) -> Bool {
        print("❌ shouldChangeText \(range) | \(text) \(self.log)")
        return true
    }
    
    public func textStyling(at position: UITextPosition, in direction: UITextStorageDirection) -> [NSAttributedString.Key : Any]? {
        guard let position = position as? TextPosition else {
            return nil
        }
        if _innerText.length == 0 {
            return _typingAttributesHolder.bs_attributes
        }
        var attrs: [NSAttributedString.Key : Any]? = nil
        if 0 <= position.offset && position.offset <= _innerText.length {
            var ofs = position.offset
            if position.offset == _innerText.length || direction == .backward {
                ofs = ofs - 1
            }
            attrs = _innerText.attributes(at: ofs, effectiveRange: nil)
        }
        return attrs
    }
    
    public func position(within range: UITextRange, atCharacterOffset offset: Int) -> UITextPosition? {
        guard let range = range as? TextRange else {
            return nil
        }
        if offset < range.start.offset || offset > range.end.offset {
            return nil
        }
        if offset == range.start.offset {
            return range.start
        } else if offset == range.end.offset {
            return range.end
        } else {
            return TextPosition(offset: offset)
        }
    }
    
    public func characterOffset(of position: UITextPosition, within range: UITextRange) -> Int {
        guard let position = position as? TextPosition else {
            return NSNotFound
        }
        return position.offset
    }
    
    public var selectionAffinity: UITextStorageDirection {
        get {
            if _selectedTextRange.end.affinity == TextAffinity.forward {
                return .forward
            } else {
                return .backward
            }
        }
        set(selectionAffinity) {
            _selectedTextRange = TextRange(range: _selectedTextRange.asRange, affinity: selectionAffinity == .forward ? TextAffinity.forward : TextAffinity.backward)
            _updateSelectionView()
        }
    }
}

public extension BSTextView {
    var log: String {
        "【text: \(text) | hasText: \(hasText) | selectedRange: \(selectedRange) | selectedTextRange: \(String(describing: selectedTextRange)) | markedTextRange: \(String(describing: markedTextRange)) 】"
    }
}
