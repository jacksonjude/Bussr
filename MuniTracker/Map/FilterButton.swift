//
//  FilterButton.swift
//  MuniTracker
//
//  Created by jackson on 1/6/19.
//  Copyright © 2019 jackson. All rights reserved.
//

import UIKit

class FilterButton: UIButton
{
    let imageSize: CGFloat = 40
    
    var imagePath: String
    var filterIsEnabled = false
    
    var singleTapHandler: (() -> Void)?
    var doubleTapHandler: (() -> Void)?
    
    var leadingConstraint: NSLayoutConstraint?
    
    init(imagePath: String, superview: UIView)
    {
        self.imagePath = imagePath
        super.init(frame: CGRect(x: superview.frame.width-imageSize-8, y: 8, width: imageSize, height: imageSize))
        
        superview.addSubview(self)
        
        leadingConstraint = NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: superview, attribute: .trailing, multiplier: 1, constant: -8)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        superview.addConstraint(leadingConstraint!)
        superview.addConstraint(NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: self.superview, attribute: .top, multiplier: 1, constant: 8))
        self.addConstraint(NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: imageSize))
        self.addConstraint(NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: imageSize))
        
        self.setFilterImage()
        self.disableButton()
                
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(buttonDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleTap)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(buttonDoubleTap))
        self.addGestureRecognizer(longPress)
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(buttonSingleTap))
        self.addGestureRecognizer(singleTap)
    }
    
    @objc func buttonSingleTap()
    {
        singleTapHandler?()
        setFilterImage()
    }
    
    @objc func buttonDoubleTap()
    {
        doubleTapHandler?()
        setFilterImage()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        setFilterImage()
    }
    
    func disableButton()
    {
        self.isEnabled = false
        self.isHidden = true
    }
    
    func enableButton()
    {
        self.isEnabled = true
        self.isHidden = false
    }
    
    func setFilterImage()
    {
        self.setImage(UIImage(named: imagePath + (filterIsEnabled ? "Fill" : "") + "Icon" + darkImageAppend()), for: .normal)
    }
    
    func darkImageAppend() -> String
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            return ""
        case .dark:
            return "Dark"
        }
    }
}
