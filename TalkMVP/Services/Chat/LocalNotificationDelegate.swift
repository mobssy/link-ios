//
//  LocalNotificationDelegate.swift
//  TalkMVP
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import UserNotifications

/// Shows notifications as banners even while the app is open.
class LocalNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LocalNotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound, .badge])
    }
}
