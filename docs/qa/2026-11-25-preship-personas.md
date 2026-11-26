SHIP (no blockers)

# Pre-ship four-persona review: Coal site, 2026-11-25

Artifact: `site/index.html`, rendered at http://localhost:5182/. Reader: a Mac user who works into the evening and wants the screen warmer and dimmer after dark. Success action: Buy Ember for $9 (or download, then activate). The review read the copy only. Nothing was edited.

| # | Severity | Persona(s) | Finding | Change (where + what) | Why | Evidence |
|---|---|---|---|---|---|---|
| 1 | Major | Customer, Conversion | Download for Mac sits beside Buy with no hint that the app needs a license to warm anything. A visitor can read it as a free download. | `site/index.html:134-137`: say in the facts line or the lede that the download needs a license to turn on | Without a license, the app stays in true color and shows Activate (AGENTS.md: Licensing). A surprise after install costs trust. | `index.html:132-137` |
| 2 | Major | Competitor, Customer | Nothing says why to pay $9 when Night Shift and f.lux are free. Ember's real differences are on the page but scattered: it dims as well as warms, follows a curve to bedtime, lists true color apps, and has a 24-hour preview dial. | Curve lede or hero note: name dimming plus warmth, since Night Shift only warms | The obvious attack from a rival is "Night Shift does this for free". | page copy, the "Stays out of your way" ledger |
| 3 | Major | Skeptic | No refund policy is stated. Terms only say to contact support about refunds. | `terms.html:27` and near the $9 button: state the refund rule, or say plainly that refunds go through support | Buyers look for refund terms next to a price. | `terms.html:22-27` |
| 4 | Nit | Skeptic | Support is a personal Gmail address. | Footer. Kept on purpose: it is the support email this release had to keep. | Some buyers read a personal address as a hobby project. | footer |
| 5 | Nit | Customer | The curve section uses kelvin ("2700 K") without saying what it means. | Curve lede: "about 2700 K (candlelight-warm)". Only if Neon agrees and it stays factual. | Kelvin is jargon to most buyers. The swatches help. | `index.html` curve lede |

Passes:
- Customer: the promise matches the app. Curve, strengths, Pause, true color apps and f.lux/Night Shift handling all match AGENTS.md.
- Skeptic: no invented numbers, reviews or testimonials. The sleep disclaimer is next to the price and in the FAQ. Privacy and terms are linked. One price ($9) everywhere, and checkout shows $9.00.
- Conversion: the buy link is in the nav from the first screen and in the pricing section. Install steps appear after Download.

## Top 5 changes

1. State that a license is needed to turn Ember on, next to Download (`index.html` facts line).
2. Name dimming plus warmth as the difference from Night Shift (hero note or curve lede).
3. State the refund rule near the price and in the terms.
4. Gloss kelvin once in the curve lede.
5. Consider a support address on a project domain when one exists.

None of these is a blocker, and items 1 to 3 are also true of the live 0.7.0 site. They are copy changes for Neon in a later pass.

## Not run

Real-buyer interviews, and a comparison against competitors' live pricing pages.
