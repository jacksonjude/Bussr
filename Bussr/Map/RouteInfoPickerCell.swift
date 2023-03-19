//
//  RouteInfoPickerCell.swift
//  Bussr
//
//  Created by jackson on 3/2/23.
//  Copyright © 2023 jackson. All rights reserved.
//

import UIKit

class RouteInfoPickerCell: UIView
{
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var addFavoriteButtonArea: UIView!
    @IBOutlet weak var addFavoriteButtonRotationBounds: UIView!
    @IBOutlet weak var addFavoriteButtonRotationBoundsHeight: NSLayoutConstraint!
    @IBOutlet weak var addFavoriteButtonImage: UIImageView!
    
    var row: Int?
    
    var labelText: NSAttributedString?
    {
        didSet
        {
            setAddFavoriteButtonVisibility()
        }
    }
    
    var isAddFavoriteButtonHidden = true
    {
        didSet
        {
            setAddFavoriteButtonVisibility()
        }
    }
    
    var isAddFavoriteButtonPressed = false
    {
        didSet
        {
            setAddFavoriteButtonImage()
        }
    }
    var isAddFavoriteButtonFilled = false
    {
        didSet
        {
            setAddFavoriteButtonImage(didToggleFill: oldValue != self.isAddFavoriteButtonPressed)
        }
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        
        self.label.adjustsFontSizeToFitWidth = true
        self.layer.cornerRadius = 6
        setLabelText()
        setAddFavoriteButtonImage()
        setAddFavoriteButtonRotationBounds()
    }
    
    override func awakeFromNib()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(updateCell(notification:)), name: NSNotification.Name("UpdateRoutePickerInfoCell"), object: nil)
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func updateCell(notification: Notification)
    {
        guard let row = notification.userInfo?["row"] as? Int, let favoriteButtonFill = notification.userInfo?["isAddFavoriteButtonFilled"] as? Bool else { return }
        
        if row != self.row { return }
        
        self.isAddFavoriteButtonFilled = favoriteButtonFill
    }
    
    func setLabelText()
    {
        self.label.attributedText = self.labelText
    }
    
    func setAddFavoriteButtonVisibility()
    {
        self.addFavoriteButtonArea.isHidden = self.isAddFavoriteButtonHidden
    }
    
    func setAddFavoriteButtonImage(didToggleFill: Bool = false)
    {
        var imageName = "Favorite\(isAddFavoriteButtonFilled ? "Fill" : "")"
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            imageName += "Icon"
        case .dark:
            imageName += "IconDark"
        }
        self.addFavoriteButtonImage.image = UIImage(named: imageName)
        
        if self.isAddFavoriteButtonPressed, let cgImage = self.addFavoriteButtonImage.image?.cgImage
        {
            let ciImage = CIImage(cgImage: cgImage)
            
            let context = CIContext(options: nil)
            let brightnessFilter = CIFilter(name: "CIColorControls")!
            brightnessFilter.setValue(ciImage, forKey: "inputImage")
            brightnessFilter.setValue(-0.2, forKey: "inputBrightness")
            let outputImage = brightnessFilter.outputImage!
            let cgimg = context.createCGImage(outputImage, from: outputImage.extent)
            
            self.addFavoriteButtonImage.image = UIImage(cgImage: cgimg!)
        }
        
        UIView.animate(withDuration: 0.2, delay: 0.0) {
            self.backgroundColor = self.isAddFavoriteButtonFilled ? UIColor(red: 245/255, green: 161/255, blue: 14/255, alpha: 0.45) : UIColor.clear
        }
        
        if didToggleFill
        {
            self.addFavoriteButtonRotationBounds.rotate(endValue: (self.isAddFavoriteButtonFilled ? 1 : -1) * Float.pi * 2.0 * 1/5, duration: 0.2, repeatCount: 0)
        }
    }
    
    func setAddFavoriteButtonRotationBounds()
    {
        let angle = Float.pi/5
        let height = addFavoriteButtonImage.frame.height
        let starRadius = height/(1+CGFloat(cos(angle)))
        self.addFavoriteButtonRotationBoundsHeight.constant = 2*starRadius
    }
}

extension UIView {
    private static let kRotationAnimationKey = "rotationanimationkey"

    func rotate(endValue: Float, duration: Double = 1, repeatCount: Float = Float.infinity) {
        if layer.animation(forKey: UIView.kRotationAnimationKey) == nil {
            let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")

            rotationAnimation.fromValue = 0.0
            rotationAnimation.toValue = endValue
            rotationAnimation.duration = duration
            rotationAnimation.repeatCount = repeatCount

            layer.add(rotationAnimation, forKey: UIView.kRotationAnimationKey)
        }
    }

    func stopRotating() {
        if layer.animation(forKey: UIView.kRotationAnimationKey) != nil {
            layer.removeAnimation(forKey: UIView.kRotationAnimationKey)
        }
    }
}
