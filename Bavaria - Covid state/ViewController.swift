//
//  ViewController.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 07/11/2020.
//

import UIKit
import CoreLocation

class ViewController: UIViewController {
    
    let locationManager = CLLocationManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.delegate = self
        
//        locationManager.desiredAccuracy = kCLLocationAccuracyBest
//             locationManager.requestWhenInUseAuthorization()
//
//        // if previously user has allowed the location permission, then request location
//           if(CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways){
//               locationManager.requestLocation()
//           }
        
    }
    
    @IBAction func onClick(_ sender: Any) {
        //
//        fetchData(urlString: urlString) { (result) in
//            switch result {
//            case .Success(let data):
//                print(data)
//            case .Error(let message):
//                print("error", message)
//            }
//        }
        
        retriveCurrentLocation()
    }
    
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

extension UIViewController : CLLocationManagerDelegate {
    
   public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            print("location manager authorization status changed")
            
            switch status {
            case .authorizedAlways:
                print("user allow app to get location data when app is active or in background")
            case .authorizedWhenInUse:
                print("user allow app to get location data only when app is active")
            case .denied:
                print("user tap 'disallow' on the permission dialog, cant get location data")
            case .restricted:
                print("parental control setting disallow location data")
            case .notDetermined:
                print("the location permission dialog haven't shown before, user haven't tap allow/disallow")
            }
        }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let lastLocation = locations.last!
        print(  lastLocation.coordinate.latitude)
        print(  lastLocation.coordinate.longitude)
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // might be a good idea to show an alert to user to ask them to walk to a place with GPS signal
    }
    
}

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



