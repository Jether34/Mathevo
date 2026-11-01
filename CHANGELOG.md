# Changelog

## 2026-11-01

### Calculator visualization update

- Added 3D plot meshes made from visibly shaded triangular faces.
- Added an approximate total surface area and face count for equation plots.
- Added side lengths and face area for the largest sampled triangle in an implicit 3D surface.
- Added the right triangle area formula and computed area to the interactive triangle view. The hypotenuse, adjacent side, and opposite side remain labeled on the shape.
- Kept the x, y, and z axes visible and made expression surface rotation keep its text upright.
- Added a default plane for 3D graph mode when no expression has been entered.

Surface area values for plotted equations are mesh approximations over the displayed domain. Increasing mesh resolution can improve precision at additional rendering cost.

## 2026-11-01

### Interactive triangle visualization

- Reworked the right-triangle plot as a shaded 3D triangular prism with x, y, and z axes, distinct side colors, and a matching yellow angle marker.
- Added orbit controls that support vertical and horizontal touch drags, zoom in/out buttons, and a reset view action.
- Added side-by-side shaded face area cards with formulas and values for both triangular ends and each rectangular side, plus total prism surface area.
- Wired the angle and hypotenuse sliders to update the plot, side lengths, face areas, total surface area, and the expression returned to the calculator.
