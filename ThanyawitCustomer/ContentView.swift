import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: CustomerStore

    var body: some View {
        NavigationSplitView {
            List {
                Section("ทำงานตามลำดับ") {
                    NavigationLink {
                        DashboardView()
                    } label: {
                        Label("ภาพรวมงาน", systemImage: "chart.bar.doc.horizontal")
                    }

                    NavigationLink {
                        CustomersView()
                    } label: {
                        Label("1 ฐานลูกค้า", systemImage: "building.2")
                    }

                    NavigationLink {
                        BillingView()
                    } label: {
                        Label("2 ตรวจใบชั่ง + อนุมัติบิล", systemImage: "text.viewfinder")
                    }

                    NavigationLink {
                        FormsCommandView()
                    } label: {
                        Label("3 สั่งปริ้นท์เอกสาร", systemImage: "printer")
                    }
                }

                Section("ติดตามและสำรอง") {
                    NavigationLink {
                        DocumentControlView()
                    } label: {
                        Label("4 ทะเบียนคุมเอกสาร", systemImage: "tray.full")
                    }

                    NavigationLink {
                        ExportView()
                    } label: {
                        Label("5 สำรอง/ส่งออก", systemImage: "externaldrive")
                    }
                }
            }
            .navigationTitle("ธัญญวิชญ์")
        } detail: {
            DashboardView()
        }
        .navigationSplitViewStyle(.balanced)
    }
}
