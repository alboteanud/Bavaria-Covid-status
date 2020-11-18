//
//  ViewController.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 07/11/2020.
//

import UIKit
import CoreData

class ViewController: UIViewController , NSFetchedResultsControllerDelegate{
    var server = CloudServer()
    var fetchRequest: NSFetchRequest<FeedEntry>!
    private var fetchedResultsController: NSFetchedResultsController<FeedEntry>!
    var feedEntry: FeedEntry?
    
    @IBOutlet weak var updateButton: UIButton!
    @IBOutlet weak var colorView: UIView!
    @IBOutlet weak var instructionsTextView: UITextView!
    @IBOutlet weak var changeLocationButton: UIButton!
    @IBOutlet weak var casesTextView: UITextView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var locationTextView: UITextView!
 
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initFetchedResultsController()
        fetchFeedEntry()
    }
    
    func initFetchedResultsController()  {
        if fetchRequest == nil {
            fetchRequest = FeedEntry.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(FeedEntry.timestamp), ascending: false)]
            fetchRequest.fetchLimit = 1
        }
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                              managedObjectContext: PersistentContainer.shared.viewContext,
                                                              sectionNameKeyPath: nil,
                                                              cacheName: String(describing: self))
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("Error fetching results: \(error)")
        }
    }
    
    private func fetchFeedEntry() {
        PersistentContainer.shared.viewContext.performAndWait {
            do {
                let fetchResult = try PersistentContainer.shared.viewContext.fetch(fetchRequest)
                guard !fetchResult.isEmpty else { return }
                feedEntry = fetchResult[0]
                updateUI(feedEntry: feedEntry )
                
            } catch {
                print("Error fetching from context: \(error)")
            }
        }
       }
    
    @IBAction func onClick(_ sender: Any) {
//        NotificationManager().registerForNotifications(statusCode: "fake")
        updateEntries()
        
    }
    
    private func updateEntries(){
        showLoadingUI()
        
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        
        let context = PersistentContainer.shared.newBackgroundContext()
        let operations = Operations.getOperationsToFetchCovidData(using: context, server: server)
        operations.last?.completionBlock = {
            DispatchQueue.main.async {
                self.hideLoadingUI()
            }
        }
        
        queue.addOperations(operations, waitUntilFinished: false)
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("controller did change")
        guard let fetchedObjects = controller.fetchedObjects else { return }
        guard !fetchedObjects.isEmpty else { return }
        guard let entry = fetchedObjects[0] as? FeedEntry else {return}
        updateUI(feedEntry: entry)
        feedEntry = entry
    }
    
    private func updateUI(feedEntry: FeedEntry?) {
        guard let entry = feedEntry else { return}
        
        let formatter1 = DateFormatter()
//        formatter1.dateStyle = .short
        let dateString = formatter1.string(from: entry.timestamp!)
        let textToShow: String = entry.message! + dateString
        self.instructionsTextView.text =  textToShow
        
        self.casesTextView.text = entry.cases
        
        let statusColor = entry.color!
        let myUIColor = UIColor(statusColor)
        self.colorView.backgroundColor = myUIColor
        
    }
    
    
    
    private func showLoadingUI(){
        activityIndicator.isHidden = false
        updateButton.isEnabled = false
        colorView.isHidden = true
        instructionsTextView.text = nil
        changeLocationButton.isEnabled = false
        casesTextView.text = nil
    }
    
    private func hideLoadingUI() {
        activityIndicator.stopAnimating()
        updateButton.isEnabled = true
        colorView.isHidden = false
        changeLocationButton.isEnabled = true
    }
    
}
    
    extension UIColor {
        convenience init (_ color: Color) {
            self.init(red: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue), alpha: 1.0)
        }
    }
    







