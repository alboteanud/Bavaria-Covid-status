//
//  Operations.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 14.11.2020.
//

import Firebase
import CoreData
import UserNotifications

struct Operations {

    static func getOperationsToFetchCovidData(using context: NSManagedObjectContext) -> [Operation] {
        let fetchLocationOperation = FetchLocationOperation(context: context)
        let downloadFromCloudOperation = DownloadFromCloudOperation(context: context)
        
        let sendLocationToCloud = BlockOperation { [unowned fetchLocationOperation, unowned downloadFromCloudOperation] in
            guard (fetchLocationOperation.resultLocationEntry) != nil else {
                downloadFromCloudOperation.cancel()
                return
            }
            downloadFromCloudOperation.currentLocation = fetchLocationOperation.resultLocationEntry
        }
        
        sendLocationToCloud.addDependency(fetchLocationOperation)
        downloadFromCloudOperation.addDependency(sendLocationToCloud)
        
        let addToStoreOperation = AddAreaInfoToStoreOperation(context: context)
        let passCloudResultsToStore = BlockOperation { [unowned downloadFromCloudOperation, unowned addToStoreOperation] in
            guard (downloadFromCloudOperation.areaInfo != nil) else {
                        addToStoreOperation.cancel()
                        return
                    }
            addToStoreOperation.areaInfo = downloadFromCloudOperation.areaInfo
        }

        passCloudResultsToStore.addDependency(downloadFromCloudOperation)
        addToStoreOperation.addDependency(passCloudResultsToStore)
        
        let fetchStoredAreaInfoOperation = FetchAreaInfoOperation(context: context)
        let notifyUserIfNeededOperation = NotifyUserIfNeeded(context: context)
        
        let passDataToNotification = BlockOperation { [unowned fetchStoredAreaInfoOperation, unowned downloadFromCloudOperation, unowned notifyUserIfNeededOperation] in
            guard let areaInfo = downloadFromCloudOperation.areaInfo  else {
                notifyUserIfNeededOperation.cancel()
                return
            }
            notifyUserIfNeededOperation.storedAreaInfo = fetchStoredAreaInfoOperation.result
            notifyUserIfNeededOperation.freshAreaInfo = areaInfo
        }
        
        passDataToNotification.addDependency(fetchStoredAreaInfoOperation)
        passDataToNotification.addDependency(downloadFromCloudOperation)
        notifyUserIfNeededOperation.addDependency(passDataToNotification)
        
        return [fetchLocationOperation, sendLocationToCloud, downloadFromCloudOperation,
                fetchStoredAreaInfoOperation, passDataToNotification,
                addToStoreOperation, passCloudResultsToStore, notifyUserIfNeededOperation]
        }
    }
    
    class NotifyUserIfNeeded: Operation {
        var storedAreaInfo: AreaInfoEntry?
        var freshAreaInfo: AreaInfo?
        private let context: NSManagedObjectContext
        let notificationManager = NotificationManager()
        
        init(context: NSManagedObjectContext) {
            self.context = context
        }
        
        override func main() {
            guard let newStatusCode = freshAreaInfo?.statusCode else {return}
            let oldStatusCode = storedAreaInfo?.statusCode

            if(newStatusCode != oldStatusCode){
                    notificationManager.registerForNotifications(statusCode: newStatusCode)
            }
           
        }
    }

// Fetches the most recent location entry from the Core Data store.
class FetchLocationOperation: Operation {
    private let context: NSManagedObjectContext
    
    var resultLocationEntry: LocationEntry?
    
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
                
                resultLocationEntry = fetchResult[0]
            } catch {
                print("Error fetching from context: \(error)")
            }
        }
    }
}

class FetchAreaInfoOperation: Operation {
    private let context: NSManagedObjectContext
    
    var result: AreaInfoEntry?
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    override func main() {
        let request: NSFetchRequest<AreaInfoEntry> = AreaInfoEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(AreaInfoEntry.timestamp), ascending: false)]
        request.fetchLimit = 1
        
        context.performAndWait {
            do {
                let fetchResult = try context.fetch(request)
                guard !fetchResult.isEmpty else { return }
                
                result = fetchResult[0]
            } catch {
                print("Error fetching from context: \(error)")
            }
        }
    }
}


