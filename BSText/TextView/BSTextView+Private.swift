//
//  BSTextView+Private.swift
//  BSText
//
//  Created by naijoug on 2022/4/16.
//

import UIKit

extension BSTextView {
    
    /// Update layout and selection before runloop sleep/end.
    func _commitUpdate() {
        #if !TARGET_INTERFACE_BUILDER
        state.needUpdate = true
        TextTransaction(target: self, selector: #selector(self._updateIfNeeded)).commit()
        #else
        _update()
        #endif
    }
    
    /// Update layout and selection view if needed.
    @objc func _updateIfNeeded() {
        if state.needUpdate {
            _update()
        }
    }
    
    /// Update layout and selection view immediately.
    func _update() {
        state.needUpdate = false
        _updateLayout()
        _updateSelectionView()
    }
    
    /// Update layout immediately.
    func _updateLayout() {
        let text = _innerText.mutableCopy() as! NSMutableAttributedString
        _placeHolderView.isHidden = (text.length > 0)
        if _detectText(text) {
            _delectedText = text
        } else {
            _delectedText = nil
        }
        text.replaceCharacters(in: NSRange(location: text.length, length: 0), with: "\r") // add for nextline caret
        text.bs_removeDiscontinuousAttributes(in: NSRange(location: _innerText.length, length: 1))
        text.removeAttribute(NSAttributedString.Key(rawValue: TextAttribute.textBorderAttributeName), range: NSRange(location: _innerText.length, length: 1))
        text.removeAttribute(NSAttributedString.Key(rawValue: TextAttribute.textBackgroundBorderAttributeName), range: NSRange(location: _innerText.length, length: 1))
        if _innerText.length == 0 {
            text.bs_setAttributes(_typingAttributesHolder.bs_attributes) // add for empty text caret
        }
        if _selectedTextRange.end.offset == _innerText.length {
            for (key, value) in _typingAttributesHolder.bs_attributes ?? [:] {
                text.bs_set(attribute: key, value: value, range: NSRange(location: _innerText.length, length: 1))
            }
        }
        willChangeValue(forKey: "textLayout")
        _innerLayout = TextLayout(container: _innerContainer, text: text)
        didChangeValue(forKey: "textLayout")
        var size: CGSize = _innerLayout?.textBoundingSize ?? .zero
        let visibleSize: CGSize = _getVisibleSize()
        if _innerContainer.isVerticalForm {
            size.height = visibleSize.height
            if size.width < visibleSize.width {
                size.width = visibleSize.width
            }
        } else {
            size.width = visibleSize.width
        }
        
        _containerView.set(layout: _innerLayout, with: 0)
        _containerView.frame = CGRect()
        _containerView.frame.size = size
        state.showingHighlight = false
        self.contentSize = size
    }
    
    /// Update selection view immediately.
    /// This method should be called after "layout update" finished.
    func _updateSelectionView() {
        _selectionView.frame = _containerView.frame
        _selectionView.caretBlinks = false
        _selectionView.caretVisible = false
        _selectionView.selectionRects = nil
        TextEffectWindow.shared?.hide(selectionDot: _selectionView)
        if _innerLayout == nil {
            return
        }
        
        var allRects = [TextSelectionRect]()
        var containsDot = false
        
        var selectedRange = _selectedTextRange
        if state.trackingTouch && _trackingRange != nil {
            selectedRange = _trackingRange!
        }
        
        if _markedTextRange != nil {
            var rects = _innerLayout?.selectionRectsWithoutStartAndEnd(for: _markedTextRange!)
            if let aRects = rects {
                allRects.append(contentsOf: aRects)
            }
            if selectedRange.asRange.length > 0 {
                rects = _innerLayout?.selectionRectsWithOnlyStartAndEnd(for: selectedRange)
                if let aRects = rects {
                    allRects.append(contentsOf: aRects)
                    containsDot = aRects.count > 0
                }
            } else {
                let rect = _innerLayout!.caretRect(for: selectedRange.end)
                _selectionView.caretRect = _convertRect(fromLayout: rect)
                _selectionView.caretVisible = true
                _selectionView.caretBlinks = true
            }
        } else {
            if selectedRange.asRange.length == 0 {
                // only caret
                if isFirstResponder || state.trackingPreSelect {
                    let rect: CGRect = _innerLayout!.caretRect(for: selectedRange.end)
                    _selectionView.caretRect = _convertRect(fromLayout: rect)
                    _selectionView.caretVisible = true
                    if !state.trackingCaret && !state.trackingPreSelect {
                        _selectionView.caretBlinks = true
                    }
                }
            } else {
                // range selected
                if (isFirstResponder && !state.deleteConfirm) || (!isFirstResponder && state.selectedWithoutEdit) {
                    let rects = _innerLayout!.selectionRects(for: selectedRange)
                    allRects.append(contentsOf: rects)
                    containsDot = rects.count > 0
                } else if (!isFirstResponder && state.trackingPreSelect) || (isFirstResponder && state.deleteConfirm) {
                    let rects = _innerLayout!.selectionRectsWithoutStartAndEnd(for: selectedRange)
                    allRects.append(contentsOf: rects)
                }
            }
        }
        (allRects as NSArray).enumerateObjects({ rect, idx, stop in
            (rect as! TextSelectionRect).rect = self._convertRect(fromLayout: (rect as! TextSelectionRect).rect)
        })
        _selectionView.selectionRects = allRects
        if !state.firstShowDot && containsDot {
            state.firstShowDot = true
            /*
             The dot position may be wrong at the first time displayed.
             I can't find the reason. Here's a workaround.
             */
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.02 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
                TextEffectWindow.shared?.show(selectionDot: self._selectionView)
            })
        }
        TextEffectWindow.shared?.show(selectionDot: _selectionView)
        
