import SwiftUI

/// Shared real controls: setup and the everyday panel edit the same schedule.
struct SleepScheduleView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ClockField(title: "Wake", symbol: "sunrise", time: $model.wake)
                Rectangle().fill(Theme.steel).frame(width: 1, height: 44)
                ClockField(title: "Bedtime", symbol: "moon", time: $model.bed)
            }
            Divider().overlay(Theme.steel)
            HStack {
                Text("Night light").emberLabel(16).foregroundStyle(Theme.white)
                Spacer()
                Text(strengthDescription).font(Theme.body(11)).foregroundStyle(Theme.smoke)
            }
            SegmentedPills(options: NightStrength.allCases, label: \.label, selection: $model.strength)
        }
        .emberCard()
    }

    private var strengthDescription: String {
        switch model.strength {
        case .gentle: return "A lighter touch"
        case .standard: return "Warm and dim"
        case .deep: return "For a dark room"
        }
    }
}

struct ClockField: View {
    var title: String
    var symbol: String
    @Binding var time: ClockTime

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(Theme.body(12)).foregroundStyle(Theme.ash)
            DatePicker(title, selection: date, displayedComponents: .hourAndMinute)
                .labelsHidden().datePickerStyle(.field).controlSize(.regular)
                .accessibilityLabel(title)
                .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var date: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date() },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                time = ClockTime(hour: c.hour ?? 0, minute: c.minute ?? 0)
            }
        )
    }
}
