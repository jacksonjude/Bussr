//
//  NotificationTimePickerViewController.swift
//  MuniTracker
//
//  Created by jackson on 10/11/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class NotificationTimePickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate
{
    var timeValues: Array<Array<String>> = []
    
    @IBOutlet weak var notificationTimePickerView: UIPickerView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setTimeValues()
        
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            notificationTimePickerView.backgroundColor = UIColor.white
        case .dark:
            notificationTimePickerView.backgroundColor = UIColor.black
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadPickerView), name: NSNotification.Name("ReloadNotificationEditorViews"), object: nil)
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        return NSAttributedString(string: timeValues[component][row], attributes: [NSAttributedString.Key.foregroundColor: inverseThemeColor()])
    }
    
    func inverseThemeColor() -> UIColor
    {
        switch appDelegate.getCurrentTheme()
        {
        case .light:
            return UIColor.black
        case .dark:
            return UIColor.white
        }
    }
    
    @objc func reloadPickerView()
    {
        notificationTimePickerView.reloadAllComponents()
        
        var notificationHour = NotificationEditorState.notificationHour ?? 0
        if notificationHour > 12
        {
            notificationHour -= 12
        }
        if notificationHour == 0
        {
            notificationHour = 12
        }
        
        var notificationMinuteFormatted = String(NotificationEditorState.notificationMinute ?? 0)
        if NotificationEditorState.notificationMinute ?? 0 < 10
        {
            notificationMinuteFormatted += "0"
        }
        
        notificationTimePickerView.selectRow(timeValues[0].firstIndex(of: String(notificationHour))!, inComponent: 0, animated: true)
        notificationTimePickerView.selectRow(timeValues[1].firstIndex(of: notificationMinuteFormatted)!, inComponent: 1, animated: true)
        notificationTimePickerView.selectRow(timeValues[2].firstIndex(of: (NotificationEditorState.notificationHour ?? 0 >= 12) ? "PM":"AM")!, inComponent: 2, animated: true)
    }
    
    func setTimeValues()
    {
        timeValues = [["12"], [], ["AM", "PM"]]
        
        var hourOn = 1
        while hourOn <= 11
        {
            timeValues[0].append(String(hourOn))
            hourOn += 1
        }
        
        var minuteOn = 0
        while minuteOn <= 59
        {
            timeValues[1].append(String(format: "%02d", minuteOn))
            minuteOn += 5
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 3
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return timeValues[component].count
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch component
        {
        case 0:
            let notificationHour = timeValues[component][row]
            updateNotificationHour(notificationHour: notificationHour, pickerView: pickerView)
        case 1:
            let notificationMinute = timeValues[component][row]
            updateNotificationMinute(notificationMinute: notificationMinute)
        case 2:
            let notificationHour = timeValues[0][pickerView.selectedRow(inComponent: 0)]
            updateNotificationHour(notificationHour: notificationHour, pickerView: pickerView)
        default:
            break
        }
    }
    
    func updateNotificationHour(notificationHour: String, pickerView: UIPickerView)
    {
        var formattedNotificationHour = Int16(notificationHour)!
        if timeValues[2][pickerView.selectedRow(inComponent: 2)] == "PM"
        {
            formattedNotificationHour += 12
        }
        else if notificationHour == "12"
        {
            formattedNotificationHour = 0
        }
        NotificationEditorState.notificationHour = formattedNotificationHour
    }
    
    func updateNotificationMinute(notificationMinute: String)
    {
        let formattedNotificationMinute = Int16(notificationMinute)!
        NotificationEditorState.notificationMinute = formattedNotificationMinute
    }
}
