//
//  RoutePageViewController.swift
//  BussrExtension
//
//  Created by jackson on 8/16/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import NotificationCenter

class RoutePageViewController: UIPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource, NCWidgetProviding
{
    lazy var stopTableViewControllers: [UIViewController] = {
        return [
            self.getViewController(withIdentifier: "StopTableViewController"),
            self.getViewController(withIdentifier: "StopTableViewController"),
            self.getViewController(withIdentifier: "StopTableViewController")
        ]
    }()
    
    fileprivate func getViewController(withIdentifier identifier: String) -> UIViewController
    {
        return UIStoryboard(name: "MainInterface", bundle: nil).instantiateViewController(withIdentifier: identifier)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.extensionContext?.widgetLargestAvailableDisplayMode = .expanded
        
        self.delegate = self
        self.dataSource = self
        
        self.setViewControllers([stopTableViewControllers.first!], direction: UIPageViewController.NavigationDirection.forward, animated: false) { (done) in
        }
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        completionHandler(NCUpdateResult.newData)
    }
    
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        self.preferredContentSize = (activeDisplayMode != .expanded) ? maxSize : CGSize(width: maxSize.width, height: 220)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = stopTableViewControllers.index(of: viewController) else { return nil }
        let previousIndex = viewControllerIndex - 1
        guard previousIndex >= 0 else { return stopTableViewControllers.last }
        guard stopTableViewControllers.count > previousIndex else { return nil }
        return stopTableViewControllers[previousIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = stopTableViewControllers.index(of: viewController) else { return nil }
        let nextIndex = viewControllerIndex + 1
        guard nextIndex < stopTableViewControllers.count else { return stopTableViewControllers.first }
        guard stopTableViewControllers.count > nextIndex else { return nil }
        return stopTableViewControllers[nextIndex]
    }
}
