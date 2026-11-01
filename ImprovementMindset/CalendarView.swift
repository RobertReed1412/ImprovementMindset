import SwiftUI
import SwiftData

struct CalendarView: View {
    var body: some View { NavigationStack { CalendarContent() } }
}

struct CalendarContent: View {
    @Environment(\.modelContext) private var context
    @Query private var events: [CalendarEvent]

    @State private var monthAnchor = Date()
    @State private var selectedDay = Date()
    @State private var showingAdd = false

    private let cal = Calendar.current

    var body: some View {
            ScrollView {
                monthHeader
                weekdayRow
                monthGrid
                dayEvents
            }
            .scrollContentBackground(.hidden)
            .nightBackground()
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddEventView(defaultDate: selectedDay)
            }
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").foregroundStyle(Theme.Palette.gold)
            }
            Spacer()
            Text(monthTitle)
                .font(Theme.display(24, weight: .bold))
                .foregroundStyle(Theme.Palette.bone)
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").foregroundStyle(Theme.Palette.gold)
            }
        }
        .padding(.horizontal).padding(.top, 8)
    }

    private var weekdayRow: some View {
        HStack {
            ForEach(["S","M","T","W","T","F","S"], id: \.self) { d in
                Text(d).font(.caption2).foregroundStyle(Theme.Palette.boneDim)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal).padding(.top, 10)
    }

    private var monthGrid: some View {
        let days = monthDays()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 10).padding(.top, 6)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
        let isToday = cal.isDateInToday(day)
        let dayEvents = events.filter { $0.occurs(on: day) }
        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 15))
                    .foregroundStyle(isSelected ? Theme.Palette.night : Theme.Palette.bone)
                HStack(spacing: 2) {
                    ForEach(dayEvents.prefix(3)) { ev in
                        SwiftUI.Circle().fill(Color(hex: ev.colorHex)).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.Palette.gold : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday && !isSelected ? Theme.Palette.gold : .clear, lineWidth: 1))
        }
    }

    private var dayEvents: some View {
        let dayList = events
            .filter { $0.occurs(on: selectedDay) }
            .sorted { $0.startDate.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400)
                    < $1.startDate.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400) }
        return VStack(alignment: .leading, spacing: 10) {
            Text(selectedDayTitle)
                .font(Theme.display(18, weight: .semibold))
                .foregroundStyle(Theme.Palette.goldBright)
                .padding(.top, 18)

            if dayList.isEmpty {
                Text("No events this day.")
                    .font(.subheadline).foregroundStyle(Theme.Palette.boneDim)
                    .padding(.vertical, 8)
            }

            ForEach(dayList) { ev in
                EventRow(event: ev) { delete(ev) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.bottom, 30)
    }

    private var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "LLLL yyyy"
        return f.string(from: monthAnchor)
    }
    private var selectedDayTitle: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return f.string(from: selectedDay)
    }

    private func shiftMonth(_ by: Int) {
        if let d = cal.date(byAdding: .month, value: by, to: monthAnchor) {
            monthAnchor = d
        }
    }

    private func monthDays() -> [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let first = interval.start
        let weekday = cal.component(.weekday, from: first) - 1
        let daysInMonth = cal.range(of: .day, in: .month, for: monthAnchor)?.count ?? 30
        var result: [Date?] = Array(repeating: nil, count: weekday)
        for d in 0..<daysInMonth {
            if let date = cal.date(byAdding: .day, value: d, to: first) {
                result.append(date)
            }
        }
        return result
    }

    private func delete(_ ev: CalendarEvent) {
        context.delete(ev)
        try? context.save()
    }
}

struct EventRow: View {
    let event: CalendarEvent
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: event.colorHex))
                .frame(width: 4, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.subheadline).foregroundStyle(Theme.Palette.bone)
                HStack(spacing: 6) {
                    Text(event.timeLabel)
                    if event.recurrence != .none {
                        Image(systemName: "repeat").font(.caption2)
                        Text(event.recurrence.label)
                    }
                }
                .font(.caption2).foregroundStyle(Theme.Palette.boneDim)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.nightRaised.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Palette.goldDim.opacity(0.4), lineWidth: 0.5))
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
