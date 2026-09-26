import Foundation

struct ClockTime: Equatable, Sendable {
    var hour: Int
    var minute: Int

    var minutes: Int { hour * 60 + minute }

    static func from(minutes: Int) -> ClockTime {
        let wrapped = ((minutes % 1440) + 1440) % 1440
        return ClockTime(hour: wrapped / 60, minute: wrapped % 60)
    }

    static func from(fractionalMinutes: Double) -> ClockTime {
        from(minutes: Int(fractionalMinutes.rounded()))
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
        case .morning: return "Cool, bright light tells your body clock the day has started."
        case .day: return "Full color and full brightness. The screen stays out of your way."
        case .evening: return "Blue light eases off so melatonin can rise before bed."
        case .night: return "Warm and dim. Low blue light so sleep comes easier."
        }
    }
}

/// How far the screen goes at night. Standard is the Brown 2022 target Ember
/// shipped with; Gentle keeps text easier to read, Deep is for dark rooms.
enum NightStrength: String, CaseIterable, Sendable {
    case gentle
    case standard
    case deep

    var label: String {
        switch self {
        case .gentle: return "Gentle"
        case .standard: return "Standard"
        case .deep: return "Deep"
        }
    }

    var caption: String {
        switch self {
        case .gentle: return "Warm, still easy to read"
        case .standard: return "Warm and dim"
        case .deep: return "Very warm, very dim"
        }
    }

    var nightKelvin: Double {
        switch self {
        case .gentle: return 2200
        case .standard: return 1800
        case .deep: return 1600
        }
    }

    var nightDim: Double {
        switch self {
        case .gentle: return 0.68
        case .standard: return 0.55
        case .deep: return 0.45
        }
    }
}

/// The shape of one waking day, in minutes since wake. The view draws this;
/// `Schedule.state` samples it.
struct DayPlan: Equatable, Sendable {
    var wake: ClockTime
    var bed: ClockTime
    var awakeMinutes: Double
    var morningEndMinutes: Double
    var settleEndMinutes: Double
    var eveningStartMinutes: Double
    var duskEndMinutes: Double
    var tooShort: Bool

    var morningEnd: ClockTime { clock(at: morningEndMinutes) }
    var eveningStart: ClockTime { clock(at: eveningStartMinutes) }

    var morningFraction: Double { fraction(morningEndMinutes) }
    var eveningFraction: Double { fraction(eveningStartMinutes) }
    var duskFraction: Double { fraction(duskEndMinutes) }

    func fraction(_ minutes: Double) -> Double {
        guard awakeMinutes > 0 else { return 0 }
        return min(1, max(0, minutes / awakeMinutes))
    }

    private func clock(at minutes: Double) -> ClockTime {
        ClockTime.from(fractionalMinutes: Double(wake.minutes) + minutes)
    }
}

struct LightState: Equatable, Sendable {
    var kelvin: Double
    var dim: Double
    var phase: Phase
    var nextPhase: Phase
    var minutesUntilNext: Int
    var dayProgress: Double
    var plan: DayPlan

    /// Share of the daytime melanopic signal the screen still sends, 0...1.
    var sleepSignal: Double {
        Schedule.melanopicDER(kelvin: kelvin) * dim / (Schedule.melanopicDER(kelvin: Schedule.dayKelvin) * Schedule.dayDim)
    }

    /// Plain-language reading of `sleepSignal`.
    var signalLabel: String {
        if sleepSignal >= 0.98 { return "Full color" }
        return "Blue light −\(Int(((1 - sleepSignal) * 100).rounded()))%"
    }
}

enum Schedule {
    static let morningKelvin = 6800.0
    static let dayKelvin = 6500.0
    static let duskKelvin = 2700.0
    static let nightKelvin = NightStrength.standard.nightKelvin
    static let dayDim = 1.0
    static let duskDim = 0.82
    static let nightDim = NightStrength.standard.nightDim
    static let eveningLeadMinutes = 180
    static let minimumMorningRamp = 25
    static let morningSettleMinutes = 60
    static let eveningCutMinutes = 40
    static let minimumEveningRamp = 90

    static func plan(
        wake: ClockTime,
        bed: ClockTime,
        sunrise: Date?,
        sunset: Date?,
        calendar: Calendar = .current
    ) -> DayPlan {
        let wakeM = wrap(Double(wake.minutes))
        let bedM = wrap(Double(bed.minutes))
        let awake = minutesBetween(wakeM, bedM)
        let tooShort = awake <= Double(minimumMorningRamp + minimumEveningRamp)

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

        let settleEnd = min(morningEnd + Double(morningSettleMinutes), eveningStart)
        let span = max(awake - eveningStart, 1)
        let cut = min(Double(eveningCutMinutes), max(span / 3, 1))

        return DayPlan(
            wake: wake,
            bed: bed,
            awakeMinutes: awake,
            morningEndMinutes: morningEnd,
            settleEndMinutes: settleEnd,
            eveningStartMinutes: eveningStart,
            duskEndMinutes: eveningStart + cut,
            tooShort: tooShort
        )
    }

