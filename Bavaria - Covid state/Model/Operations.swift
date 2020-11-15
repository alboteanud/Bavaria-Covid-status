//
//  Operations.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 14.11.2020.
//

import UIKit
import CoreData
import Firebase

struct Operations {

    static func getOperationsToFetchCovidData(using context: NSManagedObjectContext) -> [Operation] {
        let fetchMostRecentLocationOperation = FetchMostRecentLocationOperation(context: context)
        let triggerCloudFunctionToCheckCovidStateOperation = TriggerCloudFunctionToCheckCovidStateOperation(context: context)
        
        let passLastLocationToServer = BlockOperation { [unowned fetchMostRecentLocationOperation, unowned triggerCloudFunctionToCheckCovidStateOperation] in
            guard let lat = fetchMostRecentLocationOperation.result?.lat else {
                triggerCloudFunctionToCheckCovidStateOperation.cancel()
                return
            }
            triggerCloudFunctionToCheckCovidStateOperation.lon = fetchMostRecentLocationOperation.result?.lon
            triggerCloudFunctionToCheckCovidStateOperation.lat = lat
            triggerCloudFunctionToCheckCovidStateOperation.language = NSLocale.current.languageCode
        }
        
        
//        let fetchMostRecentEntry = FetchMostRecentEntryOperation(context: context)
//        let downloadFromServer = DownloadEntriesFromServerOperation(context: context,
//                                                                             server: server)
//        let passTimestampToServer = BlockOperation { [unowned fetchMostRecentEntry, unowned downloadFromServer] in
//            guard let timestamp = fetchMostRecentEntry.result?.timestamp else {
//                downloadFromServer.cancel()
//                return
//            }
//            downloadFromServer.sinceDate = timestamp
//        }
//        passTimestampToServer.addDependency(fetchMostRecentEntry)
//        downloadFromServer.addDependency(passTimestampToServer)
        
        passLastLocationToServer.addDependency(fetchMostRecentLocationOperation)
        triggerCloudFunctionToCheckCovidStateOperation.addDependency(passLastLocationToServer)
      
        
        return [fetchMostRecentLocationOperation,
                passLastLocationToServer,
        triggerCloudFunctionToCheckCovidStateOperation]
    }    

}

// Fetches the most recent location entry from the Core Data store.
class FetchMostRecentLocationOperation: Operation {
    private let context: NSManagedObjectContext
    
    var result: LocationEntry?
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    override func main() {
        let request: NSFetchRequest<LocationEntry> = LocationEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(LocationEntry.timestamp), ascending: false)]
        request.fetchLimit = 1
        
        context.performAndWait {
            do {
                let fetchResult = try context.fetch(request)
                guard !fetchResult.isEmpty else { return }
                let lat = fetchResult[0].lat
                
                result = fetchResult[0]
            } catch {
                print("Error fetching from context: \(error)")
            }
        }
    }
}

class TriggerCloudFunctionToCheckCovidStateOperation : Operation {
    private let context: NSManagedObjectContext
    lazy var functions = Functions.functions()
    enum OperationError: Error {
        case cancelled
    }
    var timestamp:Date?
    var lat: Double?
    var lon: Double?
    var language: String?
    
    var result: Result<[HTTPSCallableResult?], Error>?
    
    private var downloading = false
    private var currentDownloadTask: DownloadTask?
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    convenience init(context: NSManagedObjectContext, lat: Double, lon: Double, language: String) {
        self.init(context: context)
        self.lat = lat
        self.lon = lon
        self.language = language
    }
    
    override var isAsynchronous: Bool {
        return true
    }
    
    override var isExecuting: Bool {
        return downloading
    }
    
    override var isFinished: Bool {
        return result != nil
    }
    
    override func cancel() {
        super.cancel()
        if let currentDownloadTask = currentDownloadTask {
            currentDownloadTask.cancel()
        }
    }
    
    func finish(result: Result<[HTTPSCallableResult?], Error>) {
        guard downloading else { return }
        
        willChangeValue(forKey: #keyPath(isExecuting))
        willChangeValue(forKey: #keyPath(isFinished))
        
        downloading = false
        self.result = result
        currentDownloadTask = nil
        
        didChangeValue(forKey: #keyPath(isFinished))
        didChangeValue(forKey: #keyPath(isExecuting))
    }

    override func start() {
        willChangeValue(forKey: #keyPath(isExecuting))
        downloading = true
        didChangeValue(forKey: #keyPath(isExecuting))
        
        guard !isCancelled, let lat = lat else {
            finish(result: .failure(OperationError.cancelled))
            return
        }
        
       // currentDownloadTask =
//            server.fetchEntries(since: sinceDate, completion: finish)
        functions.httpsCallable("addMessage2").call(["lat": lat, "lon": lon, "language": language]) { (result, error) in
          if let error = error as NSError? {
            if error.domain == FunctionsErrorDomain {
              let code = FunctionsErrorCode(rawValue: error.code)
              let message = error.localizedDescription
              let details = error.userInfo[FunctionsErrorDetailsKey]
            }
            // ...
          }
          if let text = (result?.data as? [String: Any])?["text"] as? String {
//            self.resultField.text = text
            print(text)
          }
        }
    }
    
}

class LocationEntryToStoreOperation: Operation {
    private let context: NSManagedObjectContext
    var locationEntry: LocationEntry?

    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    convenience init(context: NSManagedObjectContext, locationEntry: LocationEntry) {
        self.init(context: context)
        self.locationEntry = locationEntry
    }
    
    override func main() {
        guard let entry = locationEntry else { return }

        context.performAndWait {
            do {
               
                _ = LocationEntry(context: context, lat: entry.lat, lon: entry.lon, timestamp: entry.timestamp!)
                    
                    print("Adding entry with timestamp: \(entry.timestamp)")
                    
                    try context.save()
                
            } catch {
                print("Error adding entries to store: \(error)")
            }
        }
    }
}

// Add entries returned from the server to the Core Data store.
class AddEntriesToStoreOperation: Operation {
    private let context: NSManagedObjectContext
    var entries: [AreaInfoEntry]?

    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    convenience init(context: NSManagedObjectContext, entries: [AreaInfoEntry]) {
        self.init(context: context)
        self.entries = entries
    }
    
    override func main() {
        guard let entries = entries else { return }

        context.performAndWait {
            do {
                for entry in entries {
                    _ = AreaInfo(context: context, areaInfoEntry: entry)
                    
                    print("Adding entry with timestamp: \(entry.timestamp)")
                    
                    try context.save()

                    if isCancelled {
                        break
                    }
                }
            } catch {
                print("Error adding entries to store: \(error)")
            }
        }
    }
}

// A struct representing the response from the server for a single feed entry.
struct AreaInfoEntry: Codable {

    let timestamp: Date
    let dangerlevel: Int16
    let message: String
}

// An extension to create a FeedEntry object from the server representation of an entry.
extension AreaInfo {
    convenience init(context: NSManagedObjectContext, areaInfoEntry: AreaInfoEntry) {
        self.init(context: context)
        self.message = areaInfoEntry.message
        self.dangerlevel = areaInfoEntry.dangerlevel
        self.timestamp = areaInfoEntry.timestamp
    }
}

extension LocationEntry {
    convenience init (context: NSManagedObjectContext, lat: Double, lon: Double, timestamp: Date) {
        self.init(context: context)
        self.lat = lat
        self.lon = lon
        self.timestamp = timestamp
    }
}

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
            let operation = LocationEntryToStoreOperation(context: context, locationEntry: entry)
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

