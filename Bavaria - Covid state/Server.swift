//
//  Server.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 15.11.2020.
//

import Foundation
import Firebase

// A cancellable download task.
protocol DownloadTask {
    func cancel()
    var isCancelled: Bool { get }
}

protocol Server {
    func callCloudFunction(location : LocationEntry?, completion: @escaping (Result<ServerEntry, Error>) -> Void)
}


// A struct representing the response from the cloud.
struct ServerEntry: Codable {
    struct Color: Codable {
        var red: Double
        var blue: Double
        var green: Double
    }
    
    let color: Color
    let timestamp: Date?
    let statusCode: String?
    let message: String?
    let cases: Float
}




