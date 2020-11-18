//
//  ViewController.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 07/11/2020.
//

import UIKit
import CoreData

class ViewController: UIViewController , NSFetchedResultsControllerDelegate{
    var server: Server!
    var fetchRequest: NSFetchRequest<FeedEntry>!
    
    @IBOutlet weak var textMessageView: UITextField!
    private var fetchedResultsController: NSFetchedResultsController<FeedEntry>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        tableView.separatorStyle = .none
        
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
    
    @IBAction func onClick(_ sender: Any) {
        NotificationManager().registerForNotifications(statusCode: "fake")

        let context = PersistentContainer.shared.newBackgroundContext()
        let request: NSFetchRequest<FeedEntry> = FeedEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(FeedEntry.timestamp), ascending: false)]
        request.fetchLimit = 1
        
        context.performAndWait {
            do {
                let fetchResult = try context.fetch(request)
                guard !fetchResult.isEmpty else { return }
                print(fetchResult.count)
                fetchResult.forEach{ (element) in
                    print(element.timestamp, element.cases)
                }
                
//                DispatchQueue.main.async {
                    self.textMessageView.text = fetchResult[0].message
//                }
                
            } catch {
                print("Error fetching from context: \(error)")
            }
        }
        
        
    }
   
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange sectionInfo: NSFetchedResultsSectionInfo,
                    atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
//            tableView.insertSections(IndexSet(integer: sectionIndex), with: .automatic)
            textMessageView.text = "inserted"
        case .delete:
//            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .automatic)
            textMessageView.text = "deleted"
        default:
            return
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange anObject: Any, at indexPath: IndexPath?,
                    for type: NSFetchedResultsChangeType,
                    newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            guard let newIndexPath = newIndexPath else { return }
//            tableView.insertRows(at: [newIndexPath], with: .automatic)
        case .delete:
            guard let indexPath = indexPath else { return }
//            tableView.deleteRows(at: [indexPath], with: .automatic)
        case .update:
//            if let cell = tableView.cellForRow(at: indexPath!) as? FeedEntryTableViewCell {
//                configure(cell: cell, at: indexPath!)
//            }
            textMessageView.text = "updated"
        case .move:
            guard let indexPath = indexPath, let newIndexPath = newIndexPath else { return }
//            tableView.moveRow(at: indexPath, to: newIndexPath)
        default:
            return
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        tableView.endUpdates()
        print("controller did change")
    }
    
//    func configure(cell: FeedEntryTableViewCell, at indexPath: IndexPath) {
//        let feedEntry = fetchedResultsController.object(at: indexPath)
//        cell.feedEntry = feedEntry


        
    @IBAction private func fetchLatestEntries(_ sender: UIRefreshControl) {
        sender.beginRefreshing()
        
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        
        let context = PersistentContainer.shared.newBackgroundContext()
        let operations = Operations.getOperationsToFetchCovidData(using: context, server: server)
        operations.last?.completionBlock = {
            DispatchQueue.main.async {
                sender.endRefreshing()
            }
        }
        
        queue.addOperations(operations, waitUntilFinished: false)
    }
    
    @IBAction private func showActions(_ sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.popoverPresentationController?.barButtonItem = sender
        
        alertController.addAction(UIAlertAction(title: "Reset Feed Data", style: .destructive, handler: { _ in
            PersistentContainer.shared.loadInitialData(onlyIfNeeded: false)
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(alertController, animated: true, completion: nil)
    }

    
}

extension UIColor {
    convenience init (_ color: Color) {
        self.init(red: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue), alpha: 1.0)
    }
}







