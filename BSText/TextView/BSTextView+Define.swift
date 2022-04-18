//
//  BSTextView+Define.swift
//  BSText
//
//  Created by naijoug on 2022/4/16.
//

import UIKit

/**
 The TextViewDelegate protocol defines a set of optional methods you can use
 to receive editing-related messages for BSTextView objects.
 
 @discussion The API and behavior is similar to UITextViewDelegate,
 see UITextViewDelegate's documentation for more information.
 */
@objc public protocol TextViewDelegate: UIScrollViewDelegate {
    
    @objc optional func textViewShouldBeginEditing(_ textView: BSTextView) -> Bool
    @objc optional func textViewShouldEndEditing(_ textView: BSTextView) -> Bool
    @objc optional func textViewDidBeginEditing(_ textView: BSTextView)
    @objc optional func textViewDidEndEditing(_ textView: BSTextView)
    @objc optional func textView(_ textView: BSTextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    @objc optional func textViewDidChange(_ textView: BSTextView)
    @objc optional func textViewDidChangeSelection(_ textView: BSTextView)
    @objc optional func textView(_ textView: BSTextView, shouldTap highlight: TextHighlight, in characterRange: NSRange) -> Bool
    @objc optional func textView(_ textView: BSTextView, didTap highlight: TextHighlight, in characterRange: NSRange, rect: CGRect)
    @objc optional func textView(_ textView: BSTextView, shouldLongPress highlight: TextHighlight, in characterRange: NSRange) -> Bool
    @objc optional func textView(_ textView: BSTextView, didLongPress highlight: TextHighlight, in characterRange: NSRange, rect: CGRect)
}

extension BSTextView {
    
    static let kDefaultUndoLevelMax: Int = 20

    static let kAutoScrollMinimumDuration = 0.1
    static let kLongPressMinimumDuration = 0.5
    static let kLongPressAllowableMovement: Float = 10.0

    static let kMagnifierRangedTrackFix: CGFloat = -6
    static let kMagnifierRangedPopoverOffset: CGFloat = 4
    static let kMagnifierRangedCaptureOffset: CGFloat = -6

    static let kHighlightFadeDuration: TimeInterval = 0.15

    static let kDefaultInset = UIEdgeInsets(top: 6, left: 4, bottom: 6, right: 4)
    static let kDefaultVerticalInset = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
    
}

public enum TextGrabberDirection : UInt {
    case none = 0
    case start = 1
    case end = 2
}

public enum TextMoveDirection : UInt {
    case none = 0
    case left = 1
    case top = 2
    case right = 3
    case bottom = 4
}

/// An object that captures the state of the text view. Used for undo and redo.
class TextViewUndoObject: NSObject {
    
    var text: NSAttributedString?
    var selectedRange: NSRange?
    
    override init() {
        super.init()
    }
    
    convenience init(text: NSAttributedString?, range: NSRange) {
        self.init()
        self.text = text ?? NSAttributedString()
        self.selectedRange = range
    }
}

extension BSTextView {
    
    struct State {
        ///< TextGrabberDirection, current tracking grabber
        var trackingGrabber = TextGrabberDirection.none
        ///< track the caret
        var trackingCaret = false
        ///< track pre-select
        var trackingPreSelect = false
        ///< is in touch phase
        var trackingTouch = false
        ///< don't forward event to next responder
        var swallowTouch = false
        ///< TextMoveDirection, move direction after touch began
        var touchMoved = TextMoveDirection.none
        ///< show selected range but not first responder
        var selectedWithoutEdit = false
        ///< delete a binding text range
        var deleteConfirm = false
        ///< ignore become first responder temporary
        var ignoreFirstResponder = false
        ///< ignore begin tracking touch temporary
        var ignoreTouchBegan = false
        
        var showingMagnifierCaret = false
        var showingMagnifierRanged = false
        var showingMenu = false
        var showingHighlight = false
        
        ///< apply the typing attributes once
        var typingAttributesOnce = false
        ///< select all once when become first responder
        var clearsOnInsertionOnce = false
        ///< auto scroll did tick scroll at this timer period
        var autoScrollTicked = false
        ///< the selection grabber dot has displayed at least once
        var firstShowDot = false
        ///< the layout or selection view is 'dirty' and need update
        var needUpdate = false
        ///< the placeholder need update it's contents
        var placeholderNeedUpdate = false
        
        var insideUndoBlock = false
        var firstResponderBeforeUndoAlert = false
    }
    
}