    /// Morning reaches cool daylight in 25 minutes, then settles to 6500K over
    /// the next hour. Evening drops the melanopic signal fast in the first 40
    /// minutes, then slides to the night target by bedtime. Every ramp blends
    /// in mired (reciprocal kelvin) with a smootherstep ease, so the change
    /// looks even to the eye instead of hanging at 6500K and snapping at the end.
    static func state(
        now: Date,
        calendar: Calendar = .current,
        wake: ClockTime,
        bed: ClockTime,
        sunrise: Date?,
        sunset: Date?,
        strength: NightStrength = .standard
    ) -> LightState {
        let plan = plan(wake: wake, bed: bed, sunrise: sunrise, sunset: sunset, calendar: calendar)
        let nowM = wrap(minutes(in: now, calendar: calendar))
        let elapsed = minutesBetween(wrap(Double(wake.minutes)), nowM)
        return state(elapsed: elapsed, plan: plan, strength: strength)
    }

    /// The light at `elapsed` minutes after wake on `plan`. Anything at or past
    /// bedtime, up to the next wake, is night.
    static func state(elapsed: Double, plan: DayPlan, strength: NightStrength = .standard) -> LightState {
        let elapsed = wrap(elapsed)
        let awake = plan.awakeMinutes
        let nightK = strength.nightKelvin
        let nightD = strength.nightDim

        if plan.tooShort || elapsed >= awake {
            return LightState(
                kelvin: nightK,
                dim: nightD,
                phase: .night,
                nextPhase: .morning,
                minutesUntilNext: remainingMinutes(wrap(-elapsed)),
                dayProgress: 1,
                plan: plan
            )
        }

        let morningEnd = plan.morningEndMinutes
        let eveningStart = plan.eveningStartMinutes

        if elapsed < morningEnd {
            let t = ease(elapsed / max(morningEnd, 1))
            return LightState(
                kelvin: blendKelvin(nightK, morningKelvin, t),
                dim: lerp(nightD, dayDim, t),
                phase: .morning,
                nextPhase: .day,
                minutesUntilNext: remainingMinutes(morningEnd - elapsed),
                dayProgress: elapsed / awake,
                plan: plan
            )
        }
        if elapsed >= eveningStart {
            let span = max(awake - eveningStart, 1)
            let into = elapsed - eveningStart
            let cut = plan.duskEndMinutes - eveningStart
            let kelvin: Double
            let dim: Double
            if into < cut {
                let t = ease(into / cut)
                kelvin = blendKelvin(dayKelvin, duskKelvin, t)
                dim = lerp(dayDim, duskDim, t)
            } else {
                let t = ease((into - cut) / max(span - cut, 1))
                kelvin = blendKelvin(duskKelvin, nightK, t)
                dim = lerp(duskDim, nightD, t)
            }
            return LightState(
                kelvin: kelvin,
                dim: dim,
                phase: .evening,
                nextPhase: .night,
                minutesUntilNext: remainingMinutes(awake - elapsed),
                dayProgress: elapsed / awake,
                plan: plan
            )
        }
        let settleSpan = plan.settleEndMinutes - morningEnd
        let settle = settleSpan > 0 ? ease((elapsed - morningEnd) / settleSpan) : 1
        return LightState(
            kelvin: blendKelvin(morningKelvin, dayKelvin, settle),
            dim: dayDim,
            phase: .day,
            nextPhase: .evening,
            minutesUntilNext: remainingMinutes(eveningStart - elapsed),
            dayProgress: elapsed / awake,
            plan: plan
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

    /// Correlated color temperature is perceptually even in mired (1e6 / K),
    /// not in kelvin: 6500→5000K is a small step, 2700→1800K a large one.
    static func blendKelvin(_ a: Double, _ b: Double, _ t: Double) -> Double {
        let mired = lerp(1_000_000 / a, 1_000_000 / b, min(1, max(0, t)))
        return 1_000_000 / mired
    }

    /// Perlin smootherstep: zero first and second derivative at both ends, so a
    /// ramp neither starts with a kick nor lands with a bump.
    static func ease(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        return x * x * x * (x * (x * 6 - 15) + 10)
    }
}