// trigger cloud function to calculate covid status in the area
class DownloadFromCloudOperation : Operation {
    private let context: NSManagedObjectContext
    var functions = Functions.functions()
    var areaInfo : AreaInfo?
    
    
    enum OperationError: Error {
        case cancelled
    }
    
    var currentLocation : LocationEntry?
    var result: Result<[HTTPSCallableResult?], Error>?
    private var downloading = false
    private var currentDownloadTask: DownloadTask?
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    convenience init(context: NSManagedObjectContext, location : LocationEntry?) {
        self.init(context: context)
        self.currentLocation = location
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
        
        guard !isCancelled, let location = currentLocation else {
            finish(result: .failure(OperationError.cancelled))
            return
        }
        
        let lat = currentLocation?.lat
        let lon = currentLocation?.lon
        let language = NSLocale.current.languageCode
        
        functions.httpsCallable("calculateCovidStatus").call(["lat": lat, "lon": lon, "language": language]) { (result, error) in
          if let error = error as NSError? {
            if error.domain == FunctionsErrorDomain {
              let code = FunctionsErrorCode(rawValue: error.code)
              let message = error.localizedDescription
              let details = error.userInfo[FunctionsErrorDetailsKey]
            }
           
            self.finish(result: .failure(error))
          }
          if let resultData = (result?.data as? [String: Any]) {
            let resultMessage = resultData["message"] as? String
            print(resultMessage)
            let resultStatusCode = resultData["statusCode"] as? String
            let resultColor = resultData["color"] as? String
            let resultCases = resultData["cases"] as? String
            print(resultCases)
            self.areaInfo = AreaInfo (timestamp: Date(), statusCode: resultStatusCode, message: resultMessage, cases: resultCases)
        
            self.finish(result: .success([result]))
          }
        }
    }
}

class AddLocationEntryToStoreOperation: Operation {
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
        guard let locationEntry = locationEntry else { return }

        context.performAndWait {
            do {
                _ = LocationEntry(context: context, lat: locationEntry.lat, lon: locationEntry.lon, timestamp: locationEntry.timestamp!)
                    print("Adding entry with timestamp: \(locationEntry.timestamp)")
                    try context.save()
                
            } catch {
                print("Error adding entries to store: \(error)")
            }
        }
    }
}

// Add entries returned from the server to the Core Data store.
class AddAreaInfoToStoreOperation: Operation {
    private let context: NSManagedObjectContext
    var areaInfo: AreaInfo?

    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    convenience init(context: NSManagedObjectContext, areaInfo: AreaInfo) {
        self.init(context: context)
        self.areaInfo = areaInfo
    }
    
    override func main() {
        guard let areaInfo = areaInfo else { return }

        context.performAndWait {
            do {
                    _ = AreaInfoEntry(context: context, areaInfo: areaInfo)
                    
                    print("Adding entry areaInfo with timestamp: \(areaInfo.timestamp)")
                    
                    try context.save()

            } catch {
                print("Error adding areaInfo entries to store: \(error)")
            }
        }
    }
}

// Delete old entries  from the Core Data store.
class DeleteAreaInfoEntriesOperation: Operation {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    // TODO implementation
}

// A struct representing the response from the cloud.
struct AreaInfo: Codable {
    let timestamp: Date?
    let statusCode: String?
    let message: String?
    let cases: String?
}

// An extension to create a AreaInfoEntry object from the cloud representation of an entry.
extension AreaInfoEntry {
    convenience init(context: NSManagedObjectContext, areaInfo: AreaInfo) {
        self.init(context: context)
        self.message = areaInfo.message
        self.statusCode = areaInfo.statusCode
        self.timestamp = areaInfo.timestamp
        self.cases = areaInfo.cases
    }
}

extension LocationEntry {
    convenience init (context: NSManagedObjectContext, lat: Double, lon: Double, timestamp: Date) {
        self.init(context: context)
        self.lat = lat
        self.lon = lon
        self.timestamp = timestamp
        self.id = 0   // replace previous entry location
    }
}

