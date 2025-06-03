//
//  PersistenceController.swift
//  EaglePuffs
//
//  Created by Harpreet Athwal on 6/2/25.
//


import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "SensorData")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load Core Data store: \(error)")
            }
        }
    }
}
