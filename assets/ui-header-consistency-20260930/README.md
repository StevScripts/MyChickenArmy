# Shared menu topbars

User requested consistent topbars across the current menus. UITheme now owns
the Army-derived 1474:83 header aspect, icon gutter, left title, inset rim,
approved full-sheet studs and one red close control. All eight menus use it;
the standard shell also covers the Studio tools page. Per-screen header and
close overrides were removed. Bodies start below the shared proportional gap.
Offline Earnings adds the shared X with the same dismissal as Continue.

All eight previews were visually inspected in Pet Roll Test edit mode. The
focused check passed at 1280×720 and 844×390: matching header/X proportions,
no title/X or body/header overlap, and native Scale/aspect components only.
These are simulated parent dimensions, not physical-device usability tests.
All eight changed modules compiled through Studio loadstring. No Play session,
purchase, DataStore change, asset upload, publish, Git commit or push occurred.

`before/` preserves the eight source files as they stood before this request.
`header-check.luau` restores the preview parent geometry after its checks.
The Studio preview is left on MyArmy. Save the place separately to retain it.
