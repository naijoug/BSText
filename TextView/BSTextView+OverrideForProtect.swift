//
//  BSTextView+OverrideForProtect.swift
//  BSText
//
//  Created by naijoug on 2022/4/16.
//

import UIKit

extension BSTextView {
    
    open override func tintColorDidChange() {
        if responds(to: #selector(setter: self.tintColor)) {
            let color: UIColor? = tintColor
            var attrs = _highlightTextAttributes
            var linkAttrs = _linkTextAttributes ?? [NSAttributedString.Key : Any]()
            
            if color == nil {
                attrs?.removeValue(forKey: .foregroundColor)
                attrs?.removeValue(forKey: NSAttributedString.Key(kCTForegroundColorAttributeName as String))
                linkAttrs[.foregroundColor] = BSTextView._defaultTintColor
                linkAttrs[NSAttributedString.Key(kCTForegroundColorAttributeName as String)] = BSTextView._defaultTintColor.cgColor
            } else {
                attrs?[.foregroundColor] = color
                attrs?[NSAttributedString.Key(kCTForegroundColorAttributeName as String)] = color?.cgColor
                linkAttrs[.foregroundColor] = color
                linkAttrs[NSAttributedString.Key(kCTForegroundColorAttributeName as String)] = color?.cgColor
            }
            highlightTextAttributes = attrs
            _selectionView.color = color != nil ? color : BSTextView._defaultTintColor
            linkTextAttributes = linkAttrs
            _commitUpdate()
        }
    }
    
    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        var size = size
        if !isVerticalForm && size.width <= 0 {
            size.width = TextContainer.textContainerMaxSize.width
        }
        if isVerticalForm && size.height <= 0 {
            size.height = TextContainer.textContainerMaxSize.height
        }
        
        if (!isVerticalForm && size.width == bounds.size.width) || (isVerticalForm && size.height == bounds.size.height) {
            _updateIfNeeded()
            if !isVerticalForm {
                if _containerView.bounds.size.height <= size.height {
                    return _containerView.bounds.size
                }
            } else {
                if _containerView.bounds.size.width <= size.width {
                    return _containerView.bounds.size
                }
            }
        }
        
        if !isVerticalForm {
            size.height = TextContainer.textContainerMaxSize.height
        } else {
            size.width = TextContainer.textContainerMaxSize.width
        }
        
        let container: TextContainer? = _innerContainer.copy() as? TextContainer
        container?.size = size
        
        let layout = TextLayout(container: container, text: _innerText)
        return layout?.textBoundingSize ?? .zero
    }
    
}
