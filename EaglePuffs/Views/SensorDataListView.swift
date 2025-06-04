//
//  SensorDataListView.swift
//  EaglePuffs
//
//  Created by Harpreet Athwal on 6/2/25.
//


import SwiftUI
import CoreData

struct SensorDataListView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SensorData.start, ascending: true)],
        animation: .default
    )
    private var sensorDataList: FetchedResults<SensorData>

    var body: some View {
        List(sensorDataList, id: \.self) { data in
            VStack(alignment: .leading) {
                Text("Start: \(data.start)")
                Text("Duration: \(data.duration)")
                if let timestamp = data.timestamp {
                    Text("Received Timestamp: \(timestamp)")
                } else {
                    Text("Received Timestamp: Unknown")
                }
                Text("Synced: \(data.isSynced ? "Yes" : "No")")
                    .foregroundColor(data.isSynced ? .green : .red)
            }
        }
        .navigationTitle("Sensor Data")
    }
}

#if DEBUG
import CoreData

struct SensorDataListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        
        // Add example data if none exists
        if (try? context.count(for: SensorData.fetchRequest())) == 0 {
            for i in 0..<5 {
                let newData = SensorData(context: context)
                newData.start = Int64(Int16(10 + i * 5))
                newData.duration = Int64(Int16(20 + i * 10))
                newData.timestamp = Calendar.current.date(byAdding: .day, value: -i, to: Date())
                newData.isSynced = i % 2 == 0
            }
            try? context.save()
        }
        
        return NavigationView {
            SensorDataListView()
                .environment(\.managedObjectContext, context)
        }
    }
}
#endif
