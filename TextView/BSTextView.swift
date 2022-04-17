//
//  BSTextView.swift
//  BSText
//
//  Created by BlueSky on 2018/12/20.
//  Copyright © 2019 GeekBruce. All rights reserved.
//

import UIKit
#if canImport(YYImage)
import YYImage
#endif

// ===> BSTextView+Type

/**
 The BSTextView class implements the behavior for a scrollable, multiline text region.
 
 @discussion The API and behavior is similar to UITextView, but provides more features:
 
 * It extends the CoreText attributes to support more text effects.
 * It allows to add UIImage, UIView and CALayer as text attachments.
 * It allows to add 'highlight' link to some range of text to allow user interact with.
 * It allows to add exclusion paths to control text container's shape.
 * It supports vertical form layout to display and edit CJK text.
 * It allows user to copy/paste image and attributed text from/to text view.
 * It allows to set an attributed text as placeholder.
 
 See NSAttributedStringExtension.swift for more convenience methods to set the attributes.
 See TextAttribute.swift and TextLayout.swift for more information.
 */
open class BSTextView: UIScrollView, UITextInput, UITextInputTraits, UIScrollViewDelegate, UIAlertViewDelegate, TextDebugTarget, TextKeyboardObserver, NSSecureCoding {
    
    public lazy var tokenizer: UITextInputTokenizer = UITextInputStringTokenizer(textInput: UITextView())
    public var markedTextRange: UITextRange?
    
    @objc public static let textViewTextDidBeginEditingNotification = "TextViewTextDidBeginEditing"
    @objc public static let textViewTextDidChangeNotification = "TextViewTextDidChange"
    @objc public static let textViewTextDidEndEditingNotification = "TextViewTextDidEndEditing"
    
    // MARK: - Accessing the Delegate
    ///*****************************************************************************
    /// @name Accessing the Delegate
    ///*****************************************************************************
    @objc open weak override var delegate: UIScrollViewDelegate? {
        set {
            _outerDelegate = newValue as? TextViewDelegate
        }
        get {
            return _outerDelegate
        }
    }
    
    // MARK: - Configuring the Text Attributes
    ///*****************************************************************************
    /// @name Configuring the Text Attributes
    ///*****************************************************************************
    
    var _text = ""
    /**
     The text displayed by the text view.
     Set a new value to this property also replaces the text in `attributedText`.
     Get the value returns the plain text in `attributedText`.
     */
    @objc public var text: String {
        set {
            if _text == newValue {
                return
            }
            _setText(newValue)
            
            state.selectedWithoutEdit = false
            state.deleteConfirm = false
            _endTouchTracking()
            _hideMenu()
            _resetUndoAndRedoStack()
            replace(TextRange(range: NSRange(location: 0, length: _innerText.length)), withText: _text)
        }
        get {
            return _text
        }
    }
    
    lazy var _font: UIFont? = BSTextView._defaultFont
    /**
     The font of the text. Default is 12-point system font.
     Set a new value to this property also causes the new font to be applied to the entire `attributedText`.
     Get the value returns the font at the head of `attributedText`.
     */
    @objc public var font: UIFont? {
        set {
            if _font == newValue {
                return
            }
            _setFont(newValue)
            
            state.typingAttributesOnce = false
            _typingAttributesHolder.bs_font = newValue
            _innerText.bs_font = newValue
            _resetUndoAndRedoStack()
            _commitUpdate()
        }
        get {
            return _font
        }
    }
    
    var _textColor: UIColor? = UIColor.black
    /**
     The color of the text. Default is black.
     Set a new value to this property also causes the new color to be applied to the entire `attributedText`.
     Get the value returns the color at the head of `attributedText`.
     */
    @objc public var textColor: UIColor? {
        set {
            if _textColor == newValue {
                return
            }
            _setTextColor(newValue)
            
            state.typingAttributesOnce = false
            _typingAttributesHolder.bs_color = newValue
            _innerText.bs_color = newValue
            _resetUndoAndRedoStack()
            _commitUpdate()
        }
        get {
            return _textColor
        }
    }
    
