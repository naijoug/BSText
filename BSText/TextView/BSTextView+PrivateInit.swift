//
//  BSTextView+PrivateInit.swift
//  BSText
//
//  Created by naijoug on 2022/4/16.
//

import UIKit

extension BSTextView {
    
    func _initTextView() {
        delaysContentTouches = false
        canCancelContentTouches = true
        clipsToBounds = true
        if #available(iOS 11.0, *) {
            contentInsetAdjustmentBehavior = .never
        }
        super.delegate = self
        
        _innerContainer.insets = BSTextView.kDefaultInset
        
        let name = NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String)
        let c = BSTextView._defaultTintColor.cgColor
        _linkTextAttributes = [NSAttributedString.Key.foregroundColor: BSTextView._defaultTintColor, name: c]
        
        
        let highlight = TextHighlight()
        let border = TextBorder()
        border.insets = UIEdgeInsets(top: -2, left: -2, bottom: -2, right: -2)
        border.fillColor = UIColor(white: 0.1, alpha: 0.2)
        border.cornerRadius = 3
        highlight.border = border
        _highlightTextAttributes = highlight.attributes
        
        _placeHolderView.isUserInteractionEnabled = false
        _placeHolderView.isHidden = true
        
        _containerView = TextContainerView()
        _containerView.hostView = self
        
        _selectionView = TextSelectionView()
        _selectionView.isUserInteractionEnabled = false
        _selectionView.hostView = self
        _selectionView.color = BSTextView._defaultTintColor
        
        _magnifierCaret = TextMagnifier.magnifier(with: TextMagnifierType.caret)!
        _magnifierCaret.hostView = _containerView
        _magnifierRanged = TextMagnifier.magnifier(with: TextMagnifierType.ranged)!
        _magnifierRanged.hostView = _containerView
        
        addSubview(_placeHolderView)
        addSubview(_containerView)
        addSubview(_selectionView)
        
        self.debugOption = TextDebugOption.shared
        TextDebugOption.add(self)
        
        _updateInnerContainerSize()
        _update()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self._pasteboardChanged), name: UIPasteboard.changedNotification, object: nil)
        TextKeyboardManager.default.add(observer: self)
        
        isAccessibilityElement = true
    }
    
}
