//
//  BSTextView+OverrideUIResponder.swift
//  BSText
//
//  Created by naijoug on 2022/4/16.
//

import UIKit

extension BSTextView {
    
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        _updateIfNeeded()
        let touch = touches.first!
        let point = touch.location(in: _containerView)
        
        _trackingTime = touch.timestamp
        _touchBeganTime = _trackingTime
        _trackingPoint = point
        _touchBeganPoint = _trackingPoint
        _trackingRange = _selectedTextRange
        
        state.trackingGrabber = .none
        state.trackingCaret = false
        state.trackingPreSelect = false
        state.trackingTouch = true
        state.swallowTouch = true
        state.touchMoved = .none
        
        if !isFirstResponder && !state.selectedWithoutEdit && isHighlightable {
            _highlight = _getHighlight(at: point, range: &_highlightRange)
            _highlightLayout = nil
        }
        
        if (!isSelectable && _highlight == nil) || state.ignoreTouchBegan {
            state.swallowTouch = false
            state.trackingTouch = false
        }
        
        if state.trackingTouch {
            _startLongPressTimer()
            if _highlight != nil {
                _showHighlight(animated: false)
            } else {
                if _selectionView.isGrabberContains(point) {
                    // track grabber
                    panGestureRecognizer.isEnabled = false // disable scroll view
                    _hideMenu()
                    state.trackingGrabber = _selectionView.isStartGrabberContains(point) ? .start : .end
                    _magnifierRangedOffset = _getMagnifierRangedOffset()
                } else {
                    if _selectedTextRange.asRange.length == 0 && isFirstResponder {
                        if _selectionView.isCaretContains(point) {
                            // track caret
                            state.trackingCaret = true
                            panGestureRecognizer.isEnabled = false // disable scroll view
                        }
                    }
                }
            }
            _updateSelectionView()
        }
        