    var _textAlignment = NSTextAlignment.natural
    /**
     The technique to use for aligning the text. Default is NSTextAlignmentNatural.
     Set a new value to this property also causes the new alignment to be applied to the entire `attributedText`.
     Get the value returns the alignment at the head of `attributedText`.
     */
    @objc public var textAlignment: NSTextAlignment {
        set {
            if _textAlignment == newValue {
                return
            }
            _setTextAlignment(newValue)
            
            _typingAttributesHolder.bs_alignment = newValue
            _innerText.bs_alignment = newValue
            _resetUndoAndRedoStack()
            _commitUpdate()
        }
        get {
            return _textAlignment
        }
    }
    
    var _textVerticalAlignment = TextVerticalAlignment.top
    /**
     The text vertical aligmnent in container. Default is TextVerticalAlignmentTop.
     */
    @objc public var textVerticalAlignment: TextVerticalAlignment {
        set {
            if _textVerticalAlignment == newValue {
                return
            }
            willChangeValue(forKey: "textVerticalAlignment")
            _textVerticalAlignment = newValue
            didChangeValue(forKey: "textVerticalAlignment")
            _containerView.textVerticalAlignment = newValue
            _commitUpdate()
        }
        get {
            return _textVerticalAlignment
        }
    }
    
    var _dataDetectorTypes = UIDataDetectorTypes.init(rawValue: 0)
    /**
     The types of data converted to clickable URLs in the text view. Default is UIDataDetectorTypeNone.
     The tap or long press action should be handled by delegate.
     */
    @objc public var dataDetectorTypes: UIDataDetectorTypes {
        set {
            if _dataDetectorTypes == newValue {
                return
            }
            _setDataDetectorTypes(newValue)
            let type = TextUtilities.textCheckingType(from: newValue)
            _dataDetector = type.rawValue != 0 ? try? NSDataDetector(types: type.rawValue) : nil
            _resetUndoAndRedoStack()
            _commitUpdate()
        }
        get {
            return _dataDetectorTypes
        }
    }
    
    var _linkTextAttributes: [NSAttributedString.Key : Any]?
    /**
     The attributes to apply to links at normal state. Default is light blue color.
     When a range of text is detected by the `dataDetectorTypes`, this value would be
     used to modify the original attributes in the range.
     */
    @objc public var linkTextAttributes: [NSAttributedString.Key : Any]? {
        set {
            let dic1 = _linkTextAttributes as NSDictionary?, dic2 = newValue as NSDictionary?
            if dic1 == dic2 || dic1?.isEqual(dic2) ?? false {
                return
            }
            _setLinkTextAttributes(newValue)
            if _dataDetector != nil {
                _commitUpdate()
            }
        }
        get {
            return _linkTextAttributes
        }
    }
    
    var _highlightTextAttributes: [NSAttributedString.Key : Any]?
    /**
     The attributes to apply to links at highlight state. Default is a gray border.
     When a range of text is detected by the `dataDetectorTypes` and the range was touched by user,
     this value would be used to modify the original attributes in the range.
     */
    @objc public var highlightTextAttributes: [NSAttributedString.Key : Any]? {
        set {
            let dic1 = _highlightTextAttributes as NSDictionary?, dic2 = newValue as NSDictionary?
            if dic1 == dic2 || dic1?.isEqual(dic2) ?? false {
                return
            }
            _setHighlightTextAttributes(newValue)
            if _dataDetector != nil {
                _commitUpdate()
            }
        }
        get {
            return _highlightTextAttributes
        }
    }
    
