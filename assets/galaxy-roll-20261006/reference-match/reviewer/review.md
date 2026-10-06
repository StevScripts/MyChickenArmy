# Independent motion review

Reference: `/Users/stevin/Desktop/Screen Recording 2026-10-06 at 1.40.58 AM.mov`.

Decoded with ffmpeg from 11.8 seconds, sampled 30fps, scaled to 864×559. Reported times are sample positions with ~one-frame uncertainty; original variable-rate capture and resampling limit exact onset estimates. OpenCV seeking by milliseconds was found unreliable and was not used for measurements. Root's sequential native-PTS measurements should take precedence if timelines differ.

## Geometry (measured)

- Top recording bar is 16 pixels, so game content is approximately 864×543.
- Resting outer panel spans x87–777, y248–327: approximately 80% of viewport width, 15% of viewport height, centered at viewport (0.5,0.5).
- Panel has a thin yellow upper / orange lower outline, rounded corners, and additional transparent black fill.
- Full-screen dimming retains about 45.7% of a stable sky patch's brightness. Empty panel retains about 28.4% of the same scene before dimming. This supports dim opacity 0.55 and extra panel opacity ~0.38–0.40.
- Native center marker spans full panel height. Yellow top taper points down; orange bottom tip points up. Marker remains stationary in the panel.
- Base card color area is approximately 48×41 pixels, stride approximately 69 pixels, so cards are wider than tall. Percentage sits bottom right. No name labels or separate winner text appear.

## Entry (measured, native easing inference)

Panel enters EMPTY from below. Observed upper border positions:

| Time | Top Y |
|---|---:|
| 12.667 | 545 |
| 12.700 | 495 |
| 12.800 | 393 |
| 12.900 | 305 |
| 13.000 | 249 |
| 13.100 | 217 |
| 13.200 | 210 |
| 13.300 | 214 |
| 13.400 | 227 |
| 13.500 | 239 |
| 13.600 | 248 |

Resting top is 248; overshoot minimum210 means38px/0.070viewport upwards. Standard Back-Out's ~0.100 overshoot coefficient implies start-to-targetdistance~0.70viewport, so initial centerY≈1.20 is a plausible implementation. Native Back-Out s=1.70158, startcenter1.2, finalcenter.5 fits approximately1.04s duration, onset12.617, RMSE3.85px. Treat those fitted values as approximate; recommended implementation is native1s Back-Out from1.2 to.5 and compare with native-PTS root measurements.

No cards at13.500; first visible cards at13.533. First tiles slide from the right; full strip fills by13.70–13.73. Do not show pre-populated tiles during most of panel entry.

Dim brightness ratios:1.00@12.6,.975@12.7,.917@12.8,.797@12.9,.668@13.0,.535@13.1,.469@13.2,.457@13.3. Smooth~0.65s fade, plausibly SineInOut; exact easing unproven.

## Continuous center focus (measured)

Cards enlarge while approaching center, shrink as leaving. This runs throughout spin, not only after the winner lands. At17.6, two adjacent central cards centeredx401 and470 are54×48 and56×47; farther cards at332 and538 are48×42 and48×40. At21.5 and22.5, winner at433 is58×52; immediate neighbors approximately69px away are50–52×44; next neighbors137px away are46–48×41.

Approximate intended scale: maximum1.22–1.25, first-neighbor~1.08, base by~1.5strides. A distance-dependent scale is strongly supported; exact formula is inference. No added winner growth, label fade, confetti, or other new reveal stage is seen during the stationary hold.

## Exit (measured and fitted)

The panel first dips DOWN, then moves rapidly UP offscreen.

| Time | Top Y |
|---|---:|
| 23.400 | 248 |
| 23.500 | 249 |
| 23.600 | 256 |
| 23.700 | 267 |
| 23.800 | 277 |
| 23.900 | 280 |
| 24.000 | 272 |
| 24.100 | 247 |
| 24.200 | 199 |
| 24.300 | 124 |
| 24.500 | Offscreen |

Standard Back-In s=1.70158 fits start23.4668, duration0.9990s, endpointtop−75.4, RMSE0.323px. This corresponds centerY≈−0.1 viewport. Initial downward overshoot33px≈0.061viewport. Keep all cards/marker in the exiting panel, no scale-away or fade-only exit.

Dimming begins clearing later than panel motion: stable.457 through23.6, then.462@23.7,.495@23.8,.588@23.9,.711@24.0,.839@24.1,.944@24.2,1.00@24.3. This supports a delayed ~0.65s dim fade, beginning roughly0.15–0.20s after exit begins.

Root owns horizontal strip fitting and determines exact stop/hold duration. No audio analysis was performed, so no sound-match claim is made here.
