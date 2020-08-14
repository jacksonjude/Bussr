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
    let hourOffset = Calendar(identifier: .gregorian).component(.hour, from: Date(timeIntervalSince1970: 0.0))-24
    var timeValues: Array<Array<String>> = []
    
    @IBOutlet weak var notificationTimePickerView: UIPickerView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setTimeValues()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadPickerView), name: NSNotification.Name("ReloadNotificationEditorViews"), object: nil)
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        return NSAttributedString(string: timeValues[component][row], attributes: [:])
    }
    
    @objc func reloadPickerView()
    {
        notificationTimePickerView.reloadAllComponents()
        
        var notificationHour = 12
        if NotificationEditorState.notificationHour != nil && !(NotificationEditorState.newNotification ?? false)
        {
            notificationHour = Int(NotificationEditorState.notificationHour!) + hourOffset
        }
        
        if notificationHour < 0
        {
            notificationHour += 24
        }
        if notificationHour > 24
        {
            notificationHour -= 24
        }
        
        var notificationMinute = NotificationEditorState.notificationMinute ?? 0
        
        if NotificationEditorState.newNotification ?? false
        {
            let hour = Calendar.current.component(.hour, from: Date())
            let minute = Calendar.current.component(.minute, from: Date())
            
            notificationHour = hour
            notificationMinute = Int16(minute + (5 - minute % 5))
        }
        
        var notification12Hour = notificationHour
        if notification12Hour > 12
        {
            notification12Hour -= 12
        }
        if notification12Hour == 0
        {
            notification12Hour = 12
        }
        
        var notificationMinuteFormatted = String(notificationMinute)
        if notificationMinute < 10
        {
            notificationMinuteFormatted = "0" + notificationMinuteFormatted
        }
        
        notificationTimePickerView.selectRow(timeValues[0].firstIndex(of: String(notification12Hour))!, inComponent: 0, animated: true)
        notificationTimePickerView.selectRow(timeValues[1].firstIndex(of: notificationMinuteFormatted)!, inComponent: 1, animated: true)
        notificationTimePickerView.selectRow(timeValues[2].firstIndex(of: (notificationHour >= 12) ? "PM":"AM")!, inComponent: 2, animated: true)
        
        self.pickerView(notificationTimePickerView, didSelectRow: notificationTimePickerView.selectedRow(inComponent: 0), inComponent: 0)
        self.pickerView(notificationTimePickerView, didSelectRow: notificationTimePickerView.selectedRow(inComponent: 1), inComponent: 1)
        self.pickerView(notificationTimePickerView, didSelectRow: notificationTimePickerView.selectedRow(inComponent: 2), inComponent: 2)
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
        if timeValues[2][pickerView.selectedRow(inComponent: 2)] == "PM" && notificationHour != "12"
        {
            formattedNotificationHour += 12
        }
        else if timeValues[2][pickerView.selectedRow(inComponent: 2)] == "PM" && notificationHour == "12"
        {
            formattedNotificationHour = 12
        }
        else if notificationHour == "12"
        {
            formattedNotificationHour = 0
        }
        formattedNotificationHour -= Int16(hourOffset)
        
        if formattedNotificationHour < 0
        {
            formattedNotificationHour += 24
        }
        if formattedNotificationHour > 24
        {
            formattedNotificationHour -= 24
        }
        
        NotificationEditorState.notificationHour = formattedNotificationHour
    }
    
    func updateNotificationMinute(notificationMinute: String)
    {
        let formattedNotificationMinute = Int16(notificationMinute)!
        NotificationEditorState.notificationMinute = formattedNotificationMinute
    }
}