    var _typingAttributes: [NSAttributedString.Key : Any]?
    /**
     The attributes to apply to new text being entered by the user.
     When the text view's selection changes, this value is reset automatically.
     */
    @objc public var typingAttributes: [NSAttributedString.Key : Any]? {
        set {
            _setTypingAttributes(newValue)
            state.typingAttributesOnce = true
            for (key, obj) in newValue ?? [:] {
                self._typingAttributesHolder.bs_set(attribute: key, value: obj)
            }
            _commitUpdate()
        }
        get {
            return _typingAttributes
        }
    }
    
    
    var _attributedText = NSAttributedString()
    /**
     The styled text displayed by the text view.
     Set a new value to this property also replaces the value of the `text`, `font`, `textColor`,
     `textAlignment` and other properties in text view.
     
     @discussion It only support the attributes declared in CoreText and TextAttribute.
     See `NSAttributedStringExtension.swift` for more convenience methods to set the attributes.
     */
    @objc public var attributedText: NSAttributedString? {
        get {
            return _attributedText
        }
        set {
            if _attributedText == newValue {
                return
            }
            _setAttributedText(newValue)
            state.typingAttributesOnce = false
            
            let text = _attributedText as? NSMutableAttributedString
            if text?.length ?? 0 == 0 {
                replace(TextRange(range: NSRange(location: 0, length: _innerText.length)), withText: "")
                return
            }
            if let should = _outerDelegate?.textView?(self, shouldChangeTextIn: NSRange(location: 0, length: _innerText.length), replacementText: text?.string ?? "") {
                if !should {
                    return
                }
            }
            
            state.selectedWithoutEdit = false
            state.deleteConfirm = false
            _endTouchTracking()
            _hideMenu()
            
            _inputDelegate?.selectionWillChange(self)
            _inputDelegate?.textWillChange(self)
            _innerText = text!
            _parseText()
            _selectedTextRange = TextRange(range: NSRange(location: 0, length: _innerText.length))
            _inputDelegate?.textDidChange(self)
            _inputDelegate?.selectionDidChange(self)
            
            _setAttributedText(text)
            if _innerText.length > 0 {
                _typingAttributesHolder.bs_attributes = _innerText.bs_attributes(at: _innerText.length - 1)
            }
            
            _updateOuterProperties()
            _updateLayout()
            _updateSelectionView()
            
            if isFirstResponder {
                _scrollRangeToVisible(_selectedTextRange)
            }
            
            _outerDelegate?.textViewDidChange?(self)
            
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: BSTextView.textViewTextDidChangeNotification), object: self)
            
