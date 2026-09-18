import Foundation

struct ClockTime: Equatable, Sendable {
    var hour: Int
    var minute: Int

    var minutes: Int { hour * 60 + minute }

    static func from(minutes: Int) -> ClockTime {
        let wrapped = ((minutes % 1440) + 1440) % 1440
        return ClockTime(hour: wrapped / 60, minute: wrapped % 60)
    }

    func stepped(by delta: Int) -> ClockTime {
        ClockTime.from(minutes: minutes + delta)
    }

    var label: String {
        let h24 = hour
        let suffix = h24 >= 12 ? "PM" : "AM"
        let h12 = h24 % 12 == 0 ? 12 : h24 % 12
        return String(format: "%d:%02d %@", h12, minute, suffix)
    }
}

enum Phase: String, Equatable, Sendable, CaseIterable {
    case morning
    case day
    case evening
    case night

    var index: String {
        switch self {
        case .morning: return "01"
        case .day: return "02"
        case .evening: return "03"
        case .night: return "04"
        }
    }

    var shortLabel: String {
        switch self {
        case .morning: return "Dawn"
        case .day: return "Day"
        case .evening: return "Dusk"
        case .night: return "Night"
        }
    }

    var title: String {
        switch self {
        case .morning: return "Morning light"
        case .day: return "Daylight"
        case .evening: return "Winding down"
        case .night: return "Night light"
        }
    }

    var summary: String {
        switch self {
        case .morning: return "Cool, bright light to help you wake up."
        case .day: return "Full color. The screen stays out of your way."
        case .evening: return "Blue light drops so melatonin can start."
        case .night: return "Warm and dim until you sleep."
        }
    }
}

struct LightState: Equatable, Sendable {
    var kelvin: Double
    var dim: Double
    var phase: Phase
    var nextPhase: Phase
    var minutesUntilNext: Int
    var dayProgress: Double

    var melanopicDER: Double {
        Schedule.melanopicDER(kelvin: kelvin)
    }

    var nextCaption: String {
        let h = minutesUntilNext / 60
        let m = minutesUntilNext % 60
        if minutesUntilNext <= 0 { return phase.title }
        if h > 0 { return "\(nextPhase.shortLabel) in \(h)h \(m)m" }
        return "\(nextPhase.shortLabel) in \(m)m"
    }
}

enum Schedule {
    static let morningKelvin = 6800.0
    static let dayKelvin = 6500.0
    static let duskKelvin = 2700.0
    static let nightKelvin = 1800.0
    static let dayDim = 1.0
    static let duskDim = 0.82
    static let nightDim = 0.55
    static let eveningLeadMinutes = 180
    static let minimumMorningRamp = 25
    static let eveningCutMinutes = 40
    static let minimumEveningRamp = 90

    /// Fast melanopic drop in the first 40 minutes of evening, then a slow
    /// slide to night. Morning reaches cool daylight in 25 minutes.
    static func state(
        now: Date,
        calendar: Calendar = .current,
        wake: ClockTime,
        bed: ClockTime,
        sunrise: Date?,
        sunset: Date?
    ) -> LightState {
        let nowM = wrap(minutes(in: now, calendar: calendar))
        let wakeM = wrap(wake.minutes)
        let bedM = wrap(bed.minutes)
        let awake = minutesBetween(wakeM, bedM)
        let elapsed = minutesBetween(wakeM, nowM)

        if awake <= minimumMorningRamp + minimumEveningRamp || elapsed >= awake {
            let untilWake = minutesBetween(nowM, wakeM)
            return LightState(
                kelvin: nightKelvin,
                dim: nightDim,
                phase: .night,
                nextPhase: .morning,
                minutesUntilNext: untilWake,
                dayProgress: 1
            )
        }

        let sunriseElapsed = sunrise.map { minutesBetween(wakeM, wrap(minutes(in: $0, calendar: calendar))) }
        let sunsetElapsed = sunset.map { minutesBetween(wakeM, wrap(minutes(in: $0, calendar: calendar))) }

        let morningFromSun = sunriseElapsed.flatMap { $0 <= 6 * 60 ? $0 : nil }
        let morningEnd = max(minimumMorningRamp, morningFromSun ?? 0)

        var eveningStart = max(0, awake - eveningLeadMinutes)
        if let sunsetElapsed, sunsetElapsed < eveningStart, sunsetElapsed > awake / 2 {
            eveningStart = sunsetElapsed
        }
        eveningStart = min(eveningStart, awake - minimumEveningRamp)
        eveningStart = max(eveningStart, morningEnd)

        if elapsed < morningEnd {
            let t = smoothstep(Double(elapsed) / Double(max(morningEnd, 1)))
            return LightState(
                kelvin: lerp(nightKelvin, morningKelvin, t),
                dim: lerp(nightDim, dayDim, t),
                phase: .morning,
                nextPhase: .day,
                minutesUntilNext: morningEnd - elapsed,
                dayProgress: Double(elapsed) / Double(awake)
            )
        }
        if elapsed >= eveningStart {
            let span = max(awake - eveningStart, 1)
            let into = elapsed - eveningStart
            let cut = min(eveningCutMinutes, max(span / 3, 1))
            let kelvin: Double
            let dim: Double
            if into < cut {
                let t = smoothstep(Double(into) / Double(cut))
                kelvin = lerp(dayKelvin, duskKelvin, t)
                dim = lerp(dayDim, duskDim, t)
            } else {
                let t = smoothstep(Double(into - cut) / Double(max(span - cut, 1)))
                kelvin = lerp(duskKelvin, nightKelvin, t)
                dim = lerp(duskDim, nightDim, t)
            }
            return LightState(
                kelvin: kelvin,
                dim: dim,
                phase: .evening,
                nextPhase: .night,
                minutesUntilNext: awake - elapsed,
                dayProgress: Double(elapsed) / Double(awake)
            )
        }
        return LightState(
            kelvin: dayKelvin,
            dim: dayDim,
            phase: .day,
            nextPhase: .evening,
            minutesUntilNext: eveningStart - elapsed,
            dayProgress: Double(elapsed) / Double(awake)
        )
    }

    static func melanopicDER(kelvin: Double) -> Double {
        let k = min(max(kelvin, 1000), 8000)
        return min(1.0, max(0.16, 0.000145 * k - 0.05))
    }

    static func minutes(in date: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func wrap(_ minutes: Int) -> Int {
        ((minutes % 1440) + 1440) % 1440
    }

    static func minutesBetween(_ start: Int, _ end: Int) -> Int {
        wrap(end - start)
    }

    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    static func smoothstep(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        return x * x * (3 - 2 * x)
    }
}
