# Ember site: cinematic redesign (full creative control)

Redesign the static marketing site in `site/` (plain HTML/CSS/JS, served by Cloudflare Workers via wrangler; no build step) into a cinematic, film-like experience. Read AGENTS.md, README.md, docs/website-design.md, and the current site first.

Art direction: "The last light." The page plays like one evening: dusk -> night -> dawn. Near-black base #09090B, ember-rust warm light, big high-contrast serif headlines (Newsreader is already loaded), restrained small sans body, generous negative space.

Assets in `site/assets/cinematic/`: hero-dusk.jpg (+ hero-dusk-1200.jpg for small screens), night.jpg, dawn.jpg (2400x1350, dark top = room for text). No video exists; give the hero stills life with CSS/JS motion (slow Ken Burns drift, scroll parallax, maybe the glow brightening/warming with scroll). Rules: no overlays over the imagery; fade imagery into the solid bg with gradients; borderless asymmetric sections; dawn image as CTA/footer background.

Ideas (optional): scroll-tied color temperature shift across the page, keep and restyle the existing interactive Mac preview as a centerpiece, sticky hero that releases after section two.

Guardrails:
- Keep all existing functionality working: the interactive preview (site.js), nav/anchors, Stripe checkout link (licensing Worker /buy/ember, no tracking script), downloads, privacy.html, 404.html, _headers, JSON-LD, meta tags.
- Keep content truthful: same claims, price, requirements, FAQ, science caveats. No invented testimonials, stats, reviews, or features.
- Responsive (mobile-first check at 390px), accessible (contrast, focus, alt, skip link, prefers-reduced-motion disables motion), fast (no heavy libs; no frameworks; lazy-load non-hero images).
- Do not deploy, do not push, do not touch the native app, do not run git commands that discard work. Do not edit files outside site/ except a short note in docs/website-design.md.
