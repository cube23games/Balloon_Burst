# TJ-45B — Quality-first glow A/B experiment

**The original Gaussian blur, particle effects, sound quality and every gameplay
rule are preserved.** The alternative is for internal QA ONLY; it is not a
production optimization. Do not reduce sound quality or particle counts again.

Two variants are built from the SAME commit, signed with the SAME certificate
and given the SAME versionCode. The ordinary internal QA artifact remains
`balloon-burst-internal-qa-apk` (originalBlur), and the additional QA artifact
is `balloon-burst-internal-qa-glow-experiment-apk` (gradientExperiment).
Only `ENABLE_QA_AUTOTAP=true` AND `TJ45B_GLOW_GRADIENT=true` activates the
alternative; all public release builds and ordinary QA builds use original blur.

## Device test and release gate

Only install after full signed CI GREEN. Install each variant OVER the existing
game; never uninstall, clear storage or disturb the TJ-44H checkpoint.
Confirm World 1 **24/24 stars** and saved coin bank each time.
Verify exported `qaGlowRenderer` is the expected variant.

With sound ON, compare fresh Level 8, warm Level 8 and 120s+ Endless Arcade.
Repeat each condition three times when practical and alternate variant order.
Export separate detailed reports. Compare normalized hitches/min, UI/raster
over-budget percentage, average and worst raster time, and player-perceived
smoothness. The 350ms warm ticker gap requires independent scheduling/lifecycle
investigation; it is not explained by a 24.5ms maximum raster frame.

Capture side-by-side screenshot references at streak 0, 10, 20, 30 and 100+.
Inspect halo softness, glow radius, color, brightness and compositing.
**Any visible loss is a rejection** regardless of speed. The gradient is an
approximation, not an established pixel-perfect match. Require a measurable
repeatable performance gain AND explicit owner visual acceptance before even
considering its promotion. No merge, mirror sync or tag without approval.

## Glow V2 refinement — owner direction: Aura, not fog

The owner initially preferred the energy of experimental V1 but found some
halos excessively diffuse, obscuring balloon definition like glowing fog.
V1 is not visually accepted for production. V2 tries a **tighter halo**:
the outer radius contracts from V1's `glowRadius + 2.2*sigma` to
`glowRadius + 1.35*sigma`; color holds nearer the balloon and falls off
faster beyond its outline. It is NOT guaranteed to be visually superior
or faster. Only owner-controlled install-over device QA can establish that.

The fourth, separately labeled APK is
`balloon-burst-internal-qa-tight-aura-v2-apk` with report
`qaGlowRenderer: tightAuraV2`, enabled by both
`ENABLE_QA_AUTOTAP=true` and `TJ45B_GLOW_AURA_V2=true`.
The original and V1 artifacts retain their previous flags and behavior,
all built from one commit under the same signing key and versionCode.

For visual acceptance, compare original / V1 / V2 under similar world,
balloon color and streak (10, 20, 30, 100+), paying particular attention
to clear balloon edges against the sky. Then compare long-run Endless
raster-over-budget rate on alternating QA variants. Reject V2 if it loses
visual quality or fails to deliver repeatable meaningful speed benefit.
No gameplay changes, sound-quality downgrades or particle removal.
