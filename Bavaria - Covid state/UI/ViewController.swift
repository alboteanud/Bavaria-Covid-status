//
//  ViewController.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 07/11/2020.
//

import UIKit
import CoreLocation
import Firebase

class ViewController: UIViewController{
    
    lazy var functions = Functions.functions()

    override func viewDidLoad() {
        super.viewDidLoad()
        // update UI
    }
    
    @IBAction func onClick(_ sender: Any) {

callCloudFunction()
    }
    
    func callCloudFunction(){
        functions.httpsCallable("addMessage2").call(["text": "hi"]) { (result, error) in
          if let error = error as NSError? {
            if error.domain == FunctionsErrorDomain {
              let code = FunctionsErrorCode(rawValue: error.code)
              let message = error.localizedDescription
              let details = error.userInfo[FunctionsErrorDetailsKey]
            }
            // ...
          }
          if let text = (result?.data as? [String: Any])?["text"] as? String {
//            self.resultField.text = text
            print(text)
          }
        }
    }
    

    
}




