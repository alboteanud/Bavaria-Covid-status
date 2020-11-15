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
                let allEntriesRequest: NSFetchRequest<NSFetchRequestResult> = AreaInfo.fetchRequest()
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
    
    private func generateFakeEntries(from date: Date, context: NSManagedObjectContext) -> [AreaInfo] {
        var entries = [AreaInfo]()
        let info = AreaInfo.init(entity:  NSEntityDescription.entity(forEntityName: "text", in: context)!, insertInto: context)
      
        let message = "Phase GREEN. The traffic signal is set to GREEN when and if the incidence is below 35 cases per 100.000 residents. These rules apply: Limitations of face-to-face contact in public spaces. Private events ( i.e. weddings etc. ) with a maximum of 100 participants in closed spaces and a maximum of 200 participants in the open. Wearing a mask is mandatory when ( including, but not limited to ) using public transportation, going shopping, eating and drinking in restaurants, bars, etc. and in case minimum distance (1.5m ) cannot be kept"
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

