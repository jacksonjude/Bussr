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
            setAddFavoriteButtonImage()
        }
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        
        self.label.adjustsFontSizeToFitWidth = true
        self.layer.cornerRadius = 6
        setLabelText()
        setAddFavoriteButtonImage()
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
    
    func setAddFavoriteButtonImage()
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            self.addFavoriteButtonImage.image = UIImage(named: "FavoriteAdd\(isAddFavoriteButtonFilled ? "Fill" : "")Icon")
        case .dark:
            self.addFavoriteButtonImage.image = UIImage(named: "FavoriteAdd\(isAddFavoriteButtonFilled ? "Fill" : "")IconDark")
        }
        
        UIView.animate(withDuration: 0.1, delay: 0.0) {
            self.backgroundColor = self.isAddFavoriteButtonFilled ? UIColor(red: 245/255, green: 185/255, blue: 66/255, alpha: 0.7) : UIColor.clear
        }
    }
}
