//
//  PuffRate.swift
//  EaglePuffs
//
//  Created by Harpreet Athwal on 6/2/25.
//


import Foundation
import CoreData
import SwiftUI

struct PuffRate: Identifiable {
    let id = UUID()
    let date: Date
    let averageRate: Double
}

class ChartDataProcessor {
    static func averagePuffRateByDay(from sensorDataList: FetchedResults<SensorData>) -> [PuffRate] {
        let grouped = Dictionary(grouping: sensorDataList) { data in
            Calendar.current.startOfDay(for: data.timestamp ?? Date())
        }

        return grouped.map { (date, items) in
            let total = items.reduce(0.0) { $0 + Double($1.duration) }
            let average = total / Double(items.count)
            return PuffRate(date: date, averageRate: average)
        }.sorted(by: { $0.date < $1.date })
    }

    static func averagePuffRateByMinute(from sensorDataList: FetchedResults<SensorData>) -> [PuffRate] {
        let grouped = Dictionary(grouping: sensorDataList) { data in
            let ts = data.timestamp ?? Date()
            return Calendar.current.date(bySetting: .second, value: 0, of: ts) ?? ts
        }

        return grouped.map { (minute, items) in
            let total = items.reduce(0.0) { $0 + Double($1.start) }
            let average = total / Double(items.count)
            return PuffRate(date: minute, averageRate: average)
        }.sorted(by: { $0.date < $1.date })
    }
}
