//
//  GeoLocationOperations.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 15.11.2020.
//

import CoreData
import UIKit

extension AppDelegate : CLLocationManagerDelegate {
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // only first time, if position is not present in DB
        initLocationManager()
        getLocation()
    
    // The system wakes up the app to handle location updates.
    // Reconfigure it to get location updates
        if (launchOptions?[.location]) != nil  {
        initLocationManager()
        getLocation()
        }
    
        return true
    }
    
    func initLocationManager()  {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
    }
    
    func startMySignificantLocationChanges() {
        if !CLLocationManager.significantLocationChangeMonitoringAvailable() {
            // The device does not support this service.
            return
        }
        locationManager.startMonitoringSignificantLocationChanges()
    }
    
    // MARK: CLLocationManager functions

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        getLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if CLLocationManager.authorizationStatus() == .authorizedAlways ||
            CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            
            let lastLocation = locations.last!
           print( "app delegate - lat: " , lastLocation.coordinate.latitude, Date())
            let context = PersistentContainer.shared.newBackgroundContext()
            
            let entry = LocationEntry(context: context, lat: lastLocation.coordinate.latitude, lon: lastLocation.coordinate.longitude, timestamp: Date())
            let operation = AddLocationEntryToStoreOperation(context: context, locationEntry: entry)
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            queue.addOperation(operation)
        } else {
            // Do nothing
            print("Cannot create a geofence because the user has not granted access to Location Services.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error occured: \(error.localizedDescription).")
    }
    
    func getLocation() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
           locationManager.requestAlwaysAuthorization()
            break
        case .authorizedWhenInUse:
            startMySignificantLocationChanges()
            break
        case .authorizedAlways:
            startMySignificantLocationChanges()
            break
        case .restricted:
            // Restricted by e.g. parental controls. User can't enable Location Services
            print("location unauthorised - restricted")
            break
        case .denied:
            // User denied access to Location Services, but can grant access later from the Settings app
            print("location unauthorised - denied")
            break
        }
    }
}
