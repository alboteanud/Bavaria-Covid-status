//
//  CloudService.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 18.11.2020.
//

import Foundation
import Firebase

class CloudServer: Server {
    
    static let sharedInstance = CloudServer()
    lazy var functions : Functions = Functions.functions()
    
    func callCloudFunction(location : LocationEntry?, completion: @escaping (Result<ServerEntry, Error>) -> Void){
        guard let location = location else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: nil)))
            return
        }
        let language = Locale.current.languageCode
        let lat = location.lat
        let lon = location.lon
        
//        let functions = Functions.functions()
        
        functions.httpsCallable("calculateCovidStatus").call(["lat": lat, "lon": lon, "language": language]) { (result, error) in
           if let error = error as NSError? {
            
            completion(.failure(error))
           }
           guard let resultData = (result?.data as? [String: Any]) ,
              let resultMessage = resultData["message"] as? String,
//              print(resultMessage)
              let resultStatusCode = resultData["statusCode"] as? String,
              let resultColor = resultData["color"] as? String,
              let cases = resultData["cases"] as? Float
//              print(cases)
            else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: nil)))
                return }
            let color = ServerEntry.Color.hexStringToUIColor(hex: resultColor)
            let entry = ServerEntry (color: color, timestamp: Date(), statusCode: resultStatusCode, message: resultMessage, cases: cases)

             completion(.success(entry))
           
        }
    }
    
}

extension ServerEntry.Color {

static func hexStringToUIColor (hex:String) -> ServerEntry.Color {
    var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

    if (cString.hasPrefix("#")) {
        cString.remove(at: cString.startIndex)
    }

    if ((cString.count) != 6) {
        return ServerEntry.Color(red: 7, blue: 7, green: 7)
    }

    var rgbValue:UInt32 = 0
    Scanner(string: cString).scanHexInt32(&rgbValue)

    let red  = Double(CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0 )
    let green = Double(CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0)
    let  blue = Double(CGFloat(rgbValue & 0x0000FF) / 255.0)

    
    return ServerEntry.Color(red: red, blue: blue, green: green)
}
}

extension UIColor {
    convenience init (_ color: Color) {
        self.init(red: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue), alpha: 1.0)
    }
}
