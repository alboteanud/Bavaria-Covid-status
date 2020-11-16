//
//  ViewController.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 07/11/2020.
//

import UIKit

class ViewController: UIViewController{

    override func viewDidLoad() {
        super.viewDidLoad()
      
    }
    
    @IBAction func onClick(_ sender: Any) {
        NotificationManager().registerForNotifications(statusCode: "fake")

    }
   
    

    
}




