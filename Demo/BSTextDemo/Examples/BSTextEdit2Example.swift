//
//  BSTextEdit2Example.swift
//  BSTextDemo
//
//  Created by guojian on 2022/4/18.
//  Copyright © 2022 GeekBruce. All rights reserved.
//

import UIKit
import BSText
import YYImage

class BSTextEdit2Example: UIViewController, TextKeyboardObserver {
    
    private var textView = BSTextView()
    private var systemTextView: SystemTextView!
    private var customTextView: CustomTextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.white
        if #available(iOS 11.0, *) {
            textView.contentInsetAdjustmentBehavior = UIScrollView.ContentInsetAdjustmentBehavior.never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.edit(_:)))
        
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.delegate = self
        textView.placeholderText = "BSTextView"
        textView.frame = CGRect(x: 10, y: 100, width: view.frame.width - 20, height: 100)
        textView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        textView.textColor = .white
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView.delegate = self
        textView.keyboardDismissMode = UIScrollView.KeyboardDismissMode.interactive
        view.addSubview(textView)
        
        systemTextView = SystemTextView(frame: CGRect(x: 10, y: textView.frame.maxY + 20, width: view.frame.width - 20, height: 100))
        systemTextView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        systemTextView.textColor = .white
        systemTextView.font = UIFont.systemFont(ofSize: 17)
        systemTextView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        view.addSubview(systemTextView)
        
        customTextView = CustomTextView(frame: CGRect(x: 10, y: systemTextView.frame.maxY + 20, width: view.frame.width - 20, height: 100))
        customTextView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
//        systemTextView.textColor = .white
//        systemTextView.font = UIFont.systemFont(ofSize: 17)
//        systemTextView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        view.addSubview(customTextView)
    }
    
    @objc
    private func edit(_ item: UIBarButtonItem?) {
        textView.resignFirstResponder()
        systemTextView.resignFirstResponder()
    }
}

// MARK: - BSTextViewDelegate

extension BSTextEdit2Example: TextViewDelegate {
    
    func textView(_ textView: BSTextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        print("🏀 shouldChangeTextIn: | range: \(range) | text: \(text) \(textView.log)")
        return true
    }
    func textViewDidChange(_ textView: BSTextView) {
        print("🏀 textViewDidChange \(textView.log)")
    }
    func textViewDidChangeSelection(_ textView: BSTextView) {
        print("🏀 textViewDidChangeSelection \(textView.log)")
    }
    
    func textViewShouldBeginEditing(_ textView: BSTextView) -> Bool {
        print("🏀 textViewShouldBeginEditing \(textView.log)")
        return true
    }
    func textViewDidBeginEditing(_ textView: BSTextView) {
        print("🏀 textViewDidBeginEditing \(textView.log)")
    }
    func textViewShouldEndEditing(_ textView: BSTextView) -> Bool {
        print("🏀 textViewShouldEndEditing \(textView.log)")
        return true
    }
    func textViewDidEndEditing(_ textView: BSTextView) {
        print("🏀 textViewDidEndEditing \(textView.log)")
    }
}

private class SystemTextView: UITextView {
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        
        delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
extension SystemTextView: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        print("🍎 shouldChangeTextIn: | range: \(range) | text: \(text) \(textView.log)")
        return true
    }
    func textViewDidChange(_ textView: UITextView) {
        print("🍎 textViewDidChange \(textView.log)")
    }
    func textViewDidChangeSelection(_ textView: UITextView) {
        print("🍎 textViewDidChangeSelection \(textView.log)")
    }
    
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        print("🍎 textViewShouldBeginEditing \(textView.log)")
        return true
    }
    func textViewDidBeginEditing(_ textView: UITextView) {
        print("🍎 textViewDidBeginEditing \(textView.log)")
    }
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        print("🍎 textViewShouldEndEditing \(textView.log)")
        return true
    }
    func textViewDidEndEditing(_ textView: UITextView) {
        print("🍎 textViewDidEndEditing \(textView.log)")
    }
    
}

