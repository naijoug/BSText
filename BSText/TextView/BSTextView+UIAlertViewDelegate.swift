//
//  BSTextView+UIAlertViewDelegate.swift
//  BSText
//
//  Created by naijoug on 2022/4/16.
//

import UIKit

extension BSTextView {
    
    public func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        let title = alertView.buttonTitle(at: buttonIndex)
        if (title?.length ?? 0) == 0 {
            return
        }
        let strings = _localizedUndoStrings()
        if (title == strings[1]) || (title == strings[2]) {
            _redo()
        } else if (title == strings[3]) || (title == strings[4]) {
            _undo()
        }
        _restoreFirstResponderAfterUndoAlert()
    }
    
}
