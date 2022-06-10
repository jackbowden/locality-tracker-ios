//
//  Notifier.swift
//  testingground
//
//  Created by Jack Bowden on 7/8/21.
//

import Foundation
import UserNotifications

class Notifier: NSObject, UNUserNotificationCenterDelegate {
    override init() {
        super.init()
        
        let userNotificationCenter = UNUserNotificationCenter.current()
        userNotificationCenter.delegate = self
        
//        UNUserNotificationCenter.current().getNotificationSettings { lmao in
//            switch lmao.authorizationStatus {
//            case .authorized: return
//            default: self.requestNotificationAuthorization()
//            }
//        }
        
        requestNotificationAuthorization()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .badge, .sound]) //.alert instead of .list
    }
    
    func getNotificationsSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            //print("Notification settings \(settings)")
        }
    }
    
    func requestNotificationAuthorization() {
        // Auth options
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .carPlay]) { granted, _ in
            print("Notification permissions granted.")
            guard granted else { return }
            //self.getNotificationsSettings()
        }
        
        
    }
    
    func sendNotification(title: String, body: String) {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = title
        notificationContent.body = body
        notificationContent.badge = NSNumber(value: 0)
        
        if let url = Bundle.main.url(forResource: "dune",
                                    withExtension: "png") {
            if let attachment = try? UNNotificationAttachment(identifier: "dune",
                                                            url: url,
                                                            options: nil) {
                notificationContent.attachments = [attachment]
            }
        }
        
        let request = UNNotificationRequest(identifier: "testNotification",
                                            content: notificationContent,
                                            trigger: nil)
        
        UNUserNotificationCenter.current().add(request)
        
        // vibration
        // todo: fix vibration
//        let generator = UINotificationFeedbackGenerator()
//        generator.notificationOccurred(.warning)
    }
}