// MARK: UIKeyInput
extension SystemTextView {
    override func insertText(_ text: String) {
        print("\n🍎 🚀 insertText | \(text) \(self.log)")
        super.insertText(text)
        print("🍎 👌🏻 insertText | \(text) \(self.log)\n")
    }
    override func insertText(_ text: String, alternatives: [String], style: UITextAlternativeStyle) {
        print("\n🍎 🚀 insertText | \(text) | alternatives: \(alternatives) | style: \(style) | \(self.log)")
        super.insertText(text, alternatives: alternatives, style: style)
        print("🍎 👌🏻 insertText | \(text) | alternatives: \(alternatives) | style: \(style) | \(self.log)")
    }
    override func deleteBackward() {
        print("🍎 🛫 deleteBackward \(self.log)")
        super.deleteBackward()
        print("🍎 🛬 deleteBackward \(self.log)")
    }
}
// MARK: UITextInput
extension SystemTextView {
    override func text(in range: UITextRange) -> String? {
        print("🍎 🛫 text(in range: \(range) \(self.log)")
        let res = super.text(in: range)
        print("🍎 🛬 text(in range: | res: \(res ?? "") | range: \(range) \(self.log)")
        return res
    }
    override func replace(_ range: UITextRange, withText text: String) {
        print("🍎 🛫 replace | range: \(range) | text: \(text) \(self.log)")
        super.replace(range, withText: text)
        print("🍎 🛬 replace | range: \(range) | text: \(text) \(self.log)")
    }
    override func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        print("🍎 🛫 setMarkedText | markedText: \(markedText ?? "") | selectedRange: \(selectedRange) \(self.log)")
        super.setMarkedText(markedText, selectedRange: selectedRange)
        print("🍎 🛬 setMarkedText | markedText: \(markedText ?? "") | selectedRange: \(selectedRange) \(self.log)")
    }
    
    // Optional
    
    override func shouldChangeText(in range: UITextRange, replacementText text: String) -> Bool {
        print("🍎 🛫 setMarkedText | range: \(range) | text: \(text) \(self.log)")
        let res = super.shouldChangeText(in: range, replacementText: text)
        print("🍎 🛬 setMarkedText | range: \(range) | text: \(text) | res: \(res) \(self.log)")
        return res
    }
}

private extension BSTextView {
    var log: String {
        "【text: \(text) | selectedRange: \(selectedRange) | markedTextRange: \(String(describing: markedTextRange)) 】"
    }
}
private extension UITextView {
    var log: String {
        "【text: \(text ?? "") | selectedRange: \(selectedRange) | markedTextRange: \(String(describing: markedTextRange)) 】"
    }
}
private extension CustomTextView {
    var log: String {
        "【input: \(input)】"
    }
}



// MARK: - Custom

/**
 Reference:
    - https://gist.github.com/austinzheng/a8563c6babfd61401be3
    - https://stackoverflow.com/questions/33474771/a-swift-example-of-custom-views-for-data-input-custom-in-app-keyboard
 */

class CustomTextView: UIControl {
    // the string we'll be drawing
    var input = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(_:))))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var canBecomeFirstResponder: Bool {
        true
    }
    
    @objc
    private func tap(_ gesture: UITapGestureRecognizer) {
        becomeFirstResponder()
    }

    override func draw(_ rect: CGRect) {
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 17), .foregroundColor: UIColor.white]
        let attributedString = NSAttributedString(string: input, attributes: attrs)
        attributedString.draw(in: rect)
    }
}
extension CustomTextView: UIKeyInput {
    var hasText: Bool {
        input.isEmpty == false
    }

    func insertText(_ text: String) {
        print("\n🐒 🚀 insertText | \(text) \(self.log)")
        input += text
        setNeedsDisplay()
        print("🐒 👌🏻 insertText | \(text) \(self.log)\n")
    }

    func deleteBackward() {
        print("🐒 🛫 deleteBackward \(self.log)")
        _ = input.popLast()
        setNeedsDisplay()
        print("🐒 🛬 deleteBackward \(self.log)")
    }
}
