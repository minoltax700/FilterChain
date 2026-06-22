//
//  ContentView.swift
//  Example
//
//  Created by Kyle Yoon on 6/17/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Camera") {
                    CameraView()
                }
                NavigationLink("Photos") {
                    Text("Photos")
                        .foregroundStyle(.secondary)
                }
                .disabled(true)
            }
            .navigationTitle("Example")
        }
    }
}

#Preview {
    ContentView()
}
