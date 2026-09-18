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
        let wakeM = wrap(Double(wake.minutes))
        let bedM = wrap(Double(bed.minutes))
        let awake = minutesBetween(wakeM, bedM)
        let elapsed = minutesBetween(wakeM, nowM)

        if awake <= Double(minimumMorningRamp + minimumEveningRamp) || elapsed >= awake {
            return LightState(
                kelvin: nightKelvin,
                dim: nightDim,
                phase: .night,
                nextPhase: .morning,
                minutesUntilNext: remainingMinutes(minutesBetween(nowM, wakeM)),
                dayProgress: 1
            )
        }

        let sunriseElapsed = sunrise.map { minutesBetween(wakeM, wrap(minutes(in: $0, calendar: calendar))) }
        let sunsetElapsed = sunset.map { minutesBetween(wakeM, wrap(minutes(in: $0, calendar: calendar))) }

        let morningFromSun = sunriseElapsed.flatMap { $0 <= 6 * 60 ? $0 : nil }
        let morningEnd = max(Double(minimumMorningRamp), morningFromSun ?? 0)

        var eveningStart = max(0, awake - Double(eveningLeadMinutes))
        // Sunset during the wake window, if earlier than bedtime−3h. Do not
        // require elapsed > awake/2: that skipped legitimate early winter sunsets.
        if let sunsetElapsed, sunsetElapsed < eveningStart {
            eveningStart = sunsetElapsed
        }
        eveningStart = min(eveningStart, awake - Double(minimumEveningRamp))
        eveningStart = max(eveningStart, morningEnd)

        if elapsed < morningEnd {
            let t = smoothstep(elapsed / max(morningEnd, 1))
            return LightState(
                kelvin: lerp(nightKelvin, morningKelvin, t),
                dim: lerp(nightDim, dayDim, t),
                phase: .morning,
                nextPhase: .day,
                minutesUntilNext: remainingMinutes(morningEnd - elapsed),
                dayProgress: elapsed / awake
            )
        }
        if elapsed >= eveningStart {
            let span = max(awake - eveningStart, 1)
            let into = elapsed - eveningStart
            let cut = min(Double(eveningCutMinutes), max(span / 3, 1))
            let kelvin: Double
            let dim: Double
            if into < cut {
                let t = smoothstep(into / cut)
                kelvin = lerp(dayKelvin, duskKelvin, t)
                dim = lerp(dayDim, duskDim, t)
            } else {
                let t = smoothstep((into - cut) / max(span - cut, 1))
                kelvin = lerp(duskKelvin, nightKelvin, t)
                dim = lerp(duskDim, nightDim, t)
            }
            return LightState(
                kelvin: kelvin,
                dim: dim,
                phase: .evening,
                nextPhase: .night,
                minutesUntilNext: remainingMinutes(awake - elapsed),
                dayProgress: elapsed / awake
            )
        }
        return LightState(
            kelvin: dayKelvin,
            dim: dayDim,
            phase: .day,
            nextPhase: .evening,
            minutesUntilNext: remainingMinutes(eveningStart - elapsed),
            dayProgress: elapsed / awake
        )
    }

    static func melanopicDER(kelvin: Double) -> Double {
        let k = min(max(kelvin, 1000), 8000)
        return min(1.0, max(0.16, 0.000145 * k - 0.05))
    }

    static func minutes(in date: Date, calendar: Calendar) -> Double {
        let c = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        return Double((c.hour ?? 0) * 60 + (c.minute ?? 0))
            + Double(c.second ?? 0) / 60
            + Double(c.nanosecond ?? 0) / 60_000_000_000
    }

    static func wrap(_ minutes: Double) -> Double {
        var v = minutes.truncatingRemainder(dividingBy: 1440)
        if v < 0 { v += 1440 }
        return v
    }

    static func minutesBetween(_ start: Double, _ end: Double) -> Double {
        wrap(end - start)
    }

    static func remainingMinutes(_ value: Double) -> Int {
        Int(ceil(max(0, value) - 1e-9))
    }

    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    static func smoothstep(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        return x * x * (3 - 2 * x)
    }
}