            if !state.insideUndoBlock {
                _resetUndoAndRedoStack()
            }
        }
    }
    
    var _textParser: TextParser?
    /**
     When `text` or `attributedText` is changed, the parser will be called to modify the text.
     It can be used to add code highlighting or emoticon replacement to text view.
     The default value is nil.
     
     See `TextParser` protocol for more information.
     */
    @objc public var textParser: TextParser? {
        set {
            if _textParser === newValue || _textParser?.isEqual(newValue) ?? false {
                return
            }
            _setTextParser(newValue)
            if textParser != nil && text != "" {
                replace(TextRange(range: NSRange(location: 0, length: text.length)), withText: text)
            }
            _resetUndoAndRedoStack()
            _commitUpdate()
        }
        get {
            return _textParser
        }
    }
    
    /**
     The current text layout in text view (readonly).
     It can be used to query the text layout information.
     */
    @objc public private(set) var textLayout: TextLayout? {
        set {
            
        }
        get {
            _updateIfNeeded()
            return _innerLayout
        }
    }
    
    
    // MARK: - Configuring the Placeholder
    ///*****************************************************************************
    /// @name Configuring the Placeholder
    ///*****************************************************************************
    
    var _placeholderText: String?
    /**
     The placeholder text displayed by the text view (when the text view is empty).
     Set a new value to this property also replaces the text in `placeholderAttributedText`.
     Get the value returns the plain text in `placeholderAttributedText`.
     */
    @objc public var placeholderText: String? {
        set {
            if _placeholderAttributedText?.length ?? 0 > 0 {
                
                (_placeholderAttributedText as? NSMutableAttributedString)?.replaceCharacters(in: NSRange(location: 0, length: _placeholderAttributedText!.length), with: newValue ?? "")
                
                (_placeholderAttributedText as? NSMutableAttributedString)?.bs_font = placeholderFont
                (_placeholderAttributedText as? NSMutableAttributedString)?.bs_color = placeholderTextColor
            } else {
                if (newValue?.length ?? 0) > 0 {
                    let atr = NSMutableAttributedString(string: newValue!)
                    if _placeholderFont == nil {
                        _placeholderFont = _font ?? BSTextView._defaultFont
                    }
                    if _placeholderTextColor == nil {
                        _placeholderTextColor = BSTextView._defaultPlaceholderColor
                    }
                    atr.bs_font = _placeholderFont
                    atr.bs_color = _placeholderTextColor
                    _placeholderAttributedText = atr
                }
            }
            _placeholderText = _placeholderAttributedText?.bs_plainText(for: NSRange(location: 0, length: _placeholderAttributedText!.length))
            _commitPlaceholderUpdate()
        }
        get {
            return _placeholderText
        }
    }
    
    var _placeholderFont: UIFont?
    /**
     The font of the placeholder text. Default is same as `font` property.
     Set a new value to this property also causes the new font to be applied to the entire `placeholderAttributedText`.
     Get the value returns the font at the head of `placeholderAttributedText`.
     */
    @objc public var placeholderFont: UIFont? {
        set {
            _placeholderFont = newValue
            (_placeholderAttributedText as? NSMutableAttributedString)?.bs_font = _placeholderFont
            _commitPlaceholderUpdate()
        }
        get {
            return _placeholderFont
        }
    }
    
    var _placeholderTextColor: UIColor?
    /**
     The color of the placeholder text. Default is gray.
     Set a new value to this property also causes the new color to be applied to the entire `placeholderAttributedText`.
     Get the value returns the color at the head of `placeholderAttributedText`.
     */
    @objc public var placeholderTextColor: UIColor? {
        set {
            _placeholderTextColor = newValue
            (_placeholderAttributedText as? NSMutableAttributedString)?.bs_color = _placeholderTextColor
            _commitPlaceholderUpdate()
        }
        get {
            return _placeholderTextColor
        }
    }
    
    var _placeholderAttributedText: NSAttributedString?
    /**
     The styled placeholder text displayed by the text view (when the text view is empty).
     Set a new value to this property also replaces the value of the `placeholderText`,
     `placeholderFont`, `placeholderTextColor`.
     
     @discussion It only support the attributes declared in CoreText and TextAttribute.
     See `NSAttributedStringExtension.swift` for more convenience methods to set the attributes.
     */
    @objc public var placeholderAttributedText: NSAttributedString? {
        set {
            _placeholderAttributedText = newValue
            _placeholderText = placeholderAttributedText?.bs_plainText(for: NSRange(location: 0, length: _placeholderAttributedText!.length))
            _placeholderFont = _placeholderAttributedText?.bs_font
            _placeholderTextColor = _placeholderAttributedText?.bs_color
            _commitPlaceholderUpdate()
        }
        get {
            return _placeholderAttributedText
        }
    }
    
    
    // MARK: - Configuring the Text Container
    ///*****************************************************************************
    /// @name Configuring the Text Container
    ///*****************************************************************************
    
    var _textContainerInset = kDefaultInset
    /**
     The inset of the text container's layout area within the text view's content area.
     */
    @objc public var textContainerInset: UIEdgeInsets {
        get {
            return _textContainerInset
        }
        set {
            if _textContainerInset == newValue {
                return
            }
            _setTextContainerInset(newValue)
            _innerContainer.insets = newValue
            _commitUpdate()
        }
    }
    
    var _exclusionPaths: [UIBezierPath]?
    /**
     An array of UIBezierPath objects representing the exclusion paths inside the
     receiver's bounding rectangle. Default value is nil.
     */
    @objc public var exclusionPaths: [UIBezierPath]? {
        get {
            return _exclusionPaths
        }
        set {
            if _exclusionPaths == newValue {
                return
            }
            _setExclusionPaths(newValue)
            _innerContainer.exclusionPaths = newValue
            
            if _innerContainer.isVerticalForm {
                let trans = CGAffineTransform(translationX: _innerContainer.size.width - bounds.size.width, y: 0)
                (_innerContainer.exclusionPaths as NSArray?)?.enumerateObjects({ path, idx, stop in
                    (path as! UIBezierPath).apply(trans)
                })
            }
            _commitUpdate()
        }
    }
    
    var _verticalForm = false
    /**
     Whether the receiver's layout orientation is vertical form. Default is NO.
     It may used to edit/display CJK text.
     */
    @objc public var isVerticalForm: Bool {
        get {
            return _verticalForm
        }
        set {
            if _verticalForm == newValue {
                return
            }
            _setVerticalForm(newValue)
            _innerContainer.isVerticalForm = newValue
            _selectionView.verticalForm = newValue
            
            _updateInnerContainerSize()
            
            if isVerticalForm {
                if _innerContainer.insets == BSTextView.kDefaultInset {
                    _innerContainer.insets = BSTextView.kDefaultVerticalInset
                    _setTextContainerInset(BSTextView.kDefaultVerticalInset)
                }
            } else {
                if _innerContainer.insets == BSTextView.kDefaultVerticalInset {
                    _innerContainer.insets = BSTextView.kDefaultInset
                    _setTextContainerInset(BSTextView.kDefaultInset)
                }
            }
            
            _innerContainer.exclusionPaths = exclusionPaths
            if newValue {
                let trans = CGAffineTransform(translationX: _innerContainer.size.width - bounds.size.width, y: 0)
                for path in _innerContainer.exclusionPaths ?? [] {
                    path.apply(trans)
                }
            }
            
            _keyboardChanged()
            _commitUpdate()
        }
    }
    
    var _linePositionModifier: TextLinePositionModifier?
    /**
     The text line position modifier used to modify the lines' position in layout.
     See `TextLinePositionModifier` protocol for more information.
     */
    @objc public weak var linePositionModifier: TextLinePositionModifier? {
        set {
            if _linePositionModifier === newValue || _linePositionModifier?.isEqual(newValue) ?? false {
                return
            }
            _setLinePositionModifier(newValue)
            _innerContainer.linePositionModifier = newValue
            _commitUpdate()
        }
        get {
            return _linePositionModifier
        }
    }
    
    /**
     The debug option to display CoreText layout result.
     The default value is [TextDebugOption sharedDebugOption].
     */
    @objc public var debugOption: TextDebugOption? { // = TextDebugOption.shared {
        set {
            _containerView.debugOption = newValue
        }
        get {
            return _containerView.debugOption
        }
    }
    
    
    // MARK: - Working with the Selection and Menu
    ///*****************************************************************************
    /// @name Working with the Selection and Menu
    ///*****************************************************************************
    
    /**
     Scrolls the receiver until the text in the specified range is visible.
     */
    @objc public func scrollRangeToVisible(_ range: NSRange) {
        var textRange = TextRange(range: range)
        textRange = _correctedTextRange(textRange)!
        _scrollRangeToVisible(textRange)
    }
    
    var _selectedRange = NSRange(location: 0, length: 0)
    /**
     The current selection range of the receiver.
     */
    @objc public var selectedRange: NSRange {
        get {
            return _selectedRange
        }
        set {
            if NSEqualRanges(_selectedRange, newValue) {
                return
            }
            if (_markedTextRange != nil) {
                return
            }
            state.typingAttributesOnce = false
            
            var range = TextRange(range: newValue)
            range = _correctedTextRange(range)!
            _endTouchTracking()
            _selectedTextRange = range
            _updateSelectionView()
            
            _setSelectedRange(range.asRange)
            
            if !state.insideUndoBlock {
                _resetUndoAndRedoStack()
            }
        }
    }
    
    /**
     A Boolean value indicating whether inserting text replaces the previous contents.
     The default value is NO.
     */
    @objc public var clearsOnInsertion = false {
        didSet {
            if clearsOnInsertion == oldValue {
                return
            }
            if clearsOnInsertion {
                if isFirstResponder {
                    selectedRange = NSRange(location: 0, length: _attributedText.length)
                } else {
                    state.clearsOnInsertionOnce = true
                }
            }
        }
    }
    
    /**
     A Boolean value indicating whether the receiver is isSelectable. Default is YES.
     When the value of this property is NO, user cannot select content or edit text.
     */
    @objc public var isSelectable = true {
        didSet {
            if isSelectable == oldValue {
                return
            }
            if !isSelectable {
                if isFirstResponder {
                    resignFirstResponder()
                } else {
                    state.selectedWithoutEdit = false
                    _endTouchTracking()
                    _hideMenu()
                    _updateSelectionView()
                }
            }
        }
    }
    
    /**
     A Boolean value indicating whether the receiver is isHighlightable. Default is YES.
     When the value of this property is NO, user cannot interact with the highlight range of text.
     */
    @objc public var isHighlightable = true {
        didSet {
            if isHighlightable == oldValue {
                return
            }
            _commitUpdate()
        }
    }
    
    /**
     A Boolean value indicating whether the receiver is isEditable. Default is YES.
     When the value of this property is NO, user cannot edit text.
     */
    @objc public var isEditable = true {
        didSet {
            if isEditable == oldValue {
                return
            }
            if !isEditable {
                resignFirstResponder()
            }
        }
    }
    
    
    /**
     A Boolean value indicating whether the receiver can paste image from pasteboard. Default is NO.
     When the value of this property is YES, user can paste image from pasteboard via "paste" menu.
     */
    @objc public var allowsPasteImage = false
    
    /**
     A Boolean value indicating whether the receiver can paste attributed text from pasteboard. Default is NO.
     When the value of this property is YES, user can paste attributed text from pasteboard via "paste" menu.
     */
    @objc public var allowsPasteAttributedString = false
    
    /**
     A Boolean value indicating whether the receiver can copy attributed text to pasteboard. Default is YES.
     When the value of this property is YES, user can copy attributed text (with attachment image)
     from text view to pasteboard via "copy" menu.
     */
    @objc public var allowsCopyAttributedString = true
    
    // MARK: - Manage the undo and redo
    ///*****************************************************************************
    /// @name Manage the undo and redo
    ///*****************************************************************************
    
    /**
     A Boolean value indicating whether the receiver can undo and redo typing with
     shake gesture. The default value is YES.
     */
    @objc public var allowsUndoAndRedo = true
    
    /**
     The maximum undo/redo level. The default value is 20.
     */
    @objc public var maximumUndoLevel: Int = kDefaultUndoLevelMax
    
    
    // MARK: - Replacing the System Input Views
    ///*****************************************************************************
    /// @name Replacing the System Input Views
    ///*****************************************************************************
    
    var _inputView: UIView?
    /**
     The custom input view to display when the text view becomes the first responder.
     It can be used to replace system keyboard.
     
     @discussion If set the value while first responder, it will not take effect until
     'reloadInputViews' is called.
     */
    open override var inputView: UIView? {      // kind of UIView
        set {
            _inputView = newValue
        }
        get {
            return _inputView
        }
    }
    
    var _inputAccessoryView: UIView?
    /**
     The custom accessory view to display when the text view becomes the first responder.
     It can be used to add a toolbar at the top of keyboard.
     
     @discussion If set the value while first responder, it will not take effect until
     'reloadInputViews' is called.
     */
    open override var inputAccessoryView: UIView? {      // kind of UIView
        set {
            _inputAccessoryView = newValue
        }
        get {
            return _inputAccessoryView
        }
    }
    /**
     If you use an custom accessory view without "inputAccessoryView" property,
     you may set the accessory view's height. It may used by auto scroll calculation.
     */
    @objc public var extraAccessoryViewHeight: CGFloat = 0
    
    
    lazy var _selectedTextRange = TextRange.default() /// nonnull
    var _markedTextRange: TextRange?
    
    weak var _outerDelegate: TextViewDelegate?
    
    var _placeHolderView = UIImageView()
    
    lazy var _innerText = NSMutableAttributedString() ///< nonnull, inner attributed text
    var _delectedText: NSMutableAttributedString? ///< detected text for display
    lazy var _innerContainer = TextContainer() ///< nonnull, inner text container
    var _innerLayout: TextLayout? ///< inner text layout, the text in this layout is longer than `_innerText` by appending '\n'
    
    lazy var _containerView = TextContainerView() ///< nonnull
    lazy var _selectionView = TextSelectionView() ///< nonnull
    lazy var _magnifierCaret = TextMagnifier() ///< nonnull
    lazy var _magnifierRanged = TextMagnifier() ///< nonnull
    
    lazy var _typingAttributesHolder = NSMutableAttributedString(string: " ") ///< nonnull, typing attributes
    var _dataDetector: NSDataDetector?
    var _magnifierRangedOffset: CGFloat = 0
    
    lazy var _highlightRange = NSRange(location: 0, length: 0) ///< current highlight range
    var _highlight: TextHighlight? ///< highlight attribute in `_highlightRange`
    var _highlightLayout: TextLayout? ///< when _state.showingHighlight=YES, this layout should be displayed
    var _trackingRange: TextRange? ///< the range in _innerLayout, may out of _innerText.
    
    var _insetModifiedByKeyboard = false ///< text is covered by keyboard, and the contentInset is modified
    var _originalContentInset = UIEdgeInsets.zero ///< the original contentInset before modified
    var _originalScrollIndicatorInsets = UIEdgeInsets.zero ///< the original scrollIndicatorInsets before modified
    
    var _longPressTimer: Timer?
    var _autoScrollTimer: Timer?
    var _autoScrollOffset: CGFloat = 0 ///< current auto scroll offset which shoud add to scroll view
    var _autoScrollAcceleration: Int = 0 ///< an acceleration coefficient for auto scroll
    var _selectionDotFixTimer: Timer? ///< fix the selection dot in window if the view is moved by parents
    var _previousOriginInWindow = CGPoint.zero
    
    var _touchBeganPoint = CGPoint.zero
    var _trackingPoint = CGPoint.zero
    var _touchBeganTime: TimeInterval = 0
    var _trackingTime: TimeInterval = 0
    lazy var _undoStack: [TextViewUndoObject] = []
    lazy var _redoStack: [TextViewUndoObject] = []
    var _lastTypeRange: NSRange?
    
    lazy var state = State()
    
    // UITextInputTraits
    
    public var autocapitalizationType = UITextAutocapitalizationType.sentences
    public var autocorrectionType = UITextAutocorrectionType.default
    public var spellCheckingType = UITextSpellCheckingType.default
    public var keyboardType = UIKeyboardType.default
    public var keyboardAppearance = UIKeyboardAppearance.default
    public var returnKeyType = UIReturnKeyType.default
    public var enablesReturnKeyAutomatically = false
    public var isSecureTextEntry = false
    
    
    // MARK: - Private
    
    // ===> BSTextView+Private.swift
    
    // MARK: - Private Setter
    
    // ===> BSTextView+PrivateSetter
    
    // MARK: - Private Init
    
    // ===> BSTextView+PrivateInit
    
    // MARK: - Public
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        tokenizer = UITextInputStringTokenizer(textInput: self)
        _initTextView()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIPasteboard.changedNotification, object: nil)
        TextKeyboardManager.default.remove(observer: self)
        
        TextEffectWindow.shared?.hide(selectionDot: _selectionView)
        TextEffectWindow.shared?.hide(_magnifierCaret)
        TextEffectWindow.shared?.hide(_magnifierRanged)
        
        TextDebugOption.remove(self)
        
        _longPressTimer?.invalidate()
        _autoScrollTimer?.invalidate()
        _selectionDotFixTimer?.invalidate()
    }
    
    // MARK: - Override For Protect
    
    open override var isMultipleTouchEnabled: Bool {
        get {
            return super.isMultipleTouchEnabled
        }
        set {
            super.isMultipleTouchEnabled = false // must not enabled
        }
    }
    
    open override var contentInset: UIEdgeInsets {
        get {
            return super.contentInset
        }
        set {
            let oldInsets = self.contentInset
            if _insetModifiedByKeyboard {
                _originalContentInset = newValue
            } else {
                super.contentInset = newValue
                if oldInsets != newValue { // changed
                    _updateInnerContainerSize()
                    _commitUpdate()
                    _commitPlaceholderUpdate()
                }
            }
        }
    }
    
    open override var scrollIndicatorInsets: UIEdgeInsets {
        get {
            return super.scrollIndicatorInsets
        }
        set {
            if _insetModifiedByKeyboard {
                _originalScrollIndicatorInsets = newValue
            } else {
                super.scrollIndicatorInsets = newValue
            }
        }
    }
    
    open override var frame: CGRect {
        set {
            let oldSize: CGSize = bounds.size
            super.frame = newValue
            let newSize: CGSize = bounds.size
            let changed: Bool = _innerContainer.isVerticalForm ? (oldSize.height != newSize.height) : (oldSize.width != newSize.width)
            if changed {
                _updateInnerContainerSize()
                _commitUpdate()
            }
            if !oldSize.equalTo(newSize) {
                _commitPlaceholderUpdate()
            }
        }
        get {
            return super.frame
        }
    }
    
    open override var bounds: CGRect {
        set {
            let oldSize: CGSize = self.bounds.size
            super.bounds = newValue
            let newSize: CGSize = self.bounds.size
            let changed: Bool = _innerContainer.isVerticalForm ? (oldSize.height != newSize.height) : (oldSize.width != newSize.width)
            if changed {
                _updateInnerContainerSize()
                _commitUpdate()
            }
            if !oldSize.equalTo(newSize) {
                _commitPlaceholderUpdate()
            }
        }
        get {
            return super.bounds
        }
    }
    
    // ===> BSTextView+OverrideForProtect.swift
    
    // MARK: - Override UIResponder
    
    // ===> BSTextView+OverrideUIResponder.swift
    
    // MARK: - Override NSObject(UIResponderStandardEditActions)
    // MARK: - Overrice NSObject(NSKeyValueObservingCustomization)
    
    // ===> BSTextView+NSObject.swift
    
    // MARK: - @protocol NSCoding
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _initTextView()
        attributedText = aDecoder.decodeObject(forKey: "attributedText") as? NSAttributedString
        if let decode = (aDecoder.decodeObject(forKey: "selectedRange") as? NSValue)?.rangeValue {
            selectedRange = decode
        }
        textVerticalAlignment = TextVerticalAlignment(rawValue: aDecoder.decodeInteger(forKey: "textVerticalAlignment"))!
        dataDetectorTypes = UIDataDetectorTypes(rawValue: UInt(aDecoder.decodeInteger(forKey: "dataDetectorTypes")))
        textContainerInset = aDecoder.decodeUIEdgeInsets(forKey: "textContainerInset")
        if let decode = aDecoder.decodeObject(forKey: "exclusionPaths") as? [UIBezierPath] {
            exclusionPaths = decode
        }
        isVerticalForm = aDecoder.decodeBool(forKey: "isVerticalForm")
    }
    
    open override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(attributedText, forKey: "attributedText")
        aCoder.encode(NSValue(range: selectedRange), forKey: "selectedRange")
        aCoder.encode(textVerticalAlignment, forKey: "textVerticalAlignment")
        aCoder.encode(dataDetectorTypes.rawValue, forKey: "dataDetectorTypes")
        aCoder.encode(textContainerInset, forKey: "textContainerInset")
        aCoder.encode(exclusionPaths, forKey: "exclusionPaths")
        aCoder.encode(isVerticalForm, forKey: "isVerticalForm")
    }
    
    // MARK: - NSSecureCoding
    
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    // MARK: - @protocol UIScrollViewDelegate
    
    // ===> BSTextView+UIScrollViewDelegate.swift
    
    // MARK: - @protocol TextKeyboardObserver
    
    public func keyboardChanged(with transition: TextKeyboardTransition) {
        _keyboardChanged()
    }
    
    // MARK: - @protocol UIAlertViewDelegate
    
    // ===> BSTextView+UIAlertViewDelegate.swift
    
    // MARK: - @protocol UIKeyInput
    // MARK: - @protocol UITextInput
    
    weak var _inputDelegate: UITextInputDelegate?
    weak public var inputDelegate: UITextInputDelegate? {
        set {
            _inputDelegate = newValue
        }
        get {
            return _inputDelegate
        }
    }
    
    public var selectedTextRange: UITextRange? {
        get {
            return _selectedTextRange
        }
        set {
            guard var n = newValue as? TextRange else {
                return
            }
            n = _correctedTextRange(n)!
            if _selectedTextRange == n {
                return
            }
            _updateIfNeeded()
            _endTouchTracking()
            _hideMenu()
            state.deleteConfirm = false
            state.typingAttributesOnce = false
            
            _inputDelegate?.selectionWillChange(self)
            _selectedTextRange = n
            _lastTypeRange = _selectedTextRange.asRange
            _inputDelegate?.selectionDidChange(self)
            
            _updateOuterProperties()
            _updateSelectionView()
            
            if isFirstResponder {
                _scrollRangeToVisible(self._selectedTextRange)
            }
        }
    }
    
    public var markedTextStyle: [NSAttributedString.Key : Any]?
    
    // MARK: - @protocol UITextInput optional
    
    // ===> BSTextView+UITextInput.swift
}
