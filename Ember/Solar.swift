import Foundation

enum Solar {
    /// Glynn County, GA — used when location is off.
    static let fallbackLatitude = 31.1499
    static let fallbackLongitude = -81.4915

    struct Events: Equatable, Sendable {
        var sunrise: Date
        var sunset: Date
    }

    static func events(
        on date: Date,
        latitude: Double,
        longitude: Double,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> Events? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let start = cal.startOfDay(for: date)
        let offsetHours = Double(timeZone.secondsFromGMT(for: start)) / 3600
        let y = cal.component(.year, from: start)
        let m = cal.component(.month, from: start)
        let d = cal.component(.day, from: start)
        let dayOfYear = julianDay(year: y, month: m, day: d) - julianDay(year: y, month: 1, day: 1) + 1

        guard let sunriseH = localHours(kind: .sunrise, dayOfYear: dayOfYear, latitude: latitude, longitude: longitude, offsetHours: offsetHours),
              let sunsetH = localHours(kind: .sunset, dayOfYear: dayOfYear, latitude: latitude, longitude: longitude, offsetHours: offsetHours)
        else { return nil }

        return Events(
            sunrise: start.addingTimeInterval(sunriseH * 3600),
            sunset: start.addingTimeInterval(sunsetH * 3600)
        )
    }

    private enum Kind { case sunrise, sunset }

    /// NOAA / Williams sunrise-sunset algorithm. Civil zenith -0.833°.
    private static func localHours(
        kind: Kind,
        dayOfYear: Double,
        latitude: Double,
        longitude: Double,
        offsetHours: Double
    ) -> Double? {
        let zenith = 90.833
        let lat = latitude * .pi / 180
        let lngHour = longitude / 15.0
        let tApprox: Double
        switch kind {
        case .sunrise: tApprox = dayOfYear + ((6 - lngHour) / 24)
        case .sunset: tApprox = dayOfYear + ((18 - lngHour) / 24)
        }

        let mAnom = (0.9856 * tApprox) - 3.289
        var l = mAnom + (1.916 * sin(mAnom * .pi / 180)) + (0.020 * sin(2 * mAnom * .pi / 180)) + 282.634
        l = normalize(l, 360)

        var ra = atan(0.91764 * tan(l * .pi / 180)) * 180 / .pi
        ra = normalize(ra, 360)
        ra = (ra + (floor(l / 90) * 90 - floor(ra / 90) * 90)) / 15

        let sinDec = 0.39782 * sin(l * .pi / 180)
        let cosDec = cos(asin(sinDec))
        let cosH = (cos(zenith * .pi / 180) - (sinDec * sin(lat))) / (cosDec * cos(lat))
        if cosH > 1 || cosH < -1 { return nil }

        let h: Double
        switch kind {
        case .sunrise: h = (360 - acos(cosH) * 180 / .pi) / 15
        case .sunset: h = (acos(cosH) * 180 / .pi) / 15
        }

        let localT = h + ra - (0.06571 * tApprox) - 6.622
        let utc = localT - lngHour
        return normalize(utc + offsetHours, 24)
    }

    private static func julianDay(year: Int, month: Int, day: Int) -> Double {
        var y = year
        var m = month
        if m <= 2 {
            y -= 1
            m += 12
        }
        let a = floor(Double(y) / 100)
        let b = 2 - a + floor(a / 4)
        return floor(365.25 * Double(y + 4716)) + floor(30.6001 * Double(m + 1)) + Double(day) + b - 1524.5
    }

    private static func normalize(_ value: Double, _ max: Double) -> Double {
        var v = value.truncatingRemainder(dividingBy: max)
        if v < 0 { v += max }
        return v
    }
}
