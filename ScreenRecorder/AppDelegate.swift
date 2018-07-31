//
//  AppDelegate.swift
//  ScreenRecorder
//
//  Created by 邓锋 on 2018/7/26.
//  Copyright © 2018年 xiangzhen. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        NSSetUncaughtExceptionHandler { exception in
            
            let message = "NSSetUncaughtExceptionHandler"
            UserDefaults.standard.set(message, forKey: "ERROR_MESSAGE")
            UserDefaults.standard.synchronize()
            ScreenRecorder.default.pause()
            
        }
        
        signal(SIGABRT) { (_) in
            print("aaaaaaaaa")
            let message = "SIGABRT"
            UserDefaults.standard.set(message, forKey: "ERROR_MESSAGE")
            UserDefaults.standard.synchronize()
        }
        signal(SIGILL) { (_) in
            print("aaaaaaaaa")
            let message = "SIGILL"
            UserDefaults.standard.set(message, forKey: "ERROR_MESSAGE")
            UserDefaults.standard.synchronize()
        }
        signal(SIGSEGV) { (_) in
            print("aaaaaaaaa")
            let message = "SIGSEGV"
            UserDefaults.standard.set(message, forKey: "ERROR_MESSAGE")
            UserDefaults.standard.synchronize()
        }
        signal(SIGFPE) { (_) in
            print("aaaaaaaaa")
            let message = "SIGFPE"
            UserDefaults.standard.set(message, forKey: "ERROR_MESSAGE")
            UserDefaults.standard.synchronize()
        }
        signal(SIGBUS) { (_) in
            print("aaaaaaaaa")
            let message = "SIGBUS"
            UserDefaults.standard.set(message, forKey: "ERROR_MESSAGE")
            UserDefaults.standard.synchronize()
        }
        signal(SIGPIPE) { (_) in
            print("aaaaaaaaa")
            let message = "SIGPIPE"
            UserDefaults.standard.set(message, forKey: "ERROR_MESSAGE")
            UserDefaults.standard.synchronize()
        }
        print(UserDefaults.standard.object(forKey: "ERROR_MESSAGE"))
        print(UserDefaults.standard.object(forKey: "ERROR_MESSAGE2"))
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        print(">>>>>>>applicationWillTerminate")
        ScreenRecorder.default.pause()
    }


}

