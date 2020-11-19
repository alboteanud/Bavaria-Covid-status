//
//  ViewController.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 07/11/2020.
//
// instruction for this app here https://docs.google.com/document/d/1O6K2SkQ6vV9R8ZDin4IZ_zm54xlNFPqqhIEVByo_NRs/edit?usp=sharing

import UIKit
import BackgroundTasks
import CoreLocation
import Firebase
import CoreData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window:UIWindow?
    var locationManager = CLLocationManager()
    private let server: Server = FirebaseServer()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
//        PersistentContainer.shared.loadInitialData()
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.danalboteanu.apprefresh.CovidState", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
     
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefresh()
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.danalboteanu.apprefresh.CovidState")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 10 * 60) // Fetch no earlier than 10 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let context = PersistentContainer.shared.newBackgroundContext()
        let operations = Operations.getOperationsToFetchCovidData(using: context, server: server)
        let lastOperation = operations.last!
        
        task.expirationHandler = {
            // After all operations are cancelled, the completion block below is called to set the task to complete.
            queue.cancelAllOperations()
        }

        lastOperation.completionBlock = {
            task.setTaskCompleted(success: !lastOperation.isCancelled)
        }

        queue.addOperations(operations, waitUntilFinished: false)
    }

}

// e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.danalboteanu.apprefresh.CovidState"]
