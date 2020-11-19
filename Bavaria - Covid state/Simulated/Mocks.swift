//
//  Mocks.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 15.11.2020.
//

import Foundation
import CoreData

struct Mocks {
    
}

extension NSPersistentContainer {
   
    // Fills the Core Data store with initial fake data
    // If onlyIfNeeded is true, only does so if the store is empty
    func loadInitialData(onlyIfNeeded: Bool = true) {
        let context = newBackgroundContext()
        context.perform {
            do {
                let allEntriesRequest: NSFetchRequest<NSFetchRequestResult> = FeedEntry.fetchRequest()
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
                    
//                    _ = self.generateFakeEntries(from: now, context: context).map { _ in AreaInfo(context: context) }
                    try context.save()
                    
//                    self.lastCleaned = nil
                }
            } catch {
                print("Could not load initial data due to \(error)")
            }
        }
    }
    
    // needs refractoring
    func insertFakeLocation(context: NSManagedObjectContext) -> String? {
        let entity = NSEntityDescription.entity(forEntityName: "LocationEntry",
                                           in: context)!
//        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(FeedEntry.timestamp), ascending: false)]
        let fakeLocation = getFakeLocation()
        let name = fakeLocation.name
        print("will insert FakeLocation",fakeLocation.name)
        let object = NSManagedObject(entity: entity, insertInto: context)
        object.setValue(fakeLocation.name, forKeyPath: "name")
        object.setValue(fakeLocation.id, forKeyPath: "id")
        object.setValue(fakeLocation.lat, forKeyPath: "lat")
        object.setValue(fakeLocation.lon, forKeyPath: "lon")
        object.setValue(fakeLocation.timestamp, forKeyPath: "timestamp")

        do {
            try context.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
//        print("did insert FakeLocation",name)
        return name
    }
    
    func addLocationToStore(location: CLLocation){
        let context = PersistentContainer.shared.newBackgroundContext()
        
        let entry = LocationEntry(context: context, location: location)
        let operation = AddLocationEntryToStoreOperation(context: context, locationEntry: entry)
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.addOperation(operation)
    }
    
    func insertFakeLocation() {
        let newLocation = getFakeLocation()
        let context = PersistentContainer.shared.viewContext
        print("inserting FakeLocation in DB ",newLocation.lat, newLocation.lon)
        let operation = AddLocationEntryToStoreOperation(context: context, locationEntry: newLocation)
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.addOperation(operation)
    }
    
    private func getFakeLocation() -> LocationEntry {
        let context = PersistentContainer.shared.newBackgroundContext()
        let key = locations.keys.randomElement()!
        let location = locations[key]
        let lat = location![0]
        let lon = location![1]
        return LocationEntry(context: context, location: CLLocation(latitude: lat, longitude: lon), locationName: key)
      
    }
  
    private func generateFakeEntries(from date: Date, context: NSManagedObjectContext) -> [FeedEntry] {
        var entries = [FeedEntry]()
        let info = FeedEntry.init(entity:  NSEntityDescription.entity(forEntityName: "text", in: context)!, insertInto: context)
      
        entries.append(info)
      
        return entries
    }
    
    //        fetchData(urlString: urlString) { (result) in
    //            switch result {
    //            case .Success(let data):
    //                print(data)
    //            case .Error(let message):
    //                print("error", message)
    //            }
    //        }
    
    enum Result<T> {
        case Success(T)
        case Error(String)
    }

    struct Source : Codable {
        struct Features : Codable {
            struct Attributes : Codable {
                let cases7_per_100k: Double
            }
            let attributes: Attributes
        }
        let features: [Features]
    }

    // "features": [{
    // "attributes": {
    //  "cases7_per_100k": 52.3705563898389
    // }
    // }]
    
    func fetchData(completion: @escaping (Result<Double>) -> Void) {
        let urlString = "https://services7.arcgis.com/mOBPykOjAyBO2ZKk/arcgis/rest/services/RKI_Landkreisdaten/FeatureServer/0/query?where=1%3D1&outFields=cases7_per_100k&geometry=12%2C52&geometryType=esriGeometryPoint&inSR=4326&spatialRel=esriSpatialRelIntersects&returnGeometry=false&outSR=4326&f=json"
        
        guard let url = URL(string: urlString) else { return completion(.Error("Invalid URL")) }
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            
            guard error == nil else { return completion(.Error(error!.localizedDescription)) }
            guard let data = data else { return completion(.Error(error?.localizedDescription ?? "There is no data"))}
            do {
                let decoded = try JSONDecoder().decode(Source.self, from: data)
                if decoded.features.count > 0 {
                    let cases = decoded.features[0].attributes.cases7_per_100k
                    DispatchQueue.main.async {
                        completion(.Success(cases))
                    }
                } else {
                    return completion(.Error("Response features is empty"))
                }
                
            } catch let error {
                return completion(.Error(error.localizedDescription))
            }
            
        }.resume()
        
    }
    
    func retriveCurrentLocation(){
        let status = CLLocationManager.authorizationStatus()
        let locationManager = CLLocationManager()

        if(status == .denied || status == .restricted || !CLLocationManager.locationServicesEnabled()){
            // show alert to user telling them they need to allow location data to use some feature of your app
            return
        }

        // if haven't show location permission dialog before, show it to user
        if(status == .notDetermined){
            locationManager.requestWhenInUseAuthorization()

            // if you want the app to retrieve location data even in background, use requestAlwaysAuthorization
             locationManager.requestAlwaysAuthorization()
            return
        }
        
        locationManager.requestLocation()
      
    }
    
}

var locations = ["Berlin": [52.531677, 13.3817],
                 "München": [48.137154, 11.576124],
                 "Dresden": [51.050407, 13.737262],
                 "Hamburg": [53.551086, 9.99743],
                 "Stuttgart": [48.783333, 9.183333],
                 "Köln": [50.935173, 6.953101],
                 "Düsseldorf": [51.233334, 6.783333],
                 "Nürnberg": [49.460983, 11.061859],
                 "Regensburg": [49.013432, 12.101624],
                 "Augsburg": [48.366512, 10.894446]
                 
]

