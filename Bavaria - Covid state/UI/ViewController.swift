//
//  ViewController.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 07/11/2020.
//

import UIKit
import CoreData

class ViewController: UIViewController , NSFetchedResultsControllerDelegate{
    private var server = CloudServer()
    private var fetchRequest: NSFetchRequest<FeedEntry>!
    private var fetchedResultsController: NSFetchedResultsController<FeedEntry>!
    private var feedEntry: FeedEntry?
    
    @IBOutlet weak var updateButton: UIButton!
    @IBOutlet weak var colorView: UIView!
    @IBOutlet weak var instructionsTextView: UITextView!
    @IBOutlet weak var changeLocationButton: UIButton!
    @IBOutlet weak var casesTextView: UITextView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var locationTextView: UITextView!
 
    @IBAction func onChangeLocationButtonClick(_ sender: Any) {
//        PersistentContainer.shared.insertFakeLocation()
        
        // Save changes in the application's managed object context when the application transitions to the background.
//        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
        save()
    }
    
    func save() {
      
      guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
        return
      }
      
        let managedContext = PersistentContainer.shared.viewContext
//       appDelegate.persistentContainer.viewContext
        PersistentContainer.shared.insertFakeLocation3(context: managedContext)
      
//      let entity =
//        NSEntityDescription.entity(forEntityName: "LocationEntry",
//                                   in: managedContext)!
//fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(FeedEntry.timestamp), ascending: false)]
//
//      let person = NSManagedObject(entity: entity, insertInto: managedContext)
//
//      person.setValue("Berlin", forKeyPath: "name")
//        person.setValue(1, forKeyPath: "id")
//        person.setValue(52.000, forKeyPath: "lat")
//        person.setValue(13.3817, forKeyPath: "lon")
//        person.setValue(Date(), forKeyPath: "timestamp")
////        "Berlin": [52.531677, 13.3817],
//
//      // 4
//      do {
//        try managedContext.save()
////        people.append(person)
//      } catch let error as NSError {
//        print("Could not save. \(error), \(error.userInfo)")
//      }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initFetchedResultsController()
        fetchFeedEntry()
    }
    
   func viewDidLoad2() {
        super.viewDidLoad()
        
        
        if fetchRequest == nil {
            fetchRequest = FeedEntry.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(FeedEntry.timestamp), ascending: false)]
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
    
    @IBAction func onUpdateButtonClick(_ sender: Any) {
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
        
        let cases = NumberFormatter.localizedString(from: Int(entry.cases) as NSNumber, number: .decimal)
        let formatString = NSLocalizedString("You have %@ Corona cases per 100k inhabitants",
                                             comment: "How many Coronavirus cases there are in the area per 100k people")
        self.casesTextView.text = String.localizedStringWithFormat(formatString, cases)
        
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

    