        if !state.swallowTouch {
            super.touchesBegan(touches, with: event)
        }
    }
    
    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        _updateIfNeeded()
        let touch = touches.first!
        let point = touch.location(in: _containerView)
        
        _trackingTime = touch.timestamp
        _trackingPoint = point
        
        if state.touchMoved == .none {
            state.touchMoved = _getMoveDirection()
            if state.touchMoved != .none {
                _endLongPressTimer()
            }
        }
        state.clearsOnInsertionOnce = false
        
        if state.trackingTouch {
            var showMagnifierCaret = false
            var showMagnifierRanged = false
            
            if _highlight != nil {
                
                let highlight = _getHighlight(at: _trackingPoint, range: nil)
                if highlight == _highlight {
                    _showHighlight(animated: true)
                } else {
                    _hideHighlight(animated: true)
                }
            } else {
                _trackingRange = _selectedTextRange
                if state.trackingGrabber != .none {
                    panGestureRecognizer.isEnabled = false
                    _hideMenu()
                    _updateTextRangeByTrackingGrabber()
                    showMagnifierRanged = true
                } else if state.trackingPreSelect {
                    _updateTextRangeByTrackingPreSelect()
                    showMagnifierCaret = true
                } else if state.trackingCaret || (_markedTextRange != nil) || isFirstResponder {
                    if state.trackingCaret || state.touchMoved != .none {
                        state.trackingCaret = true
                        _hideMenu()
                        if isVerticalForm {
                            if state.touchMoved == .top || state.touchMoved == .bottom {
                                panGestureRecognizer.isEnabled = false
                            }
                        } else {
                            if state.touchMoved == .left || state.touchMoved == .right {
                                panGestureRecognizer.isEnabled = false
                            }
                        }
                        _updateTextRangeByTrackingCaret()
                        if _markedTextRange != nil {
                            showMagnifierRanged = true
                        } else {
                            showMagnifierCaret = true
                        }
                    }
                }
            }
            _updateSelectionView()
            if showMagnifierCaret {
                _showMagnifierCaret()
            }
            if showMagnifierRanged {
                _showMagnifierRanged()
            }
        }
        
        let autoScrollOffset: CGFloat = _getAutoscrollOffset()
        if autoScrollOffset != _autoScrollOffset {
            if abs(Float(autoScrollOffset)) < abs(Float(_autoScrollOffset)) {
//                _autoScrollAcceleration *= 0.5
                _autoScrollAcceleration /= 2
            }
            _autoScrollOffset = autoScrollOffset
            if _autoScrollOffset != 0 && state.touchMoved != .none {
                _startAutoScrollTimer()
            }
        }
        
        if !state.swallowTouch {
            super.touchesMoved(touches, with: event)
        }
    }
    
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        _updateIfNeeded()
        
        let touch = touches.first!
        let point = touch.location(in: _containerView)
        
        _trackingTime = touch.timestamp
        _trackingPoint = point
        
        if state.touchMoved == .none {
            state.touchMoved = _getMoveDirection()
        }
        if state.trackingTouch {
            _hideMagnifier()
            
            if _highlight != nil {
                if state.showingHighlight {
                    if _highlight!.tapAction != nil {
                        var rect: CGRect = _innerLayout!.rect(for: TextRange(range: _highlightRange))
                        rect = _convertRect(fromLayout: rect)
                        _highlight!.tapAction!(self, _innerText, _highlightRange, rect)
                    } else {
                        var shouldTap = true
                        if let t = _outerDelegate?.textView?(self, shouldTap: _highlight!, in: _highlightRange) {
                            shouldTap = t
                        }
                        if shouldTap {
                            var rect = _innerLayout!.rect(for: TextRange(range: _highlightRange))
                            rect = _convertRect(fromLayout: rect)
                            _outerDelegate?.textView?(self, didTap: _highlight!, in: _highlightRange, rect: rect)
                        }
                    }
                    _removeHighlight(animated: true)
                }
            } else {
                if state.trackingCaret {
                    if state.touchMoved != .none {
                        _updateTextRangeByTrackingCaret()
                        _showMenu()
                    } else {
                        if state.showingMenu {
                            _hideMenu()
                        } else {
                            _showMenu()
                        }
                    }
                } else if state.trackingGrabber != .none {
                    _updateTextRangeByTrackingGrabber()
                    _showMenu()
                } else if state.trackingPreSelect {
                    _updateTextRangeByTrackingPreSelect()
                    if _trackingRange!.asRange.length > 0 {
                        state.selectedWithoutEdit = true
                        _showMenu()
                    } else {
                        perform(#selector(self.becomeFirstResponder), with: nil, afterDelay: 0)
                    }
                } else if state.deleteConfirm || (markedTextRange != nil) {
                    _updateTextRangeByTrackingCaret()
                    _hideMenu()
                } else {
                    if state.touchMoved == .none {
                        if state.selectedWithoutEdit {
                            state.selectedWithoutEdit = false
                            _hideMenu()
                        } else {
                            if isFirstResponder {
                                let oldRange = _trackingRange
                                _updateTextRangeByTrackingCaret()
                                if oldRange == _trackingRange {
                                    if state.showingMenu {
                                        _hideMenu()
                                    } else {
                                        _showMenu()
                                    }
                                } else {
                                    _hideMenu()
                                }
                            } else {
                                _hideMenu()
                                if state.clearsOnInsertionOnce {
                                    state.clearsOnInsertionOnce = false
                                    _selectedTextRange = TextRange(range: NSRange(location: 0, length: _innerText.length))
                                    _setSelectedRange(_selectedTextRange.asRange)
                                } else {
                                    _updateTextRangeByTrackingCaret()
                                }
                                perform(#selector(self.becomeFirstResponder), with: nil, afterDelay: 0)
                            }
                        }
                    }
                }
            }
            if _trackingRange != nil && (!(_trackingRange == _selectedTextRange) || state.trackingPreSelect) {
                if !(_trackingRange == _selectedTextRange) {
                    _inputDelegate?.selectionWillChange(self)
                    _selectedTextRange = _trackingRange!
                    _inputDelegate?.selectionDidChange(self)
                    _updateAttributesHolder()
                    _updateOuterProperties()
                }
                if state.trackingGrabber == .none && !state.trackingPreSelect {
                    _scrollRangeToVisible(_selectedTextRange)
                }
            }
            
            _endTouchTracking()
        }
        if !state.swallowTouch {
            super.touchesEnded(touches, with: event)
        }
    }
    
    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        _endTouchTracking()
        _hideMenu()
        
        if !state.swallowTouch {
            super.touchesCancelled(touches, with: event)
        }
    }
    
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        
        if motion == .motionShake && allowsUndoAndRedo {
            if !TextUtilities.isAppExtension {
                _showUndoRedoAlert()
            }
        } else {
            super.motionEnded(motion, with: event)
        }
    }
    
    override open var canBecomeFirstResponder: Bool {
        if !isSelectable {
            return false
        }
        if !isEditable {
            return false
        }
        if state.ignoreFirstResponder {
            return false
        }
        if let should = _outerDelegate?.textViewShouldBeginEditing?(self) {
            if !should {
                return false
            }
        }
        return true
    }
    
    @discardableResult
    open override func becomeFirstResponder() -> Bool {
        let isFirstResponder: Bool = self.isFirstResponder
        if isFirstResponder {
            return true
        }
        let shouldDetectData = _shouldDetectText()
        let become: Bool = super.becomeFirstResponder()
        if !isFirstResponder && become {
            _endTouchTracking()
            _hideMenu()
            
            state.selectedWithoutEdit = false
            if shouldDetectData != _shouldDetectText() {
                _update()
            }
            _updateIfNeeded()
            _updateSelectionView()
            perform(#selector(self._scrollSelectedRangeToVisible), with: nil, afterDelay: 0)
            
            _outerDelegate?.textViewDidBeginEditing?(self)
                
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: BSTextView.textViewTextDidBeginEditingNotification), object: self)
        }
        return become
    }
    
    open override var canResignFirstResponder: Bool {
        guard isFirstResponder else { return true }
        return _outerDelegate?.textViewShouldEndEditing?(self) ?? true
    }
    
    @discardableResult
    override open func resignFirstResponder() -> Bool {
        let isFirstResponder: Bool = self.isFirstResponder
        if !isFirstResponder {
            return true
        }
        let resign: Bool = super.resignFirstResponder()
        if resign {
            if (markedTextRange != nil) {
                markedTextRange = nil
                _parseText()
                _setText(_innerText.bs_plainText(for: NSRange(location: 0, length: _innerText.length)))
            }
            state.selectedWithoutEdit = false
            if _shouldDetectText() {
                _update()
            }
            _endTouchTracking()
            _hideMenu()
            _updateIfNeeded()
            _updateSelectionView()
            _restoreInsets(animated: true)
            
            _outerDelegate?.textViewDidEndEditing?(self)
            
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: BSTextView.textViewTextDidEndEditingNotification), object: self)
        }
        return resign
    }
    
    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        /*
         ------------------------------------------------------
         Default menu actions list:
         cut:                                   Cut
         copy:                                  Copy
         select:                                Select
         selectAll:                             Select All
         paste:                                 Paste
         delete:                                Delete
         _promptForReplace:                     Replace...
         _transliterateChinese:                 简⇄繁
         _showTextStyleOptions:                 𝐁𝐼𝐔
         _define:                               Define
         _addShortcut:                          Add...
         _accessibilitySpeak:                   Speak
         _accessibilitySpeakLanguageSelection:  Speak...
         _accessibilityPauseSpeaking:           Pause Speak
         makeTextWritingDirectionRightToLeft:   ⇋
         makeTextWritingDirectionLeftToRight:   ⇌
         
         ------------------------------------------------------
         Default attribute modifier list:
         toggleBoldface:
         toggleItalics:
         toggleUnderline:
         increaseSize:
         decreaseSize:
         */
        
        if _selectedTextRange.asRange.length == 0 {
            if action == #selector(self.select(_:)) || action == #selector(self.selectAll(_:)) {
                return _innerText.length > 0
            }
            if action == #selector(self.paste(_:)) {
                return _isPasteboardContainsValidValue()
            }
        } else {
            if action == #selector(self.cut(_:)) {
                return isFirstResponder && isEditable
            }
            if action == #selector(self.copy(_:)) {
                return true
            }
            if action == #selector(self.selectAll(_:)) {
                return _selectedTextRange.asRange.length < _innerText.length
            }
            if action == #selector(self.paste(_:)) {
                return isFirstResponder && isEditable && _isPasteboardContainsValidValue()
            }
            let selString = NSStringFromSelector(action)
            if selString.hasSuffix("define:") && selString.hasPrefix("_") {
                return _getRootViewController() != nil
            }
        }
        return false
    }
    
    override open func reloadInputViews() {
        super.reloadInputViews()
        if (markedTextRange != nil) {
            unmarkText()
        }
    }
    
}