        if containsDot {
            _startSelectionDotFixTimer()
        } else {
            _endSelectionDotFixTimer()
        }
    }
    
    /// Update inner contains's size.
    func _updateInnerContainerSize() {
        var size: CGSize = _getVisibleSize()
        if _innerContainer.isVerticalForm {
            size.width = CGFloat.greatestFiniteMagnitude
        } else {
            size.height = CGFloat.greatestFiniteMagnitude
        }
        _innerContainer.size = size
    }
    
    /// Update placeholder before runloop sleep/end.
    func _commitPlaceholderUpdate() {
        #if !TARGET_INTERFACE_BUILDER
        state.placeholderNeedUpdate = true
        TextTransaction(target: self, selector: #selector(self._updatePlaceholderIfNeeded)).commit()
        #else
        _updatePlaceholder()
        #endif
    }
    
    /// Update placeholder if needed.
    @objc func _updatePlaceholderIfNeeded() {
        if state.placeholderNeedUpdate {
            state.placeholderNeedUpdate = false
            _updatePlaceholder()
        }
    }
    
    /// Update placeholder immediately.
    func _updatePlaceholder() {
        var frame = CGRect.zero
        _placeHolderView.image = nil
        _placeHolderView.frame = frame
        if (placeholderAttributedText?.length ?? 0) > 0 {
            let container = _innerContainer.copy() as! TextContainer
            container.size = bounds.size
            container.truncationType = TextTruncationType.end
            container.truncationToken = nil
            let layout = TextLayout(container: container, text: placeholderAttributedText)!
            let size: CGSize = layout.textBoundingSize
            let needDraw: Bool = size.width > 1 && size.height > 1
            if needDraw {
                UIGraphicsBeginImageContextWithOptions(size, _: false, _: 0)
                let context = UIGraphicsGetCurrentContext()
                layout.draw(in: context, size: size, debug: debugOption)
                let image: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                _placeHolderView.image = image
                frame.size = image?.size ?? CGSize.zero
                if container.isVerticalForm {
                    frame.origin.x = bounds.size.width - (image?.size.width ?? 0)
                } else {
                    frame.origin = CGPoint.zero
                }
                _placeHolderView.frame = frame
            }
        }
    }
    
    /// Update the `_selectedTextRange` to a single position by `_trackingPoint`.
    func _updateTextRangeByTrackingCaret() {
        if !state.trackingTouch {
            return
        }
        
        let trackingPoint = _convertPoint(toLayout: _trackingPoint)
        
        if var newPos = _innerLayout?.closestPosition(to: trackingPoint) {
            newPos = _correctedTextPosition(newPos)!
            if _markedTextRange != nil {
                if newPos.compare(_markedTextRange!.start) == .orderedAscending {
                    newPos = _markedTextRange!.start
                } else if newPos.compare(_markedTextRange!.end) == .orderedDescending {
                    newPos = _markedTextRange!.end
                }
            }
            _trackingRange = TextRange.range(with: NSRange(location: newPos.offset, length: 0), affinity: newPos.affinity)
        }
    }
    
    /// Update the `_selectedTextRange` to a new range by `_trackingPoint` and `_state.trackingGrabber`.
    func _updateTextRangeByTrackingGrabber() {
        if !state.trackingTouch || state.trackingGrabber == .none {
            return
        }
        
        let isStart = (state.trackingGrabber == .start)
        var magPoint = _trackingPoint
        magPoint.y += BSTextView.kMagnifierRangedTrackFix
        magPoint = _convertPoint(toLayout: magPoint)
        var position: TextPosition? = _innerLayout?.position(for: magPoint, oldPosition: (isStart ? _selectedTextRange.start : _selectedTextRange.end), otherPosition: (isStart ? _selectedTextRange.end : _selectedTextRange.start))
        if position != nil {
            position = _correctedTextPosition(position)
            if (position?.offset ?? 0) > _innerText.length {
                position = TextPosition.position(with: _innerText.length)
            }
            _trackingRange = TextRange.range(with: (isStart ? position! : _selectedTextRange.start), end: (isStart ? _selectedTextRange.end : position!))
        }
    }
    
    /// Update the `_selectedTextRange` to a new range/position by `_trackingPoint`.
    func _updateTextRangeByTrackingPreSelect() {
        if !state.trackingTouch {
            return
        }
        _trackingRange = _getClosestTokenRange(at: _trackingPoint)
    }
    
    /// Show or update `_magnifierCaret` based on `_trackingPoint`, and hide `_magnifierRange`.
    func _showMagnifierCaret() {
        if TextUtilities.isAppExtension {
            return
        }
        
        if state.showingMagnifierRanged {
            state.showingMagnifierRanged = false
            TextEffectWindow.shared?.hide(_magnifierRanged)
        }
        
        _magnifierCaret.hostPopoverCenter = _trackingPoint
        _magnifierCaret.hostCaptureCenter = _trackingPoint
        if !state.showingMagnifierCaret {
            state.showingMagnifierCaret = true
            TextEffectWindow.shared?.show(_magnifierCaret)
        } else {
            TextEffectWindow.shared?.move(_magnifierCaret)
        }
    }
    
    /// Show or update `_magnifierRanged` based on `_trackingPoint`, and hide `_magnifierCaret`.
    func _showMagnifierRanged() {
        if TextUtilities.isAppExtension {
            return
        }
        
        if isVerticalForm {
            // hack for vertical form...
            _showMagnifierCaret()
            return
        }
        
        if state.showingMagnifierCaret {
            state.showingMagnifierCaret = false
            TextEffectWindow.shared?.hide(_magnifierCaret)
        }
        
        var magPoint = _trackingPoint
        if isVerticalForm {
            magPoint.x += BSTextView.kMagnifierRangedTrackFix
        } else {
            magPoint.y += BSTextView.kMagnifierRangedTrackFix
        }
        
        var selectedRange = _selectedTextRange
        if state.trackingTouch && _trackingRange != nil {
            selectedRange = _trackingRange!
        }
        
        var position: TextPosition?
        if _markedTextRange != nil {
            position = selectedRange.end
        } else {
            position = _innerLayout?.position(for: _convertPoint(toLayout: magPoint), oldPosition: (state.trackingGrabber == .start ? selectedRange.start : selectedRange.end), otherPosition: (state.trackingGrabber == .start ? selectedRange.end : selectedRange.start))
        }
        
        let lineIndex = _innerLayout?.lineIndex(for: position) ?? 0
        if lineIndex < _innerLayout?.lines.count ?? 0 {
            let line = _innerLayout!.lines[lineIndex]
            let lineRect: CGRect = _convertRect(fromLayout: line.bounds)
            if isVerticalForm {
                magPoint.x = TextUtilities.textClamp(x: magPoint.x, low: lineRect.minX, high: lineRect.maxX)
            } else {
                
                magPoint.y = TextUtilities.textClamp(x: magPoint.y, low: lineRect.minY, high: lineRect.maxY)
            }
            var linePoint: CGPoint = _innerLayout!.linePosition(for: position)
            linePoint = _convertPoint(fromLayout: linePoint)
            
            var popoverPoint: CGPoint = linePoint
            if isVerticalForm {
                popoverPoint.x = linePoint.x + _magnifierRangedOffset
            } else {
                popoverPoint.y = linePoint.y + _magnifierRangedOffset
            }
            
            var capturePoint: CGPoint = .zero
            if isVerticalForm {
                capturePoint.x = linePoint.x + BSTextView.kMagnifierRangedCaptureOffset
                capturePoint.y = linePoint.y
            } else {
                capturePoint.x = linePoint.x
                capturePoint.y = linePoint.y + BSTextView.kMagnifierRangedCaptureOffset
            }
            
            _magnifierRanged.hostPopoverCenter = popoverPoint
            _magnifierRanged.hostCaptureCenter = capturePoint
            if !state.showingMagnifierRanged {
                state.showingMagnifierRanged = true
                TextEffectWindow.shared?.show(_magnifierRanged)
            } else {
                TextEffectWindow.shared?.move(_magnifierRanged)
            }
        }
    }
    
    /// Update the showing magnifier.
    func _updateMagnifier() {
        if TextUtilities.isAppExtension {
            return
        }
        
        if state.showingMagnifierCaret {
            TextEffectWindow.shared?.move(_magnifierCaret)
        }
        if state.showingMagnifierRanged {
            TextEffectWindow.shared?.move(_magnifierRanged)
        }
    }
    
    /// Hide the `_magnifierCaret` and `_magnifierRanged`.
    func _hideMagnifier() {
        if TextUtilities.isAppExtension {
            return
        }
        
        if state.showingMagnifierCaret || state.showingMagnifierRanged {
            // disable touch began temporary to ignore caret animation overlap
            state.ignoreTouchBegan = true
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.15 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { [weak self] in
                if let strongSelf = self {
                    strongSelf.state.ignoreTouchBegan = false
                }
            })
        }
        
        if state.showingMagnifierCaret {
            state.showingMagnifierCaret = false
            TextEffectWindow.shared?.hide(_magnifierCaret)
        }
        if state.showingMagnifierRanged {
            state.showingMagnifierRanged = false
            TextEffectWindow.shared?.hide(_magnifierRanged)
        }
    }
    
    /// Show and update the UIMenuController.
    func _showMenu() {
        var rect: CGRect
        if _selectionView.caretVisible {
            rect = _selectionView.caretView.frame
        } else if let rects = _selectionView.selectionRects, rects.count > 0 {
            var sRect = rects.first!
            rect = sRect.rect
            for i in 1..<rects.count {
                sRect = rects[i]
                rect = rect.union(sRect.rect)
            }
            
            let inter: CGRect = rect.intersection(bounds)
            if !inter.isNull && inter.size.height > 1 {
                rect = inter //clip to bounds
            } else {
                if rect.minY < bounds.minY {
                    rect.size.height = 1
                    rect.origin.y = bounds.minY
                } else {
                    rect.size.height = 1
                    rect.origin.y = bounds.maxY
                }
            }
            
            let mgr = TextKeyboardManager.default
            if mgr.keyboardVisible {
                let kbRect = mgr.convert(mgr.keyboardFrame, to: self)
                let kbInter: CGRect = rect.intersection(kbRect)
                if !kbInter.isNull && kbInter.size.height > 1 && kbInter.size.width > 1 {
                    // self is covered by keyboard
                    if kbInter.minY > rect.minY {
                        // keyboard at bottom
                        rect.size.height -= kbInter.size.height
                    } else if kbInter.maxY < rect.maxY {
                        // keyboard at top
                        rect.origin.y += kbInter.size.height
                        rect.size.height -= kbInter.size.height
                    }
                }
            }
        } else {
            rect = _selectionView.bounds
        }
        
        if !isFirstResponder {
            if !_containerView.isFirstResponder {
                _containerView.becomeFirstResponder()
            }
        }
        
        if isFirstResponder || _containerView.isFirstResponder {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.01 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { [weak self] in
                if let strongSelf = self {
                    let menu = UIMenuController.shared
                    menu.setTargetRect(rect.standardized, in: strongSelf._selectionView)
                    menu.update()
                    if !strongSelf.state.showingMenu || !menu.isMenuVisible {
                        strongSelf.state.showingMenu = true
                        menu.setMenuVisible(true, animated: true)
                    }
                }
            })
        }
    }
    
    /// Hide the UIMenuController.
    func _hideMenu() {
        if state.showingMenu {
            state.showingMenu = false
            let menu = UIMenuController.shared
            menu.setMenuVisible(false, animated: true)
        }
        if _containerView.isFirstResponder {
            state.ignoreFirstResponder = true
            _containerView.resignFirstResponder() // it will call [self becomeFirstResponder], ignore it temporary.
            state.ignoreFirstResponder = false
        }
    }
    
    /// Show highlight layout based on `_highlight` and `_highlightRange`
    /// If the `_highlightLayout` is nil, try to create.
    func _showHighlight(animated: Bool) {
        let fadeDuration: TimeInterval = animated ? BSTextView.kHighlightFadeDuration : 0
        if _highlight == nil {
            return
        }
        if _highlightLayout == nil {
            let hiText = (_delectedText ?? _innerText)
            let newAttrs = _highlight!.attributes
            for (key, value) in newAttrs {
                hiText.bs_set(attribute: key, value: value, range: _highlightRange)
            }
            
            _highlightLayout = TextLayout(container: _innerContainer, text: hiText)
            if _highlightLayout == nil {
                _highlight = nil
            }
        }
        
        if (_highlightLayout != nil) && !state.showingHighlight {
            state.showingHighlight = true
            _containerView.set(layout: _highlightLayout, with: fadeDuration)
        }
    }
    
    /// Show `_innerLayout` instead of `_highlightLayout`.
    /// It does not destory the `_highlightLayout`.
    func _hideHighlight(animated: Bool) {
        let fadeDuration: TimeInterval = animated ? BSTextView.kHighlightFadeDuration : 0
        if state.showingHighlight {
            state.showingHighlight = false
            _containerView.set(layout: _innerLayout, with: fadeDuration)
        }
    }
    
    /// Show `_innerLayout` and destory the `_highlight` and `_highlightLayout`.
    func _removeHighlight(animated: Bool) {
        _hideHighlight(animated: animated)
        _highlight = nil
        _highlightLayout = nil
    }
    
    /// Scroll current selected range to visible.
    @objc func _scrollSelectedRangeToVisible() {
        _scrollRangeToVisible(_selectedTextRange)
    }
    
    /// Scroll range to visible, take account into keyboard and insets.
    func _scrollRangeToVisible(_ range: TextRange?) {
        if range == nil {
            return
        }
        var rect: CGRect = _innerLayout!.rect(for: range)
        if rect.isNull {
            return
        }
        rect = _convertRect(fromLayout: rect)
        rect = _containerView.convert(rect, to: self)
        
        if rect.size.width < 1 {
            rect.size.width = 1
        }
        if rect.size.height < 1 {
            rect.size.height = 1
        }
        let extend: CGFloat = 3
        
        var insetModified = false
        let mgr = TextKeyboardManager.default
        
        if mgr.keyboardVisible && (window != nil) && (superview != nil) && isFirstResponder && !isVerticalForm {
            var bounds: CGRect = self.bounds
            bounds.origin = CGPoint.zero
            var kbRect = mgr.convert(mgr.keyboardFrame, to: self)
            kbRect.origin.y -= extraAccessoryViewHeight
            kbRect.size.height += extraAccessoryViewHeight
            
            kbRect.origin.x -= contentOffset.x
            kbRect.origin.y -= contentOffset.y
            let inter: CGRect = bounds.intersection(kbRect)
            if !inter.isNull && inter.size.height > 1 && inter.size.width > extend {
                // self is covered by keyboard
                if inter.minY > bounds.minY {
                    // keyboard below self.top
                    
                    var originalContentInset = self.contentInset
                    var originalScrollIndicatorInsets = self.scrollIndicatorInsets
                    if _insetModifiedByKeyboard {
                        originalContentInset = self._originalContentInset
                        originalScrollIndicatorInsets = self._originalScrollIndicatorInsets
                    }
                    
                    if originalContentInset.bottom < inter.size.height + extend {
                        insetModified = true
                        if !_insetModifiedByKeyboard {
                            _insetModifiedByKeyboard = true
                            originalContentInset = contentInset
                            originalScrollIndicatorInsets = scrollIndicatorInsets
                        }
                        var newInset: UIEdgeInsets = originalContentInset
                        var newIndicatorInsets: UIEdgeInsets = originalScrollIndicatorInsets
                        newInset.bottom = inter.size.height + extend
                        newIndicatorInsets.bottom = newInset.bottom
                        
                        let curve = UIView.AnimationOptions(rawValue: 7 << 16)
                        
                        UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, curve], animations: {
                            super.contentInset = newInset
                            super.scrollIndicatorInsets = newIndicatorInsets
                            self.scrollRectToVisible(rect.insetBy(dx: -extend, dy: -extend), animated: false)
                        })
                    }
                    
                }
            }
        }
        
        if !insetModified {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut], animations: {
                self._restoreInsets(animated: false)
                self.scrollRectToVisible(rect.insetBy(dx: -extend, dy: -extend), animated: false)
            })
        }
    }
    
    /// Restore contents insets if modified by keyboard.
    func _restoreInsets(animated: Bool) {
        if _insetModifiedByKeyboard {
            _insetModifiedByKeyboard = false
            if animated {
                UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut], animations: {
                    super.contentInset = self._originalContentInset
                    super.scrollIndicatorInsets = self._originalScrollIndicatorInsets
                })
            } else {
                super.contentInset = _originalContentInset
                super.scrollIndicatorInsets = _originalScrollIndicatorInsets
            }
        }
    }
    
    /// Keyboard frame changed, scroll the caret to visible range, or modify the content insets.
    func _keyboardChanged() {
        if !isFirstResponder {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
            if TextKeyboardManager.default.keyboardVisible {
                self._scrollRangeToVisible(self._selectedTextRange)
            } else {
                self._restoreInsets(animated: true)
            }
            self._updateMagnifier()
            if self.state.showingMenu {
                self._showMenu()
            }
        })
    }
    
    /// Start long press timer, used for 'highlight' range text action.
    func _startLongPressTimer() {
        _longPressTimer?.invalidate()
        _longPressTimer = Timer.bs_scheduledTimer(with: BSTextView.kLongPressMinimumDuration, target: self, selector: #selector(self._trackDidLongPress), userInfo: nil, repeats: false)
        RunLoop.current.add(_longPressTimer!, forMode: .common)
    }
    
    /// Invalidate the long press timer.
    func _endLongPressTimer() {
        _longPressTimer?.invalidate()
        _longPressTimer = nil
    }
    
    /// Long press detected.
    @objc
    func _trackDidLongPress() {
        _endLongPressTimer()
        
        var dealLongPressAction = false
        if state.showingHighlight {
            _hideMenu()
            
            if let action = _highlight?.longPressAction {
                dealLongPressAction = true
                var rect: CGRect = _innerLayout!.rect(for: TextRange(range: _highlightRange))
                rect = _convertRect(fromLayout: rect)
                action(self, _innerText, _highlightRange, rect)
                _endTouchTracking()
            } else {
                var shouldHighlight = true
                if let d = _outerDelegate {
                    if let s = d.textView?(self, shouldLongPress: _highlight!, in: _highlightRange) {
                        shouldHighlight = s
                    }
                    if shouldHighlight {
                        dealLongPressAction = true
                        var rect: CGRect = _innerLayout!.rect(for: TextRange(range: _highlightRange))
                        rect = _convertRect(fromLayout: rect)
                        d.textView?(self, didLongPress: _highlight!, in: _highlightRange, rect: rect)
                        _endTouchTracking()
                    }
                }
            }
        }
        
        if !dealLongPressAction {
            _removeHighlight(animated: false)
            if state.trackingTouch {
                if (state.trackingGrabber != .none) {
                    panGestureRecognizer.isEnabled = false
                    _hideMenu()
                    _showMagnifierRanged()
                } else if isFirstResponder {
                    panGestureRecognizer.isEnabled = false
                    _selectionView.caretBlinks = false
                    state.trackingCaret = true
                    let trackingPoint: CGPoint = _convertPoint(toLayout: _trackingPoint)
                    var newPos = _innerLayout?.closestPosition(to: trackingPoint)
                    newPos = _correctedTextPosition(newPos)
                    if newPos != nil {
                        if let m = _markedTextRange {
                            if newPos?.compare(m.start) != .orderedDescending {
                                newPos = m.start
                            } else if newPos?.compare(m.end) != .orderedAscending {
                                newPos = m.end
                            }
                        }
                        _trackingRange = TextRange(range: NSRange(location: newPos?.offset ?? 0, length: 0), affinity: newPos!.affinity)
                        _updateSelectionView()
                    }
                    _hideMenu()
                    
                    if _markedTextRange != nil {
                        _showMagnifierRanged()
                    } else {
                        _showMagnifierCaret()
                    }
                } else if isSelectable {
                    panGestureRecognizer.isEnabled = false
                    state.trackingPreSelect = true
                    state.selectedWithoutEdit = false
                    _updateTextRangeByTrackingPreSelect()
                    _updateSelectionView()
                    _showMagnifierCaret()
                }
            }
        }
    }
    
    /// Start auto scroll timer, used for auto scroll tick.
    func _startAutoScrollTimer() {
        if _autoScrollTimer == nil {
            _autoScrollTimer = Timer.bs_scheduledTimer(with: BSTextView.kAutoScrollMinimumDuration, target: self, selector: #selector(self._trackDidTickAutoScroll), userInfo: nil, repeats: true)
            RunLoop.current.add(_autoScrollTimer!, forMode: .common)
        }
    }
    
    /// Invalidate the auto scroll, and restore the text view state.
    func _endAutoScrollTimer() {
        if state.autoScrollTicked {
            flashScrollIndicators()
        }
        _autoScrollTimer?.invalidate()
        _autoScrollTimer = nil
        _autoScrollOffset = 0
        _autoScrollAcceleration = 0
        state.autoScrollTicked = false
        
        if _magnifierCaret.captureDisabled {
            _magnifierCaret.captureDisabled = false
            if state.showingMagnifierCaret {
                _showMagnifierCaret()
            }
        }
        if _magnifierRanged.captureDisabled {
            _magnifierRanged.captureDisabled = false
            if state.showingMagnifierRanged {
                _showMagnifierRanged()
            }
        }
    }
    
    /// Auto scroll ticked by timer.
    @objc
    func _trackDidTickAutoScroll() {
        if _autoScrollOffset != 0 {
            _magnifierCaret.captureDisabled = true
            _magnifierRanged.captureDisabled = true
            
            var offset: CGPoint = contentOffset
            if isVerticalForm {
                offset.x += _autoScrollOffset
                
                if _autoScrollAcceleration > 0 {
                    offset.x += (_autoScrollOffset > 0 ? 1 : -1) * CGFloat(_autoScrollAcceleration) * CGFloat(_autoScrollAcceleration) * CGFloat(0.5)
                }
                _autoScrollAcceleration += 1
                offset.x = CGFloat(round(Double(offset.x)))
                if _autoScrollOffset < 0 {
                    if offset.x < -contentInset.left {
                        offset.x = -contentInset.left
                    }
                } else {
                    let maxOffsetX: CGFloat = contentSize.width - bounds.size.width + contentInset.right
                    if offset.x > maxOffsetX {
                        offset.x = maxOffsetX
                    }
                }
                if offset.x < -contentInset.left {
                    offset.x = -contentInset.left
                }
            } else {
                offset.y += _autoScrollOffset
                if _autoScrollAcceleration > 0 {
                    offset.y += (_autoScrollOffset > 0 ? 1 : -1) * CGFloat(_autoScrollAcceleration) * CGFloat(_autoScrollAcceleration) * CGFloat(0.5)
                }
                _autoScrollAcceleration += 1
                offset.y = CGFloat(round(Double(offset.y)))
                if _autoScrollOffset < 0 {
                    if offset.y < -contentInset.top {
                        offset.y = -contentInset.top
                    }
                } else {
                    let maxOffsetY: CGFloat = contentSize.height - bounds.size.height + contentInset.bottom
                    if offset.y > maxOffsetY {
                        offset.y = maxOffsetY
                    }
                }
                if offset.y < -contentInset.top {
                    offset.y = -contentInset.top
                }
            }
            
            var shouldScroll: Bool
            if isVerticalForm {
                shouldScroll = abs(Float(offset.x - contentOffset.x)) > 0.5
            } else {
                shouldScroll = abs(Float(offset.y - contentOffset.y)) > 0.5
            }
            
            if shouldScroll {
                state.autoScrollTicked = true
                _trackingPoint.x += offset.x - contentOffset.x
                _trackingPoint.y += offset.y - contentOffset.y
                UIView.animate(withDuration: BSTextView.kAutoScrollMinimumDuration, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, .curveLinear], animations: {
                    self.contentOffset = offset
                }) { finished in
                    if self.state.trackingTouch {
                        if (self.state.trackingGrabber != .none) {
                            self._showMagnifierRanged()
                            self._updateTextRangeByTrackingGrabber()
                        } else if self.state.trackingPreSelect {
                            self._showMagnifierCaret()
                            self._updateTextRangeByTrackingPreSelect()
                        } else if self.state.trackingCaret {
                            if self._markedTextRange != nil {
                                self._showMagnifierRanged()
                            } else {
                                self._showMagnifierCaret()
                            }
                            self._updateTextRangeByTrackingCaret()
                        }
                        self._updateSelectionView()
                    }
                }
            } else {
                _endAutoScrollTimer()
            }
        } else {
            _endAutoScrollTimer()
        }
    }
    
    /// End current touch tracking (if is tracking now), and update the state.
    func _endTouchTracking() {
        if !state.trackingTouch {
            return
        }
        
        state.trackingTouch = false
        state.trackingGrabber = .none
        state.trackingCaret = false
        state.trackingPreSelect = false
        state.touchMoved = .none
        state.deleteConfirm = false
        state.clearsOnInsertionOnce = false
        _trackingRange = nil
        _selectionView.caretBlinks = true
        
        _removeHighlight(animated: true)
        _hideMagnifier()
        _endLongPressTimer()
        _endAutoScrollTimer()
        _updateSelectionView()
        
        panGestureRecognizer.isEnabled = isScrollEnabled
    }
    
    /// Start a timer to fix the selection dot.
    func _startSelectionDotFixTimer() {
        _selectionDotFixTimer?.invalidate()
        _longPressTimer = Timer.bs_scheduledTimer(with: 1 / 15.0, target: self, selector: #selector(self._fixSelectionDot), userInfo: nil, repeats: false)
        RunLoop.current.add(_longPressTimer!, forMode: .common)
    }
    
    /// End the timer.
    func _endSelectionDotFixTimer() {
        _selectionDotFixTimer?.invalidate()
        _selectionDotFixTimer = nil
    }
    
    /// If it shows selection grabber and this view was moved by super view,
    /// update the selection dot in window.
    @objc
    func _fixSelectionDot() {
        if TextUtilities.isAppExtension {
            return
        }
        let origin = bs_convertPoint(CGPoint.zero, toViewOrWindow: TextEffectWindow.shared)
        if !origin.equalTo(_previousOriginInWindow) {
            _previousOriginInWindow = origin
            TextEffectWindow.shared?.hide(selectionDot: _selectionView)
            TextEffectWindow.shared?.show(selectionDot: _selectionView)
        }
    }
    
    /// Try to get the character range/position with word granularity from the tokenizer.
    func _getClosestTokenRange(at position: TextPosition?) -> TextRange? {
        
        guard let position = _correctedTextPosition(position) else {
            return nil
        }
//        var range: TextRange? = nil
//        if true  {       // tokenizer
            var range = tokenizer.rangeEnclosingPosition(position, with: .word, inDirection: UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)) as? TextRange
            if range?.asRange.length == 0 {
                range = tokenizer.rangeEnclosingPosition(position, with: .word, inDirection: UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)) as? TextRange
            }
//        }
        
        if range == nil || range?.asRange.length == 0 {
            range = _innerLayout?.textRange(byExtending: position, in: UITextLayoutDirection.right, offset: 1)
            range = _correctedTextRange(range)
            if range?.asRange.length == 0 {
                range = _innerLayout?.textRange(byExtending: position, in: UITextLayoutDirection.left, offset: 1)
                range = _correctedTextRange(range)
            }
        } else {
            let extStart: TextRange? = _innerLayout?.textRange(byExtending: range?.start)
            let extEnd: TextRange? = _innerLayout?.textRange(byExtending: range?.end)
            if let es = extStart, let ee = extEnd {
                let arr = ([es.start, es.end, ee.start, ee.end] as NSArray).sortedArray(using: #selector(es.start.compare(_:)))
                range = TextRange(start: arr.first as! TextPosition, end: arr.last as! TextPosition)
            }
        }
        
        range = _correctedTextRange(range)
        if range?.asRange.length == 0 {
            range = TextRange(range: NSRange(location: 0, length: _innerText.length))
        }
        
        return _correctedTextRange(range)
    }
    
    /// Try to get the character range/position with word granularity from the tokenizer.
    func _getClosestTokenRange(at point: CGPoint) -> TextRange? {
        var point = point
        point = _convertPoint(toLayout: point)
        var touchRange: TextRange? = _innerLayout?.closestTextRange(at: point)
        touchRange = _correctedTextRange(touchRange)
        
        if true {  // tokenizer
            let encEnd = tokenizer.rangeEnclosingPosition(touchRange!.end, with: .word, inDirection: UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)) as? TextRange
            let encStart = tokenizer.rangeEnclosingPosition(touchRange!.start, with: .word, inDirection: UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)) as? TextRange
            if let es = encStart, let ee = encEnd {
                let arr = ([es.start, es.end, ee.start, ee.end] as NSArray).sortedArray(using: #selector(es.start.compare(_:)))
                touchRange = TextRange(start: arr.first as! TextPosition, end: arr.last as! TextPosition)
            }
        }
        
        if touchRange != nil {
            let extStart: TextRange? = _innerLayout?.textRange(byExtending: touchRange!.start)
            let extEnd: TextRange? = _innerLayout?.textRange(byExtending: touchRange!.end)
            if let es = extStart, let ee = extEnd {
                let arr = ([es.start, es.end, ee.start, ee.end] as NSArray).sortedArray(using: #selector(es.start.compare(_:)))
                touchRange = TextRange(start: arr.first as! TextPosition, end: arr.last as! TextPosition)
            }
        }
        
        if touchRange == nil {
            touchRange = TextRange()
        }
        
        if _innerText.length > 0, let r = touchRange?.asRange, r.length == 0 {
            touchRange = TextRange(range: NSRange(location: 0, length: _innerText.length))
        }
        
        return touchRange
    }
    
    /// Try to get the highlight property. If exist, the range will be returnd by the range pointer.
    /// If the delegate ignore the highlight, returns nil.
    func _getHighlight(at point: CGPoint, range: NSRangePointer?) -> TextHighlight? {
        var point = point
        if !isHighlightable || _innerLayout?.containsHighlight == nil {
            return nil
        }
        point = _convertPoint(toLayout: point)
        var textRange: TextRange? = _innerLayout?.textRange(at: point)
        textRange = _correctedTextRange(textRange)
        if textRange == nil {
            return nil
        }
        var startIndex = textRange?.start.offset ?? 0
        if startIndex == _innerText.length {
            if startIndex == 0 {
                return nil
            } else {
                startIndex = startIndex - 1
            }
        }
        let highlightRange = NSRangePointer.allocate(capacity: 1)
        defer {
            highlightRange.deallocate()
        }
        let text = _delectedText ?? _innerText
        guard let highlight = text.attribute(NSAttributedString.Key(rawValue: TextAttribute.textHighlightAttributeName), at: startIndex, longestEffectiveRange: highlightRange, in: NSRange(location: 0, length: _innerText.length)) as? TextHighlight else {
            return nil
        }
        
        var shouldTap = true
        var shouldLongPress = true
        if highlight.tapAction == nil && highlight.longPressAction == nil {
            if let d = _outerDelegate {
                if let t = d.textView?(self, shouldTap: highlight, in: highlightRange.pointee) {
                    shouldTap = t
                }
                if let l = d.textView?(self, shouldLongPress: highlight, in: highlightRange.pointee) {
                    shouldLongPress = l
                }
            }
        }
        if !shouldTap && !shouldLongPress {
            return nil
        }
        
        range?.pointee = highlightRange.pointee
        
        return highlight
    }
    
    /// Return the ranged magnifier popover offset from the baseline, base on `_trackingPoint`.
    func _getMagnifierRangedOffset() -> CGFloat {
        var magPoint: CGPoint = _trackingPoint
        magPoint = _convertPoint(toLayout: magPoint)
        if isVerticalForm {
            magPoint.x += BSTextView.kMagnifierRangedTrackFix
        } else {
            magPoint.y += BSTextView.kMagnifierRangedTrackFix
        }
        let position = _innerLayout?.closestPosition(to: magPoint)
        let lineIndex = _innerLayout?.lineIndex(for: position) ?? 0
        if lineIndex < (_innerLayout?.lines.count ?? 0) {
            let line = _innerLayout!.lines[lineIndex]
            if isVerticalForm {
                magPoint.x = TextUtilities.textClamp(x: magPoint.x, low: line.left, high: line.right)
                return magPoint.x - line.position.x + BSTextView.kMagnifierRangedPopoverOffset
            } else {
                
                magPoint.y = TextUtilities.textClamp(x: magPoint.y, low: line.top, high: line.bottom)
                return magPoint.y - line.position.y + BSTextView.kMagnifierRangedPopoverOffset
            }
        } else {
            return 0
        }
    }
    
    /// Return a TextMoveDirection from `_touchBeganPoint` to `_trackingPoint`.
    func _getMoveDirection() -> TextMoveDirection {
        let moveH = _trackingPoint.x - _touchBeganPoint.x
        let moveV = _trackingPoint.y - _touchBeganPoint.y
        if abs(Float(moveH)) > abs(Float(moveV)) {
            if abs(Float(moveH)) > BSTextView.kLongPressAllowableMovement {
                return moveH > 0 ? TextMoveDirection.right : TextMoveDirection.left
            }
        } else {
            if abs(Float(moveV)) > BSTextView.kLongPressAllowableMovement {
                return moveV > 0 ? TextMoveDirection.bottom : TextMoveDirection.top
            }
        }
        return .none
    }
    
    /// Get the auto scroll offset in one tick time.
    func _getAutoscrollOffset() -> CGFloat {
        if !state.trackingTouch {
            return 0
        }
        
        var bounds: CGRect = self.bounds
        bounds.origin = CGPoint.zero
        let mgr = TextKeyboardManager.default
        if mgr.keyboardVisible && (window != nil) && (superview != nil) && isFirstResponder && !isVerticalForm {
            var kbRect = mgr.convert(mgr.keyboardFrame, to: self)
            kbRect.origin.y -= extraAccessoryViewHeight
            kbRect.size.height += extraAccessoryViewHeight
            
            kbRect.origin.x -= contentOffset.x
            kbRect.origin.y -= contentOffset.y
            let inter: CGRect = bounds.intersection(kbRect)
            if !inter.isNull && inter.size.height > 1 && inter.size.width > 1 {
                if inter.minY > bounds.minY {
                    bounds.size.height -= inter.size.height
                }
            }
        }
        
        var point = _trackingPoint
        point.x -= contentOffset.x
        point.y -= contentOffset.y
        
        let maxOfs: CGFloat = 32 // a good value ~
        var ofs: CGFloat = 0
        if isVerticalForm {
            if point.x < contentInset.left {
                ofs = (point.x - contentInset.left - 5) * 0.5
                if ofs < -maxOfs {
                    ofs = -maxOfs
                }
            } else if point.x > bounds.size.width {
                ofs = ((point.x - bounds.size.width) + 5) * 0.5
                if ofs > maxOfs {
                    ofs = maxOfs
                }
            }
        } else {
            if point.y < contentInset.top {
                ofs = (point.y - contentInset.top - 5) * 0.5
                if ofs < -maxOfs {
                    ofs = -maxOfs
                }
            } else if point.y > bounds.size.height {
                ofs = ((point.y - bounds.size.height) + 5) * 0.5
                if ofs > maxOfs {
                    ofs = maxOfs
                }
            }
        }
        return ofs
    }
    
    /// Visible size based on bounds and insets
    func _getVisibleSize() -> CGSize {
        var visibleSize: CGSize = bounds.size
        visibleSize.width -= contentInset.left - contentInset.right
        visibleSize.height -= contentInset.top - contentInset.bottom
        if visibleSize.width < 0 {
            visibleSize.width = 0
        }
        if visibleSize.height < 0 {
            visibleSize.height = 0
        }
        return visibleSize
    }
    
    /// Returns whether the text view can paste data from pastboard.
    func _isPasteboardContainsValidValue() -> Bool {
        let pasteboard = UIPasteboard.general
        if (pasteboard.string?.length ?? 0) > 0 {
            return true
        }
        if (pasteboard.bs_AttributedString?.length ?? 0) > 0 {
            if allowsPasteAttributedString {
                return true
            }
        }
        if pasteboard.image != nil || (pasteboard.bs_ImageData?.count ?? 0) > 0 {
            if allowsPasteImage {
                return true
            }
        }
        return false
    }
    
    /// Save current selected attributed text to pasteboard.
    func _copySelectedTextToPasteboard() {
        if allowsCopyAttributedString {
            let text: NSAttributedString = _innerText.attributedSubstring(from: _selectedTextRange.asRange)
            if text.length > 0 {
                UIPasteboard.general.bs_AttributedString = text
            }
        } else {
            let string = _innerText.bs_plainText(for: _selectedTextRange.asRange)
            if (string?.length ?? 0) > 0 {
                UIPasteboard.general.string = string
            }
        }
    }
    
    /// Update the text view state when pasteboard changed.
    @objc
    func _pasteboardChanged() {
        if state.showingMenu {
            let menu = UIMenuController.shared
            menu.update()
        }
    }
    
    /// Whether the position is valid (not out of bounds).
    func _isTextPositionValid(_ position: TextPosition?) -> Bool {
        guard let position = position else {
            return false
        }
        if position.offset < 0 {
            return false
        }
        if position.offset > _innerText.length {
            return false
        }
        if position.offset == 0 && position.affinity == TextAffinity.backward {
            return false
        }
        if position.offset == _innerText.length && position.affinity == TextAffinity.backward {
            return false
        }
        return true
    }
    
    /// Whether the range is valid (not out of bounds).
    func _isTextRangeValid(_ range: TextRange?) -> Bool {
        if !_isTextPositionValid(range?.start) {
            return false
        }
        if !_isTextPositionValid(range?.end) {
            return false
        }
        return true
    }
    
    /// Correct the position if it out of bounds.
    func _correctedTextPosition(_ position: TextPosition?) -> TextPosition? {
        guard let position = position else {
            return nil
        }
        if _isTextPositionValid(position) {
            return position
        }
        if position.offset < 0 {
            return TextPosition.position(with: 0)
        }
        if position.offset > _innerText.length {
            return TextPosition.position(with: _innerText.length)
        }
        if position.offset == 0 && position.affinity == TextAffinity.backward {
            return TextPosition.position(with: position.offset)
        }
        if position.offset == _innerText.length && position.affinity == TextAffinity.backward {
            return TextPosition.position(with: position.offset)
        }
        return position
    }
    
    /// Correct the range if it out of bounds.
    func _correctedTextRange(_ range: TextRange?) -> TextRange? {
        guard let range = range else {
            return nil
        }
        if _isTextRangeValid(range) {
            return range
        }
        guard let start = _correctedTextPosition(range.start) else {
            return nil
        }
        guard let end = _correctedTextPosition(range.end) else {
            return nil
        }
        return TextRange(start: start, end: end)
    }
    
    /// Convert the point from this view to text layout.
    func _convertPoint(toLayout point: CGPoint) -> CGPoint {
        var point = point
        let boundingSize: CGSize = _innerLayout!.textBoundingSize
        if _innerLayout?.container.isVerticalForm ?? false {
            var w = _innerLayout!.textBoundingSize.width
            if w < bounds.size.width {
                w = bounds.size.width
            }
            point.x += _innerLayout!.container.size.width - w
            if boundingSize.width < bounds.size.width {
                if textVerticalAlignment == TextVerticalAlignment.center {
                    point.x += (bounds.size.width - boundingSize.width) * 0.5
                } else if textVerticalAlignment == TextVerticalAlignment.bottom {
                    point.x += bounds.size.width - boundingSize.width
                }
            }
            return point
        } else {
            if boundingSize.height < bounds.size.height {
                if textVerticalAlignment == TextVerticalAlignment.center {
                    point.y -= (bounds.size.height - boundingSize.height) * 0.5
                } else if textVerticalAlignment == TextVerticalAlignment.bottom {
                    point.y -= bounds.size.height - boundingSize.height
                }
            }
            return point
        }
    }
    
    /// Convert the point from text layout to this view.
    func _convertPoint(fromLayout point: CGPoint) -> CGPoint {
        var point = point
        let boundingSize: CGSize = _innerLayout?.textBoundingSize ?? .zero
        if _innerLayout?.container.isVerticalForm ?? false {
            var w = _innerLayout!.textBoundingSize.width
            if w < bounds.size.width {
                w = bounds.size.width
            }
            point.x -= _innerLayout!.container.size.width - w
            if boundingSize.width < bounds.size.width {
                if textVerticalAlignment == TextVerticalAlignment.center {
                    point.x -= (bounds.size.width - boundingSize.width) * 0.5
                } else if textVerticalAlignment == TextVerticalAlignment.bottom {
                    point.x -= bounds.size.width - boundingSize.width
                }
            }
            return point
        } else {
            if boundingSize.height < bounds.size.height {
                if textVerticalAlignment == TextVerticalAlignment.center {
                    point.y += (bounds.size.height - boundingSize.height) * 0.5
                } else if textVerticalAlignment == TextVerticalAlignment.bottom {
                    point.y += bounds.size.height - boundingSize.height
                }
            }
            return point
        }
    }
    
    /// Convert the rect from this view to text layout.
    func _convertRect(toLayout rect: CGRect) -> CGRect {
        var rect = rect
        rect.origin = _convertPoint(toLayout: rect.origin)
        return rect
    }
    
    /// Convert the rect from text layout to this view.
    func _convertRect(fromLayout rect: CGRect) -> CGRect {
        var rect = rect
        rect.origin = _convertPoint(fromLayout: rect.origin)
        return rect
    }
    
    /// Replace the range with the text, and change the `_selectTextRange`.
    /// The caller should make sure the `range` and `text` are valid before call this method.
    func _replace(_ range: TextRange, withText text: String, notifyToDelegate notify: Bool) {
        if notify {
            _inputDelegate?.textWillChange(self)
        }
        let newRange = NSRange(location: range.asRange.location, length: text.length)
        _innerText.replaceCharacters(in: range.asRange, with: text)
        _innerText.bs_removeDiscontinuousAttributes(in: newRange)

        if notify {
            _inputDelegate?.textDidChange(self)
        }
        
        if NSEqualRanges(range.asRange, _selectedTextRange.asRange) {
            if notify {
                _inputDelegate?.selectionWillChange(self)
            }
            var newRange = NSRange(location: 0, length: 0)
            // fixbug 修复连续输入 Emoji 时出现的乱码的问题，原因：NSString 中 Emoji 表情的 length 等于2，而 Swift 中 Emoji 的 Count 等于1，_innerText 继承于 NSString，所以此处用 (text as NSString).length
            // now use text.utf16.count replace (text as NSString).length
            newRange.location = _selectedTextRange.start.offset + text.length
            _selectedTextRange = TextRange(range: newRange)
            if notify {
                _inputDelegate?.selectionDidChange(self)
            }
        } else {
            if range.asRange.length != text.length {
                if notify {
                    _inputDelegate?.selectionWillChange(self)
                }
                let unionRange: NSRange = NSIntersectionRange(_selectedTextRange.asRange, range.asRange)
                if unionRange.length == 0 {
                    // no intersection
                    if range.end.offset <= _selectedTextRange.start.offset {
                        let ofs = text.length - range.asRange.length
                        var newRange = _selectedTextRange.asRange
                        newRange.location += ofs
                        _selectedTextRange = TextRange(range: newRange)
                    }
                } else if unionRange.length == _selectedTextRange.asRange.length {
                    // target range contains selected range
                    _selectedTextRange = TextRange(range: NSRange(location: range.start.offset + text.length, length: 0))
                } else if range.start.offset >= _selectedTextRange.start.offset && range.end.offset <= _selectedTextRange.end.offset {
                    // target range inside selected range
                    let ofs = text.length - range.asRange.length
                    var newRange: NSRange = _selectedTextRange.asRange
                    newRange.length += ofs
                    _selectedTextRange = TextRange(range: newRange)
                } else {
                    // interleaving
                    if range.start.offset < _selectedTextRange.start.offset {
                        var newRange: NSRange = _selectedTextRange.asRange
                        newRange.location = range.start.offset + text.length
                        newRange.length -= unionRange.length
                        _selectedTextRange = TextRange(range: newRange)
                    } else {
                        var newRange: NSRange = _selectedTextRange.asRange
                        newRange.length -= unionRange.length
                        _selectedTextRange = TextRange(range: newRange)
                    }
                }
                _selectedTextRange = _correctedTextRange(_selectedTextRange)!
                if notify {
                    _inputDelegate?.selectionDidChange(self)
                }
            }
        }
    }
    
    /// Save current typing attributes to the attributes holder.
    func _updateAttributesHolder() {
        if _innerText.length > 0 {
            let index: Int = _selectedTextRange.end.offset == 0 ? 0 : _selectedTextRange.end.offset - 1
            let attributes = _innerText.bs_attributes(at: index) ?? [:]
            
            _typingAttributesHolder.bs_attributes = attributes
            _typingAttributesHolder.bs_removeDiscontinuousAttributes(in: NSRange(location: 0, length: _typingAttributesHolder.length))
            _typingAttributesHolder.removeAttribute(NSAttributedString.Key(rawValue: TextAttribute.textBorderAttributeName), range: NSRange(location: 0, length: _typingAttributesHolder.length))
            _typingAttributesHolder.removeAttribute(NSAttributedString.Key(rawValue: TextAttribute.textBackgroundBorderAttributeName), range: NSRange(location: 0, length: _typingAttributesHolder.length))
        }
    }
    
    /// Update outer properties from current inner data.
    func _updateOuterProperties() {
        _updateAttributesHolder()
        var style: NSParagraphStyle? = _innerText.bs_paragraphStyle
        if style == nil {
            style = _typingAttributesHolder.bs_paragraphStyle
        }
        if style == nil {
            style = NSParagraphStyle.default
        }
        
        var font: UIFont? = _innerText.bs_font
        if font == nil {
            font = _typingAttributesHolder.bs_font
        }
        if font == nil {
            font = BSTextView._defaultFont
        }
        
        var color: UIColor? = _innerText.bs_color
        if color == nil {
            color = _typingAttributesHolder.bs_color
        }
        if color == nil {
            color = UIColor.black
        }
        
        _setText(_innerText.bs_plainText(for: NSRange(location: 0, length: _innerText.length)))
        _setFont(font)
        _setTextColor(color)
        _setTextAlignment(style!.alignment)
        _setSelectedRange(_selectedTextRange.asRange)
        _setTypingAttributes(_typingAttributesHolder.bs_attributes)
        _setAttributedText(_innerText)
    }
    
    /// Parse text with `textParser` and update the _selectedTextRange.
    /// @return Whether changed (text or selection)
    @discardableResult
    func _parseText() -> Bool {
        if (textParser != nil) {
            let oldTextRange = _selectedTextRange
            var newRange = _selectedTextRange.asRange
            
            _inputDelegate?.textWillChange(self)
            let textChanged = textParser!.parseText(_innerText, selectedRange: &newRange)
            _inputDelegate?.textDidChange(self)
            
            var newTextRange = TextRange(range: newRange)
            newTextRange = _correctedTextRange(newTextRange)!
            
            if !(oldTextRange == newTextRange) {
                _inputDelegate?.selectionWillChange(self)
                _selectedTextRange = newTextRange
                _inputDelegate?.selectionDidChange(self)
            }
            return textChanged
        }
        return false
    }
    
    /// Returns whether the text should be detected by the data detector.
    func _shouldDetectText() -> Bool {
        if _dataDetector == nil {
            return false
        }
        if !isHighlightable {
            return false
        }
        if _linkTextAttributes?.count ?? 0 == 0 && _highlightTextAttributes?.count ?? 0 == 0 {
            return false
        }
        if isFirstResponder || _containerView.isFirstResponder {
            return false
        }
        return true
    }
    
    /// Detect the data in text and add highlight to the data range.
    /// @return Whether detected.
    func _detectText(_ text: NSMutableAttributedString?) -> Bool {
        
        guard let text = text, text.length > 0 else {
            return false
        }
        if !_shouldDetectText() {
            return false
        }
        
        var detected = false
        _dataDetector?.enumerateMatches(in: text.string, options: [], range: NSRange(location: 0, length: text.length), using: { result, flags, stop in
            switch result!.resultType {
            case .date, .address, .link, .phoneNumber:
                detected = true
                if self.highlightTextAttributes?.count ?? 0 > 0 {
                    let highlight = TextHighlight(attributes: self.highlightTextAttributes)
                    text.bs_set(textHighlight: highlight, range: result!.range)
                }
                if self.linkTextAttributes?.count ?? 0 > 0 {
                    for (key, obj) in self.linkTextAttributes! {
                        text.bs_set(attribute: key, value: obj, range: result!.range)
                    }
                }
            default:
                break
            }
        })
        return detected
    }
    
    /// Returns the `root` view controller (returns nil if not found).
    func _getRootViewController() -> UIViewController? {
        var ctrl: UIViewController? = nil
        let app: UIApplication? = TextUtilities.sharedApplication
        if ctrl == nil {
            ctrl = app?.keyWindow?.rootViewController
        }
        if ctrl == nil {
            ctrl = app?.windows.first?.rootViewController
        }
        if ctrl == nil {
            ctrl = bs_viewController
        }
        if ctrl == nil {
            return nil
        }
        
        while ctrl?.view.window == nil && ctrl?.presentedViewController != nil {
            ctrl = ctrl?.presentedViewController
        }
        if ctrl?.view.window == nil {
            return nil
        }
        return ctrl
    }
    
    /// Clear the undo and redo stack, and capture current state to undo stack.
    func _resetUndoAndRedoStack() {
        _undoStack.removeAll()
        _redoStack.removeAll()
        let object = TextViewUndoObject(text: _innerText.copy() as? NSAttributedString, range: _selectedTextRange.asRange)
        _lastTypeRange = _selectedTextRange.asRange
        
        _undoStack.append(object)
    }
    
    /// Clear the redo stack.
    func _resetRedoStack() {
        _redoStack.removeAll()
    }
    
    /// Capture current state to undo stack.
    func _saveToUndoStack() {
        if !allowsUndoAndRedo {
            return
        }
        let lastObject = _undoStack.last
        if let text = attributedText {
            if lastObject?.text!.isEqual(to: text) ?? false {
                return
            }
        }
        
        let object = TextViewUndoObject(text: (_innerText.copy() as! NSAttributedString), range: _selectedTextRange.asRange)
        _lastTypeRange = _selectedTextRange.asRange
        _undoStack.append(object)
        while _undoStack.count > maximumUndoLevel {
            _undoStack.remove(at: 0)
        }
    }
    
    /// Capture current state to redo stack.
    func _saveToRedoStack() {
        if !allowsUndoAndRedo {
            return
        }
        let lastObject = _redoStack.last
        if let text = attributedText {
            if lastObject?.text?.isEqual(to: text) ?? false {
                return
            }
        }
        
        let object = TextViewUndoObject(text: (_innerText.copy() as! NSAttributedString), range: _selectedTextRange.asRange)
        _redoStack.append(object)
        while _redoStack.count > maximumUndoLevel {
            _redoStack.remove(at: 0)
        }
    }
    
    func _canUndo() -> Bool {
        if _undoStack.count == 0 {
            return false
        }
        let object = _undoStack.last
        if object?.text?.isEqual(to: _innerText) ?? false {
            return false
        }
        return true
    }
    
    func _canRedo() -> Bool {
        if _redoStack.count == 0 {
            return false
        }
        let object = _undoStack.last
        if object?.text?.isEqual(to: _innerText) ?? false {
            return false
        }
        return true
    }
    
    func _undo() {
        if !_canUndo() {
            return
        }
        _saveToRedoStack()
        let object = _undoStack.last
        _undoStack.removeLast()
        
        state.insideUndoBlock = true
        _attributedText = (object?.text)!
        _selectedRange = (object?.selectedRange)!
        state.insideUndoBlock = false
    }
    
    func _redo() {
        if !_canRedo() {
            return
        }
        _saveToUndoStack()
        let object = _redoStack.last
        _redoStack.removeLast()
        
        state.insideUndoBlock = true
        _attributedText = (object?.text)! // ?? NSAttributedString()
        _selectedRange = (object?.selectedRange)!
        state.insideUndoBlock = false
    }
    
    func _restoreFirstResponderAfterUndoAlert() {
        if state.firstResponderBeforeUndoAlert {
            perform(#selector(self.becomeFirstResponder), with: nil, afterDelay: 0)
        }
    }
    
    /// Show undo alert if it can undo or redo.
    func _showUndoRedoAlert() {
        #if TARGET_OS_IOS
        state.firstResponderBeforeUndoAlert = isFirstResponder
        weak var _self = self
        let strings = _localizedUndoStrings()
        let canUndo = _canUndo()
        let canRedo = _canRedo()
        
        let ctrl: UIViewController? = _getRootViewController()
        
        if canUndo && canRedo {
            
            let alert = UIAlertController(title: strings[4] as? String, message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: strings[3] as? String, style: .default, handler: { action in
                _self._undo()
                _self._restoreFirstResponderAfterUndoAlert()
            }))
            alert.addAction(UIAlertAction(title: strings[2] as? String, style: .default, handler: { action in
                _self._redo()
                _self._restoreFirstResponderAfterUndoAlert()
            }))
            alert.addAction(UIAlertAction(title: strings[0] as? String, style: .cancel, handler: { action in
                _self._restoreFirstResponderAfterUndoAlert()
            }))
            ctrl?.present(alert, animated: true)
        } else if canUndo {
            
            let alert = UIAlertController(title: strings[4] as? String, message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: strings[3] as? String, style: .default, handler: { action in
                _self._undo()
                _self._restoreFirstResponderAfterUndoAlert()
            }))
            alert.addAction(UIAlertAction(title: strings[0] as? String, style: .cancel, handler: { action in
                _self._restoreFirstResponderAfterUndoAlert()
            }))
            ctrl?.present(alert, animated: true)
        } else if canRedo {
            var alert = UIAlertController(title: strings[2], message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: strings[1], style: .default, handler: { action in
                self._redo()
                self._restoreFirstResponderAfterUndoAlert()
            }))
            alert.addAction(UIAlertAction(title: strings[0], style: .cancel, handler: { action in
                self._restoreFirstResponderAfterUndoAlert()
            }))
            ctrl.present(alert, animated: true)
        }
        #endif
    }
    
    static let localizedUndoStringsDic =
        ["ar": ["إلغاء", "إعادة", "إعادة الكتابة", "تراجع", "تراجع عن الكتابة"], "ca": ["Cancel·lar", "Refer", "Refer l’escriptura", "Desfer", "Desfer l’escriptura"], "cs": ["Zrušit", "Opakovat akci", "Opakovat akci Psát", "Odvolat akci", "Odvolat akci Psát"], "da": ["Annuller", "Gentag", "Gentag Indtastning", "Fortryd", "Fortryd Indtastning"], "de": ["Abbrechen", "Wiederholen", "Eingabe wiederholen", "Widerrufen", "Eingabe widerrufen"], "el": ["Ακύρωση", "Επανάληψη", "Επανάληψη πληκτρολόγησης", "Αναίρεση", "Αναίρεση πληκτρολόγησης"], "en": ["Cancel", "Redo", "Redo Typing", "Undo", "Undo Typing"], "es": ["Cancelar", "Rehacer", "Rehacer escritura", "Deshacer", "Deshacer escritura"], "es_MX": ["Cancelar", "Rehacer", "Rehacer escritura", "Deshacer", "Deshacer escritura"], "fi": ["Kumoa", "Tee sittenkin", "Kirjoita sittenkin", "Peru", "Peru kirjoitus"], "fr": ["Annuler", "Rétablir", "Rétablir la saisie", "Annuler", "Annuler la saisie"], "he": ["ביטול", "חזור על הפעולה האחרונה", "חזור על הקלדה", "בטל", "בטל הקלדה"], "hr": ["Odustani", "Ponovi", "Ponovno upiši", "Poništi", "Poništi upisivanje"], "hu": ["Mégsem", "Ismétlés", "Gépelés ismétlése", "Visszavonás", "Gépelés visszavonása"], "id": ["Batalkan", "Ulang", "Ulang Pengetikan", "Kembalikan", "Batalkan Pengetikan"], "it": ["Annulla", "Ripristina originale", "Ripristina Inserimento", "Annulla", "Annulla Inserimento"], "ja": ["キャンセル", "やり直す", "やり直す - 入力", "取り消す", "取り消す - 入力"], "ko": ["취소", "실행 복귀", "입력 복귀", "실행 취소", "입력 실행 취소"], "ms": ["Batal", "Buat semula", "Ulang Penaipan", "Buat asal", "Buat asal Penaipan"], "nb": ["Avbryt", "Utfør likevel", "Utfør skriving likevel", "Angre", "Angre skriving"], "nl": ["Annuleer", "Opnieuw", "Opnieuw typen", "Herstel", "Herstel typen"], "pl": ["Anuluj", "Przywróć", "Przywróć Wpisz", "Cofnij", "Cofnij Wpisz"], "pt": ["Cancelar", "Refazer", "Refazer Digitação", "Desfazer", "Desfazer Digitação"], "pt_PT": ["Cancelar", "Refazer", "Refazer digitar", "Desfazer", "Desfazer digitar"], "ro": ["Renunță", "Refă", "Refă tastare", "Anulează", "Anulează tastare"], "ru": ["Отменить", "Повторить", "Повторить набор на клавиатуре", "Отменить", "Отменить набор на клавиатуре"], "sk": ["Zrušiť", "Obnoviť", "Obnoviť písanie", "Odvolať", "Odvolať písanie"], "sv": ["Avbryt", "Gör om", "Gör om skriven text", "Ångra", "Ångra skriven text"], "th": ["ยกเลิก", "ทำกลับมาใหม่", "ป้อนกลับมาใหม่", "เลิกทำ", "เลิกป้อน"], "tr": ["Vazgeç", "Yinele", "Yazmayı Yinele", "Geri Al", "Yazmayı Geri Al"], "uk": ["Скасувати", "Повторити", "Повторити введення", "Відмінити", "Відмінити введення"], "vi": ["Hủy", "Làm lại", "Làm lại thao tác Nhập", "Hoàn tác", "Hoàn tác thao tác Nhập"], "zh": ["取消", "重做", "重做键入", "撤销", "撤销键入"], "zh_CN": ["取消", "重做", "重做键入", "撤销", "撤销键入"], "zh_HK": ["取消", "重做", "重做輸入", "還原", "還原輸入"], "zh_TW": ["取消", "重做", "重做輸入", "還原", "還原輸入"]]
    
    static let localizedUndoStrings: [String] = {
        var strings: [String] = []
        
        var preferred = Bundle.main.preferredLocalizations.first ?? ""
        if preferred == "" {
            preferred = "English"
        }
        var canonical = NSLocale.canonicalLocaleIdentifier(from: preferred)
        if canonical == "" {
            canonical = "en"
        }
        strings = localizedUndoStringsDic[canonical] ?? []
        if strings.count == 0 && ((canonical as NSString).range(of: "_").location != NSNotFound) {
            
            if let prefix = canonical.components(separatedBy: "_").first, prefix != "" {
                strings = localizedUndoStringsDic[prefix] ?? []
            }
        }
        if strings.count == 0 {
            strings = localizedUndoStringsDic["en"] ?? []
        }
        
        return strings
    }()
    
    func _localizedUndoStrings() -> [String] {
        return BSTextView.localizedUndoStrings
    }
    
    /// Returns the default font for text view (same as CoreText).
    static let _defaultFont = UIFont.systemFont(ofSize: 12)
    
    /// Returns the default tint color for text view (used for caret and select range background).
    static let _defaultTintColor = UIColor(red: 69 / 255.0, green: 111 / 255.0, blue: 238 / 255.0, alpha: 1)
    
    /// Returns the default placeholder color for text view (same as UITextField).
    static let _defaultPlaceholderColor = UIColor(red: 0, green: 0, blue: 25 / 255.0, alpha: 44 / 255.0)
    
}
