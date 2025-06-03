//
//  SensorDataManager.swift
//  EaglePuffs
//
//  Created by Harpreet Athwal on 6/2/25.
//


import CoreData

class SensorDataManager {
    static let shared = SensorDataManager()

    private init() {}

    func clearAllSensorData(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = SensorData.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        do {
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes: [AnyHashable: Any] = [
                    NSDeletedObjectsKey: objectIDs
                ]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
            }
        } catch {
            print("Failed to clear SensorData: \(error)")
        }
    }

}
