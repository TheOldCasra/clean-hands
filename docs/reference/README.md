# Visual references for the UV glow look

Provided by the project owner on 2026-11-03. Used for constitution Quality Gate 3 (visual QA) and
to set the defaults in `specs/001-uv-germ-visualization/contracts/look-config.md`.

| File | Shows |
|---|---|
| `ref-01-open-palm.jpg` | One open palm, fingers spread, fluorescent tracer under UV |
| `ref-02-cupped-hands.jpg` | Two cupped hands, palms up, same effect |

**Licensing**: both images are watermarked previews from a stock photo library. They are an
internal style reference only: do not ship them in the app, put them in study materials, or
publish them. They are git-ignored so they never reach a public repository by accident.

## What the references show (measured 2026-11-03)

| Property | ref-01 | ref-02 | Implication for the look |
|---|---|---|---|
| Background | pure black, 73% of frame | pure black with circular falloff, 74% | Everything except the lit hands goes to black |
| Skin | blue-violet, hue ≈250°, value ≈0.23 | violet, hue ≈251°, sat 0.40, value ≈0.24 | Dark violet skin, creases and ridges still visible |
| Glow color (median / highlights) | `#5a7c55` / `#8dce7b`, hue ≈109° | `#508661` / `#80df90`, hue ≈138° | Lime-to-mint green, not cyan, not yellow |
| Glow coverage of visible hand | 17% | 20% | Target 15–25% at the start of the reveal |
| Glow by height (ref-01, top→bottom fifths) | 61%, 27%, 13%, 8%, 10% | n/a | Fingertips dominate (~6× the palm); palm centre mostly clean |
| Halo | almost none | slight | Very subtle bloom |
| Texture | creases cut through the glow; powdery edges | glow settles along creases | Glow inherits the real skin texture; grainy, not smooth blobs |
