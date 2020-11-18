//
//  PersistentContainer.swift
//  Bavaria - Covid state
//
//  Created by Dan Alboteanu on 14.11.2020.
//

import CoreData


class PersistentContainer : NSPersistentContainer {
    
    static let shared : NSPersistentContainer = {
       
        let container = NSPersistentContainer(name: "CovidStatusFeed")
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


// A platform-agnostic model object representing a color, suitable for persisting with Core Data
public class Color: NSObject, NSSecureCoding {
    public let red: Double
    public let green: Double
    public let blue: Double
    
    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        super.init()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        self.red = aDecoder.decodeDouble(forKey: "red")
        self.green = aDecoder.decodeDouble(forKey: "green")
        self.blue = aDecoder.decodeDouble(forKey: "blue")
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(red, forKey: "red")
        aCoder.encode(green, forKey: "green")
        aCoder.encode(blue, forKey: "blue")
    }
    
    public static var supportsSecureCoding: Bool {
        return true
    }
}

public class ColorTransformer: NSSecureUnarchiveFromDataTransformer {
    public override class func transformedValueClass() -> AnyClass {
        return Color.self
    }
}



