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
