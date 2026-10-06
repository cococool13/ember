# Circadian evidence and Ember's limits

Reviewed 2026-10-05 against primary publications and professional guidance. This memo evaluates the display schedule and public claims; it does not establish a clinical benefit for Ember.

## What the evidence supports

Brown et al. (2022) recommend, for healthy adults aged 18–55 with regular daytime schedules, at least **250 lx melanopic equivalent daylight illuminance (EDI)** at the eye during the day; at most **10 lx** starting at least three hours before bedtime; and at most **1 lx** in the sleep environment. Nighttime tasks requiring vision can use the 10 lx limit. Daylight is preferred when available, and visual safety still matters. These are consensus exposure targets, not prescribed display temperatures. [Brown et al., PLOS Biology](https://journals.plos.org/plosbiology/article?id=10.1371/journal.pbio.3001571)

CIE S 026 defines spectral metrics for light affecting retinal photoreceptors. CIE's 2024 position statement stresses that level and spectrum together, including all surrounding light sources, determine exposure; correlated color temperature alone cannot designate healthy or unhealthy light. [CIE S 026:2018](https://cie.co.at/publications/cie-system-metrology-optical-radiation-iprgc-influenced-responses-light-0), [CIE PS 001:2024](https://cie.co.at/publications/cie-position-statement-integrative-lighting-recommending-proper-light-proper-time-3rd)

A randomized trial of 167 adults aged 18–24 compared one hour of iPhone use before bed with Night Shift on, off, or no phone for seven nights. Across the full sample, Night Shift produced no attributable difference in sleep outcomes. This does not test Ember, but it rules out treating warm screen color alone as an established sleep intervention. [Duraccio et al., Sleep Health (2021), abstract](https://pubmed.ncbi.nlm.nih.gov/33867308/)

AAO guidance separates screen discomfort from blue-light damage claims. It reports no meaningful link between ordinary screen blue light and retinal damage; reduced blinking and prolonged close work contribute to discomfort. Take regular breaks, blink, reduce glare, and adjust brightness and contrast for comfortable reading. Its practical advice includes the 20-20-20 rule. A tint is not demonstrated eye-disease protection. [AAO, Digital Devices and Your Eyes](https://aao.org/eye-health/tips-prevention/blue-light-digital-eye-strain), [AAO, Should You Be Worried About Blue Light?](https://www.aao.org/eye-health/tips-prevention/should-you-be-worried-about-blue-light)

## What this means for Ember

The following are implementation conclusions, not claims measured in a trial:

- Keep the bedtime-based evening schedule. Starting three hours before bed follows the direction of the consensus, but reaching a warm preset gradually over that interval does **not** demonstrate meeting the evening exposure target throughout it.
- Keep Gentle (2200K/0.68), Standard (1800K/0.55), and Deep (1600K/0.45) as comfort choices. No cited study validates these exact combinations, the 6800K morning peak, the 25-minute morning ramp, the 40-minute evening ramp, or the extra blue-channel gain. Do not call Standard the Brown target or change defaults on that premise.
- The app modifies gamma tables; `dim` is a software gain, not measured luminance, hardware brightness, or light at the eye. Screen content, display spectrum/calibration, hardware brightness, distance, and room lighting vary. Kelvin labels are approximate tint settings, especially after an extra blue-primary adjustment.
- The original `Schedule.melanopicDER(kelvin:)` was an unvalidated linear lookup. Its result multiplied by a gamma gain could not establish a melanopic EDI or a percentage reduction in blue light. This lookup and its derived percentage have been removed from the display readings. Use observable labels such as “Full color”, “Cooler light”, or “Warm and dim”.
- Returning to the saved daytime display profile preserves intended color behavior. Do not describe it as providing adequate daytime circadian exposure. Recommend daytime daylight and dimmer room lighting in the evening; avoid an absolute claim that no display can reach a specified illuminance without measurement.

## Concrete copy corrections

| Existing claim | Recommended replacement |
| --- | --- |
| “Blue light −87%” | “Warm and dim” |
| “Standard is the Brown 2022 target” | “Standard is warm and dim; choose Gentle for easier reading or Deep for a darker room.” |
| “Blue light eases off so melatonin can rise” | “The screen grows warmer and dimmer before bed.” |
| “Low blue light so sleep comes easier” | “Warm and dim until your next wake time.” |
| “Built on CIE S 026” | “Evening timing informed by light-exposure research.” |
| “Will this fix my sleep?” implied benefit | “Ember does not measure light reaching your eyes or guarantee better sleep. Room lighting, daylight, screen brightness, and time before bed still matter.” |

Avoid clinical guarantees, eye-damage protection, quantified biological exposure, and unmeasured comparisons with f.lux or Night Shift. Refer to reciprocal-temperature blending as an implementation that makes transitions gradual, rather than “the scale the eye uses.”

## Validation boundary

Reviewed `Ember/Schedule.swift`, `Ember/DisplayEngine.swift`, related panel/tooltip references, schedule tests, and `site/index.html`. No optical measurements, human sleep trials, or medical outcome tests were performed. Optical percentage claims would require representative display spectral measurements under defined content, brightness, viewing geometry, and ambient lighting, using CIE S 026 calculations.
