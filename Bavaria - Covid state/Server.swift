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
//    func fetchMovies(since startDate: Date, completion: @escaping (Result<[ServerEntry], Error>) -> Void)-> URLSessionDataTask?
   
    func getCallTask(lat: String, lon: String, language: String, completion: @escaping (Result<[HTTPSCallableResult?], Error>) -> Void)
}


// A struct representing the response from the cloud.
struct ServerEntry: Codable {
    let timestamp: Date?
    let statusCode: String?
    let message: String?
    let cases: String?
    
    struct Color: Codable {
        var red: Double
        var blue: Double
        var green: Double
    }
    
    let color: Color
}
