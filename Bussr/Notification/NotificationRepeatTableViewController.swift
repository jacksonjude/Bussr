//
//  NotificationRepeatTableViewController.swift
//  MuniTracker
//
//  Created by jackson on 10/11/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class NotificationRepeatTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate
{
    var selectedCells = [false, false, false, false, false, false, false]
    
    @IBOutlet weak var notificationRepeatTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTableView), name: NSNotification.Name("ReloadNotificationEditorViews"), object: nil)
    }
    
    @objc func reloadTableView()
    {
        selectedCells = NotificationEditorState.notificationRepeatArray ?? []
        
        notificationRepeatTableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 7
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationRepeatCell")!
        
        var dayTitle = "Repeats every "
        
        switch indexPath.row
        {
        case 0:
            dayTitle += "Sunday"
        case 1:
            dayTitle += "Monday"
        case 2:
            dayTitle += "Tuesday"
        case 3:
            dayTitle += "Wednesday"
        case 4:
            dayTitle += "Thursday"
        case 5:
            dayTitle += "Friday"
        case 6:
            dayTitle += "Saturday"
        default:
            break
        }
        
        cell.accessoryType = selectedCells[indexPath.row] ? .checkmark : .none
        
        cell.textLabel?.text = dayTitle

        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.frame.size.height/7
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedCells[indexPath.row] = !selectedCells[indexPath.row]
        
        tableView.cellForRow(at: indexPath)?.accessoryType = selectedCells[indexPath.row] ? .checkmark : .none
        tableView.deselectRow(at: indexPath, animated: true)
        
        NotificationEditorState.notificationRepeatArray = selectedCells
    }
}
