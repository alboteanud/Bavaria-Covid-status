//
//  Server.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 15.11.2020.
//

import Foundation

// A cancellable download task.
protocol DownloadTask {
    func cancel()
    var isCancelled: Bool { get }
}
