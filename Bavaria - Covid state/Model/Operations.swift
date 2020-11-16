//
//  Operations.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 14.11.2020.
//

import Firebase
import CoreData

struct Operations {

    static func getOperationsToFetchCovidData(using context: NSManagedObjectContext) -> [Operation] {
        let fetchMostRecentLocationOperation = FetchMostRecentLocationOperation(context: context)
        let triggerCloudFunctionOperation = TriggerCloudFunctionOperation(context: context)
        
        let sendLocationToCloudFunction = BlockOperation { [unowned fetchMostRecentLocationOperation, unowned triggerCloudFunctionOperation] in
            guard (fetchMostRecentLocationOperation.result) != nil else {
                triggerCloudFunctionOperation.cancel()
                return
            }
            triggerCloudFunctionOperation.currentLocation = fetchMostRecentLocationOperation.result
        }
        
        sendLocationToCloudFunction.addDependency(fetchMostRecentLocationOperation)
        triggerCloudFunctionOperation.addDependency(sendLocationToCloudFunction)
        
        return [fetchMostRecentLocationOperation, sendLocationToCloudFunction, triggerCloudFunctionOperation]
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
                
                result = fetchResult[0]
            } catch {
                print("Error fetching from context: \(error)")
            }
        }
    }
}

class TriggerCloudFunctionOperation : Operation {
    private let context: NSManagedObjectContext
    var functions = Functions.functions()
    
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
        let resultTXT = (result?.data as? [String: Any])
          if let resultText = (result?.data as? [String: Any])?["text"] as? String {
            print(resultText)
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
class AddAreaInfoEntryToStoreOperation: Operation {
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
                    
                    print("Adding entry with timestamp: \(areaInfo.timestamp)")
                    
                    try context.save()

            } catch {
                print("Error adding entries to store: \(error)")
            }
        }
    }
}

// A struct representing the response from the server for a single feed entry.
struct AreaInfo: Codable {
    let timestamp: Date
    let dangerlevel: Int16
    let message: String
}

// An extension to create a AreaInfoEntry object from the server representation of an entry.
extension AreaInfoEntry {
    convenience init(context: NSManagedObjectContext, areaInfo: AreaInfo) {
        self.init(context: context)
        self.message = areaInfo.message
        self.dangerlevel = areaInfo.dangerlevel
        self.timestamp = areaInfo.timestamp
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

