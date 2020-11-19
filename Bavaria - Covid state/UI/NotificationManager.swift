//
//  ViewController.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 16/11/2020.
//

import UIKit
import UserNotifications

class NotificationManager: NSObject {

    func registerForNotifications(statusCode: String) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            if granted {
                self.setupAndGenerateLocalNotification(statusCode: statusCode)
            }
            if error != nil {
                print(error!)
            }
        }
    }

    // TODO add to localised strings
    func setupAndGenerateLocalNotification(statusCode: String) {
        let content = UNMutableNotificationContent()
        content.title = "Covid status Notification"
        content.subtitle = "Covis status Region Monitoring"
        content.body = "You just entered a \(statusCode) Covid area. Check instruction carefully."
        content.badge = 1
        content.sound = UNNotificationSound.default

        let center = UNUserNotificationCenter.current()
//        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "MyNotification", content: content, trigger: nil)
        center.add(request) { error in
            if let error = error {
                print(error)
            }
        }
    }

    func removeNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

