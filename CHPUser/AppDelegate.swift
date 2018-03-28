//
//  AppDelegate.swift
//  CHPUser
//
//  Created by 杨新财 on 2018/2/6.
//  Copyright © 2018年 杨新财. All rights reserved.
//

import UIKit
import SVProgressHUD
import IQKeyboardManagerSwift
import NIMSDK
import PushKit
import UserNotifications
import Toast

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, PKPushRegistryDelegate, NIMLoginManagerDelegate, UNUserNotificationCenterDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        self.setupNIMSDK()
        self.setupServices()
        self.registerPushService()
        self.setupThirdParty()
        self.configUMPush(appkey: appkey_um, launchOptions: launchOptions, httpsEnable: true)
        
        self.window = UIWindow.init(frame: UIScreen.main.bounds)
        self.window?.backgroundColor = UIColor.white
        self.window?.makeKeyAndVisible()
        self.setupMainViewController()
        self.commonInitListenEvents()
        
        self.setupStyle()

        
        return true
    }
    func setupStyle() {
        
        UINavigationBar.appearance().isTranslucent = false
        UITabBarItem.appearance().setTitleTextAttributes([NSAttributedStringKey.foregroundColor: Colors.textColor2], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([NSAttributedStringKey.foregroundColor: Colors.mainGreen], for: .selected)
        UINavigationBar.appearance().barTintColor = UIColor.ColorHex(hex: "#56C664") //#4cbc58
        UINavigationBar.appearance().titleTextAttributes = [
            NSAttributedStringKey.foregroundColor: UIColor.white,
            NSAttributedStringKey.font: UIFont.systemFont(ofSize: 18.0)]
        UIApplication.shared.setStatusBarStyle(.lightContent, animated: false)
    }
    func setupNIMSDK() {
        NIMSDKConfig.shared().shouldSyncUnreadCount = true
        NIMSDKConfig.shared().maxAutoLoginRetryTimes = 10
        NIMSDKConfig.shared().maximumLogDays = NTESBundleSetting.sharedConfig().maximumLogDays()
        NIMSDKConfig.shared().shouldCountTeamNotification = NTESBundleSetting.sharedConfig().countTeamNotification()
        NIMSDKConfig.shared().animatedImageThumbnailEnabled = NTESBundleSetting.sharedConfig().animatedImageThumbnailEnabled()
        
        let appkey = NTESDemoConfig.shared().appKey
        let option = NIMSDKOption.init(appKey: appkey!)
        option.apnsCername = NTESDemoConfig.shared().apnsCername
        option.pkCername = NTESDemoConfig.shared().pkCername
        NIMSDK.shared().register(with: option)
        
        //注册自定义消息的解析器
        NIMCustomObject.registerCustomDecoder(NTESCustomAttachmentDecoder.init())
        
        //注册 NIMKit 自定义排版配置
        NIMKit.shared().registerLayoutConfig(NTESCellLayoutConfig())
        
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
        NIMSDK.shared().loginManager.remove(self)
    }
    func setupServices() {
        NTESNotificationCenter.shared().start()
        NTESSubscribeManager.shared().start()
    }
    func registerPushService() {
        if #available(iOS 11.0, *) {
            let center:UNUserNotificationCenter = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.badge, .alert, .sound], completionHandler: { (granted, error) in
                if !granted {
                    UIApplication.shared.keyWindow?.makeToast("请开启推送功能否则无法收到推送通知", duration: 2.0, position: CSToastPositionCenter)
                }
            })
        } else {
            let types:UIUserNotificationType = [UIUserNotificationType.badge, UIUserNotificationType.sound, UIUserNotificationType.alert]
            let settings = UIUserNotificationSettings.init(types: types, categories: nil)
            UIApplication.shared.registerUserNotificationSettings(settings)
        }
        UIApplication.shared.registerForRemoteNotifications()
        
        //pushkit
        let pushRegistry:PKPushRegistry = PKPushRegistry.init(queue: DispatchQueue.main)
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = NSSet.init(object: PKPushType.voIP) as? Set<PKPushType>
        
    }
    func setupThirdParty() {
        IQKeyboardManager.sharedManager().enable = true
        SVProgressHUD.setMaximumDismissTimeInterval(1.0)
        SVProgressHUD.setMaxSupportedWindowLevel(UIWindowLevelAlert)
    }
    func commonInitListenEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(logout(noti:)), name: NSNotification.Name(rawValue: NSNotification.Name.RawValue("NTESNotificationLogout")), object: nil)
        NIMSDK.shared().loginManager.add(self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(videoCallControl(noti:)), name: NotificationVideoCallControl, object: nil)
    }
    
    @objc func logout(noti:Notification) {
        NTESLoginManager.shared().currentLoginData = nil
        NTESServiceManager.shared().destory()
    }
    
    @objc func videoCallControl(noti:Notification) {
        let dataDic:[String:Any] = noti.userInfo as! [String:Any]
        NetworkManager.shared.actionInRoom(user_type: "USER", room_name: dataDic["room_name"] as! String, action: dataDic["action"] as! String, cur_person_num: (dataDic["cur_person_num"] as! NSNumber).intValue, success: {
            
        }) { (msg) in
            print("videoCallControl:" ,msg)
        }
    }
    
    //PKPushRegistryDelegate
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        if type == .voIP {
            NIMSDK.shared().updatePushKitToken(pushCredentials.token)
        }
    }
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        let info:NSDictionary = payload.dictionaryPayload as NSDictionary
        let aps:NSDictionary = info["aps"] as! NSDictionary
        let badge:NSNumber? = aps["badge"] as? NSNumber
        if badge != nil {
            UIApplication.shared.applicationIconBadgeNumber = (badge?.intValue)!
        }
    }
    
    func setupMainViewController() {
        
        let mainTab:NTESMainTabController = NTESMainTabController.init(nibName: nil, bundle: nil)
        mainTab.setUpSubNav(getNavItems())
        self.window?.rootViewController = mainTab
        
        let phone:String? = UserDefaults.standard.object(forKey: YZHUSERPHONE) as? String
        let password:String? = UserDefaults.standard.object(forKey: YZHUSERPASSWORD) as? String
        print("1.数据获取", phone ?? "nil", password ?? "nil")
        if phone != nil && password != nil {
            print("2.数据没有丢", phone ?? "nil", password ?? "nil")
            
            SVProgressHUD.show()
            NetworkManager.shared.login(mid: phone!, password: password!, device_id: HMUUID.getUUID(), sms_code: nil) { (isLogin, msg) in
                if isLogin {
                    let loginData:NIMAutoLoginData = NIMAutoLoginData()
                    loginData.account = (UserManager.shared.userModel?.accid)!
                    loginData.token = (UserManager.shared.userModel?.token)!
                    
                    NIMSDK.shared().loginManager.login((UserManager.shared.userModel?.accid)!, token: (UserManager.shared.userModel?.token)!, completion: { (error) in
                        if error != nil {
                            SVProgressHUD.showError(withStatus: "网易云信登录失败")
                        }
                    })
                    NTESServiceManager.shared().start()
                    
                }
                SVProgressHUD.dismiss()
            }
        }
    }
    
    // Mark NIMLoginManagerDelegate
    func onKick(_ code: NIMKickReason, clientType: NIMLoginClientType) {
        var reason:String = "你被踢下线"
        switch code {
        case .byClient:
            break
        case .byClientManually:
            let clientName:String = NTESClientUtil.clientName(clientType)
            reason = clientName.isEmpty ? "你的帐号被\(clientName)端踢出下线，请注意帐号信息安全":"你的帐号被踢出下线，请注意帐号信息安全"
            break
        case .byServer:
            reason = "你被服务器踢下线"
            break
        }
        NIMSDK.shared().loginManager.logout { (error) in
            NotificationCenter.default.post(name: Notification.Name.init("NTESNotificationLogout"), object: nil)
            let alert:UIAlertController = UIAlertController.init(title: "下线通知", message: reason, preferredStyle: .alert)
            let action:UIAlertAction = UIAlertAction.init(title: "确定", style: .cancel, handler: { (action) in
            })
            alert.addAction(action)
            alert.show()
        }
    }
    func onAutoLoginFailed(_ error: Error) {
        //只有连接发生严重错误才会走这个回调，在这个回调里应该登出，返回界面等待用户手动重新登录。
        print("onAutoLoginFailed %zd",error.code);
        
        NIMSDK.shared().loginManager.logout({ (error) in
            NotificationCenter.default.post(name: NSNotification.Name.init("NTESNotificationLogout"), object: nil)
        })
        
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
//        let count:Int = NIMSDK.shared().conversationManager.allUnreadCount()
//        UIApplication.shared.applicationIconBadgeNumber = count
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
    }
}


