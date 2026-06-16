import Foundation

extension Date {
    /// Formats a date the way notes display it: time if today, "Yesterday", weekday name,
    /// abbreviated date, or full date depending on how far back it is.
    var formattedRelative: String {
        let cal = Calendar.current
        let now = Date.now
        if cal.isDateInToday(self) {
            return formatted(date: .omitted, time: .shortened)
        } else if cal.isDateInYesterday(self) {
            return String(localized: "date.yesterday")
        } else if cal.isDate(self, equalTo: now, toGranularity: .weekOfYear) {
            return formatted(.dateTime.weekday(.wide))
        } else if cal.isDate(self, equalTo: now, toGranularity: .year) {
            return formatted(.dateTime.day().month(.abbreviated))
        } else {
            return formatted(.dateTime.day().month(.abbreviated).year())
        }
    }
}
