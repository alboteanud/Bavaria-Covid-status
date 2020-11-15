//
//  PersistentContainer.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 14.11.2020.
//

import CoreData


class PersistentContainer : NSPersistentContainer {
    
    static let shared : NSPersistentContainer = {
       
        let container = NSPersistentContainer(name: "FeedEntry")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: NSMergePolicyType.mergeByPropertyStoreTrumpMergePolicyType)
        return container
    }()
    
    override func newBackgroundContext() -> NSManagedObjectContext {
        let backgroundContext = super.newBackgroundContext()
        backgroundContext.automaticallyMergesChangesFromParent = true
        backgroundContext.mergePolicy = NSMergePolicy(merge: NSMergePolicyType.mergeByPropertyStoreTrumpMergePolicyType)
        return backgroundContext
    }
    
    
    
}



