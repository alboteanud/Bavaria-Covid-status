//
//  Operations.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 14.11.2020.
//

import Foundation
import CoreData

struct Operations {

    static func getOperationsToFetchCovidData(using context: NSManagedObjectContext) -> [Operation] {
        let getCurrentLocationOperation = GetCurrentLocationOperation()
        let getDeviceLanguage = GetDeviceLanguageOperation()
        let triggerCloudFunctionToCheckCovidStateOperation = TriggerCloudFunctionToCheckCovidStateOperation()
        
        return [getCurrentLocationOperation,
        getDeviceLanguage,
        triggerCloudFunctionToCheckCovidStateOperation]
    }    

}

class GetCurrentLocationOperation : Operation {
    
    func startMySignificantLocationChanges() {
        let locationManager = CLLocationManager()
//        locationManager.delegate = self
        if !CLLocationManager.significantLocationChangeMonitoringAvailable() {
            // The device does not support this service.
            return
        }
        locationManager.startMonitoringSignificantLocationChanges()
    }
    
    func locationManager(_ manager: CLLocationManager,  didUpdateLocations locations: [CLLocation]) {
       let lastLocation = locations.last!
      print(  lastLocation.coordinate.latitude)
       // Do something with the location.
    }
    
}

class GetDeviceLanguageOperation : Operation {
    
}

class TriggerCloudFunctionToCheckCovidStateOperation : Operation {
    
}


extension NSPersistentContainer {
   
    // Fills the Core Data store with initial fake data
    // If onlyIfNeeded is true, only does so if the store is empty
    func loadInitialData(onlyIfNeeded: Bool = true) {
        let context = newBackgroundContext()
        context.perform {
            do {
                let allEntriesRequest: NSFetchRequest<NSFetchRequestResult> = Entity.fetchRequest()
                if !onlyIfNeeded {
                    // Delete all data currently in the store
                    let deleteAllRequest = NSBatchDeleteRequest(fetchRequest: allEntriesRequest)
                    deleteAllRequest.resultType = .resultTypeObjectIDs
                    let result = try context.execute(deleteAllRequest) as? NSBatchDeleteResult
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: result?.result as Any],
                                                        into: [self.viewContext])
                }
                if try !onlyIfNeeded || context.count(for: allEntriesRequest) == 0 {
                    let now = Date()
                    let start = now - (7 * 24 * 60 * 60)
                    let end = now - (60 * 60)
                    
//                    _ = generateFakeEntries(from: start, to: end).map { FeedEntry(context: context, serverEntry: $0) }
                    
                    let context = PersistentContainer.shared.newBackgroundContext()
                    let operations = Operations.getOperationsToFetchCovidData(using: context)
//                    try context.save()
                    
//                    self.lastCleaned = nil
                }
            } catch {
                print("Could not load initial data due to \(error)")
            }
        }
    }
    
}
