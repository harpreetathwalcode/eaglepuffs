//
//  PuffChartsView.swift
//  EaglePuffs
//
//  Created by Harpreet Athwal on 6/2/25.
//
import SwiftUI
import Charts
import CoreData

struct PuffChartsView: View {
    var sensorDataList: FetchedResults<SensorData>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {

                // Line Chart: Puff Rate Over Time
                Text("Puff Rate Over Time")
                    .font(.headline)
                Chart(sensorDataList) { data in
                    LineMark(
                        x: .value("Time", data.timestamp ?? Date()),
                        y: .value("Puff Rate", data.start)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 200)

                // Bar Chart: Average Puff Rate Per Day
                Text("Average Puff Rate Per Day")
                    .font(.headline)
                Chart(ChartDataProcessor.averagePuffRateByDay(from: sensorDataList)) { item in
                    BarMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Avg Rate", item.averageRate)
                    )
                    .foregroundStyle(.orange)
                }
                .frame(height: 200)

                // Bar Chart: Average Puff Rate Per Minute
                Text("Average Puff Rate Per Minute")
                    .font(.headline)
                Chart(ChartDataProcessor.averagePuffRateByMinute(from: sensorDataList)) { item in
                    BarMark(
                        x: .value("Minute", item.date, unit: .minute),
                        y: .value("Avg Rate", item.averageRate)
                    )
                    .foregroundStyle(.purple)
                }
                .frame(height: 200)

                // Scatter Plot: Puff Rate Distribution
                Text("Puff Rate Distribution")
                    .font(.headline)
                Chart(sensorDataList) { data in
                    PointMark(
                        x: .value("Time", data.timestamp ?? Date()),
                        y: .value("Puff Rate", data.start)
                    )
                }
                .frame(height: 200)

                // Gauge: Latest Puff Rate
                if let latest = sensorDataList.last {
                    Text("Current Puff Rate")
                        .font(.headline)
                    Gauge(value: Double(latest.duration), in: 0...1000) {
                        Text("Puff Rate")
                    } currentValueLabel: {
                        Text("\(latest.start)")
                    }
                    .gaugeStyle(.accessoryCircular)
                    .frame(height: 100)
                }

                // Color-Coded Line Chart
                Text("Color-Coded Puff Rate Zones")
                    .font(.headline)
                Chart(sensorDataList) { data in
                    LineMark(
                        x: .value("Time", data.timestamp ?? Date()),
                        y: .value("Puff Rate", data.start)
                    )
                    .foregroundStyle(data.start > 80 ? .red : data.start > 50 ? .orange : .green)
                }
                .frame(height: 200)

            }
            .padding()
        }
    }
}
