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

    static func getOperationsToFetchCovidData(using context: NSManagedObjectContext, server: Server) -> [Operation] {
        let fetchLocationOperation = FetchLocationOperation(context: context)
        let downloadFromCloudOperation = DownloadFromCloudOperation(context: context, server: server)
        
        let sendLocationToCloud = BlockOperation { [unowned fetchLocationOperation, unowned downloadFromCloudOperation] in
            guard (fetchLocationOperation.resultLocationEntry) != nil else {
                downloadFromCloudOperation.cancel()
                return
            }
            downloadFromCloudOperation.currentLocation = fetchLocationOperation.resultLocationEntry
        }
        
        sendLocationToCloud.addDependency(fetchLocationOperation)
        downloadFromCloudOperation.addDependency(sendLocationToCloud)
        
        let fetchFeedEntryOperation = FetchFeedEntryOperation(context: context)
        let notifyUserIfNeededOperation = NotifyUserIfNeeded(context: context)
        let passDataToNotification = BlockOperation { [unowned fetchFeedEntryOperation, unowned downloadFromCloudOperation, unowned notifyUserIfNeededOperation] in
            guard case let .success(serverEntry)? = downloadFromCloudOperation.result else {
                notifyUserIfNeededOperation.cancel()
                return
            }
            notifyUserIfNeededOperation.storedAreaInfo = fetchFeedEntryOperation.result
            notifyUserIfNeededOperation.freshAreaInfo = serverEntry
        }
        passDataToNotification.addDependency(fetchFeedEntryOperation)
        passDataToNotification.addDependency(downloadFromCloudOperation)
        notifyUserIfNeededOperation.addDependency(passDataToNotification)
        
        let addToStoreOperation = AddEntriesToStoreOperation(context: context)
        let passCloudResultsToStore = BlockOperation { [unowned downloadFromCloudOperation, unowned addToStoreOperation] in
        guard case let .success(serverEntry)? = downloadFromCloudOperation.result else {
                addToStoreOperation.cancel()
                return
            }
            addToStoreOperation.entry = serverEntry
        }
        passCloudResultsToStore.addDependency(downloadFromCloudOperation)
        addToStoreOperation.addDependency(passCloudResultsToStore)
        
        return [fetchLocationOperation, sendLocationToCloud, downloadFromCloudOperation,
                fetchFeedEntryOperation, passDataToNotification,
                addToStoreOperation, passCloudResultsToStore, notifyUserIfNeededOperation]
        }
    }
    
    class NotifyUserIfNeeded: Operation {
        var storedAreaInfo: FeedEntry?
        var freshAreaInfo: ServerEntry?
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

// An extension to create a FeedEntry object from the Firebase Cloud Function representation of an entry.
extension FeedEntry {
    convenience init(context: NSManagedObjectContext, areaInfo: ServerEntry) {
        self.init(context: context)
        self.message = areaInfo.message
        self.statusCode = areaInfo.statusCode
        self.timestamp = areaInfo.timestamp
        self.cases = areaInfo.cases
        self.color = Color(areaInfo.color)
        self.locationName = areaInfo.locationName
        self.lat = areaInfo.lat ?? 0
        self.lon = areaInfo.lon ?? 0
    }
}

// An extension to create a Color object from the server representation of a color.
extension Color {
    convenience init(_ color: ServerEntry.Color) {
        self.init(red: color.red, green: color.green, blue: color.blue)
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
                fetchResult.forEach{ element in
                    print("location fetched from local DB (lat, lon, stored at):", element.lat, element.lon, element.timestamp)
                }
                resultLocationEntry = fetchResult[0]
            } catch {
                print("Error fetching from context: \(error)")
            }
        }
    }
}

// Fetches the most recent entry from the Core Data store.
class FetchFeedEntryOperation: Operation {
    private let context: NSManagedObjectContext
    
    var result: FeedEntry?
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    override func main() {
        let request: NSFetchRequest<FeedEntry> = FeedEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(FeedEntry.timestamp), ascending: false)]
        request.fetchLimit = 1
        
        context.performAndWait {
            do {
                let fetchResult = try context.fetch(request)
                guard !fetchResult.isEmpty else { return }
                print(fetchResult.count)
                fetchResult.forEach{ (element) in
                    print("FetchFeedEntryOperation entry: ", element.timestamp, element.cases, element.color)
                }
                result = fetchResult[0]
            } catch {
                print("Error fetching from context: \(error)")
            }
        }
    }
}

// Trigger cloud function to calculate covid status in the area.
// Tribute to https://developer.apple.com/videos/play/wwdc2019/707
class DownloadFromCloudOperation : Operation {
    private let context: NSManagedObjectContext
    var functions = Functions.functions()
//    var areaInfo : ServerEntry?
    private let server: Server
    
    enum OperationError: Error {
        case cancelled
    }
    
    var currentLocation : LocationEntry?
    var result: Result<ServerEntry, Error>?
    private var downloading = false
    private var currentDownloadTask: DownloadTask?
    
    init(context: NSManagedObjectContext, server: Server) {
        self.context = context
        self.server = server
    }
    
    convenience init(context: NSManagedObjectContext, location : LocationEntry?, server: Server) {
        self.init(context: context, server: server)
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
    
        func finish(result: Result<ServerEntry, Error>) {
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
        server.callCloudFunction(location: currentLocation, completion: finish)
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
//        print(locationEntry.lat)
    }
    
    override func main() {
        guard let locationEntry = locationEntry else { return }
        print(locationEntry.lat)
        context.performAndWait {
            do {
                _ = locationEntry
                print("Adding location entry to DB. Lat: \(locationEntry.lat)")
                    try context.save()
                
            } catch {
                print("Error adding location entriy to store: \(error)")
            }
        }
    }
}

// Add entries returned from the server to the Core Data store.
class AddEntriesToStoreOperation: Operation {
    private let context: NSManagedObjectContext
    var entry: ServerEntry?

    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    convenience init(context: NSManagedObjectContext, areaInfo: ServerEntry) {
        self.init(context: context)
        self.entry = areaInfo
    }
    
    override func main() {
        guard let areaInfo = entry else { return }

        context.performAndWait {
            do {
                    _ = FeedEntry(context: context, areaInfo: areaInfo)
                    
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



