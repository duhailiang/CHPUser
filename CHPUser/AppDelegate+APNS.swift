//
//  AppDelegate+APNS.swift
//  KFHome
//
//  Created by Sansan on 2017/3/30.
//  Copyright © 2017年 Sansan. All rights reserved.
//

import Foundation
import UserNotifications
import SVProgressHUD

extension AppDelegate {
    
    func configUMPush(appkey:String, launchOptions: [UIApplicationLaunchOptionsKey: Any]?, httpsEnable:Bool) {
        
        UMConfigure.initWithAppkey(appkey_um, channel: "App Store")
        let entity:UMessageRegisterEntity = UMessageRegisterEntity()
        entity.types = Int(UMessageAuthorizationOptions.badge.rawValue)|Int(UMessageAuthorizationOptions.alert.rawValue)|Int(UMessageAuthorizationOptions.sound.rawValue)
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
            UMessage.registerForRemoteNotifications(launchOptions: launchOptions, entity: entity) { (granted, error) in
                if (granted) {
                    //点击允许
                } else {
                    //点击不允许
                }
            }
        }
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NIMSDK.shared().updateApnsToken(deviceToken)
        
        // 对deviceToken的一系列操作
        
        let deviceTokenStr:String = self.stringDevicetoken(deviceToken: deviceToken)
        UserManager.shared.deviceToken = deviceTokenStr
        
        var oid = 0
        if UserManager.shared.isLogin {
            oid = (UserManager.shared.userModel?.oid)!
        }
        NetworkManager.shared.regNotice(app_id:BundleIdentifier(), device_id: HMUUID.getUUID(), device_type: 1, device_token: deviceTokenStr, user_oid: oid, allow_status: 1, app_version: AppVersion(), sys_version: SystemVersion(), complete: { (res, msg) in })
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error)
    }
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        UMessage.didReceiveRemoteNotification(userInfo)
        print(userInfo)
    }
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if (response.notification.request.trigger?.isKind(of: UNPushNotificationTrigger.self))! {
            UMessage.didReceiveRemoteNotification(response.notification.request.content.userInfo)
            let userInfo:Dictionary = response.notification.request.content.userInfo as Dictionary
            if userInfo.keys.contains("test") {
                SVProgressHUD.showError(withStatus: "\(String(describing: userInfo["test"]!))")
            }
        }
    }
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if (notification.request.trigger?.isKind(of: UNPushNotificationTrigger.self))! {
            UMessage.setAutoAlert(false)
            UMessage.didReceiveRemoteNotification(notification.request.content.userInfo)
        }
        completionHandler([.badge, .alert, .sound])
    }
    
    func stringDevicetoken(deviceToken:Data) -> String {
        
        let device = NSData(data: deviceToken)
        let token:String = device.description.replacingOccurrences(of:"<", with:"").replacingOccurrences(of:">", with:"").replacingOccurrences(of:" ", with:"")
        
        return token
    }
}
