//
//  BSTextView+OverrideNSObject.swift
//  BSText
//
//  Created by naijoug on 2022/4/16.
//

import UIKit
#if canImport(YYImage)
import YYImage
#endif

// MARK: - NSObject(UIResponderStandardEditActions)

extension BSTextView {
    
    override open func cut(_ sender: Any?) {
        _endTouchTracking()
        if _selectedTextRange.asRange.length == 0 {
            return
        }
        
        _copySelectedTextToPasteboard()
        _saveToUndoStack()
        _resetRedoStack()
        replace(_selectedTextRange, withText: "")
    }
    
    override open func copy(_ sender: Any?) {
        _endTouchTracking()
        _copySelectedTextToPasteboard()
    }
    
    override open func paste(_ sender: Any?) {
        _endTouchTracking()
        let p = UIPasteboard.general
        var atr: NSAttributedString? = nil
        
        if allowsPasteAttributedString {
            atr = p.bs_AttributedString
            if atr?.length ?? 0 == 0 {
                atr = nil
            }
        }
        if atr == nil && allowsPasteImage {
            var img: UIImage? = nil
            
            #if canImport(YYImage)
            let scale: CGFloat = UIScreen.main.scale
            if let d = p.bs_GIFData {
                img = YYImage(data: d, scale: scale)
            }
            if img == nil, let d = p.bs_PNGData {
                img = YYImage(data: d, scale: scale)
            }
            if img == nil, let d = p.bs_WEBPData {
                img = YYImage(data: d, scale: scale)
            }
            #endif
            
            if img == nil {
                img = p.image
            }
            if img == nil && (p.bs_ImageData != nil) {
                img = UIImage(data: p.bs_ImageData!, scale: TextUtilities.textScreenScale)
            }
            if let tmpimg = img, tmpimg.size.width > 1, tmpimg.size.height > 1 {
                var content: Any = tmpimg
                
                #if canImport(YYImage)
                if tmpimg.conforms(to: YYAnimatedImage.self) {
                    let frameCount = (tmpimg as! YYAnimatedImage).animatedImageFrameCount()
                    if frameCount > 1 {
                        let imgView = YYAnimatedImageView()
                        imgView.image = img
                        imgView.frame = CGRect(x: 0, y: 0, width: tmpimg.size.width, height: tmpimg.size.height)
                        content = imgView
                    }
                }
                #endif
                
                if (content is UIImage) && tmpimg.images?.count ?? 0 > 1 {
                    let imgView = UIImageView()
                    imgView.image = img
                    imgView.frame = CGRect(x: 0, y: 0, width: tmpimg.size.width, height: tmpimg.size.height)
                    content = imgView
                }
                
                let attText = NSAttributedString.bs_attachmentString(with: content, contentMode: UIView.ContentMode.scaleToFill, width: tmpimg.size.width, ascent: tmpimg.size.height, descent: 0)
                
                if let attrs = _typingAttributesHolder.bs_attributes {
                    attText.addAttributes(attrs, range: NSRange(location: 0, length: attText.length))
                }
                atr = attText
            }
        }
        if let atr = atr {
            let endPosition: Int = _selectedTextRange.start.offset + atr.length
            let text = _innerText.mutableCopy() as! NSMutableAttributedString
            text.replaceCharacters(in: _selectedTextRange.asRange, with: atr)
            attributedText = text
            let pos = _correctedTextPosition(TextPosition(offset: endPosition))
            let range = _innerLayout?.textRange(byExtending: pos)
            if let range = _correctedTextRange(range) {
                selectedRange = NSRange(location: range.end.offset, length: 0)
            }
        } else {
            let string = p.string
            if let s = string, s != "" {
                _saveToUndoStack()
                _resetRedoStack()
                replace(_selectedTextRange, withText: s)
            }
        }
    }
    
    override open func select(_ sender: Any?) {
        _endTouchTracking()
        
        if _selectedTextRange.asRange.length > 0 || _innerText.length == 0 {
            return
        }
        
        if let newRange = _getClosestTokenRange(at: _selectedTextRange.start), newRange.asRange.length > 0 {
            _inputDelegate?.selectionWillChange(self)
            _selectedTextRange = newRange
            _inputDelegate?.selectionDidChange(self)
        }
        
        _updateIfNeeded()
        _updateOuterProperties()
        _updateSelectionView()
        _hideMenu()
        _showMenu()
    }
    
    override open func selectAll(_ sender: Any?) {
        _trackingRange = nil
        _inputDelegate?.selectionWillChange(self)
        _selectedTextRange = TextRange(range: NSRange(location: 0, length: _innerText.length))
        _inputDelegate?.selectionDidChange(self)
        
        _updateIfNeeded()
        _updateOuterProperties()
        _updateSelectionView()
        _hideMenu()
        _showMenu()
    }
    
    func _define(_ sender: Any?) {
        _hideMenu()
        
        guard let string = _innerText.bs_plainText(for: _selectedTextRange.asRange), string != "" else {
            return
        }
        let resign: Bool = resignFirstResponder()
        if !resign {
            return
        }
        
        let ref = UIReferenceLibraryViewController(term: string)
        ref.view.backgroundColor = UIColor.white
        _getRootViewController()?.present(ref, animated: true) {
        }
    }
    
}

// MARK: - NSObject(NSKeyValueObservingCustomization)

extension BSTextView {
    
    static let automaticallyNotifiesObserversKeys: Set<AnyHashable>? = {
        var keys = Set<AnyHashable>(["text", "font", "textColor", "textAlignment", "dataDetectorTypes", "linkTextAttributes", "highlightTextAttributes", "textParser", "attributedText", "textVerticalAlignment", "textContainerInset", "exclusionPaths", "isVerticalForm", "linePositionModifier", "selectedRange", "typingAttributes"])
        return keys
    }()
    
    override open class func automaticallyNotifiesObservers(forKey key: String) -> Bool {
        // `dispatch_once()` call was converted to a static variable initializer
        if automaticallyNotifiesObserversKeys?.contains(key) != nil {
            return false
        }
        return super.automaticallyNotifiesObservers(forKey: key)
    }
    
}
