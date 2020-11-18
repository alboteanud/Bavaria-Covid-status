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
    let functions = Functions.functions()
    func getCallTask(lat: String, lon: String, language: String, completion: @escaping (Result<[HTTPSCallableResult?], Error>) -> Void){
        
        
       return functions.httpsCallable("calculateCovidStatus").call(["lat": lat, "lon": lon, "language": language]) { (result, error) in
          if let error = error as NSError? {
           
//            self.finish(result: .failure(error))
          }
            // move to api service
          if let resultData = (result?.data as? [String: Any]) {
            let resultMessage = resultData["message"] as? String
            print(resultMessage)
            let resultStatusCode = resultData["statusCode"] as? String
            let resultColor = resultData["color"] as? String
            let resultCases = resultData["cases"] as? String
            print(resultCases)
//            self.areaInfo = AreaInfo (timestamp: Date(), statusCode: resultStatusCode, message: resultMessage, cases: resultCases)
        
//            self.finish(result: .success([result]))
          }
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
