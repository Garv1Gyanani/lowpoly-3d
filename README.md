# lowpoly-3d

**Desert Outpost** — A minimalist low-poly 3D idle clicker & Monument Valley diorama built 100% in pure Dart and Flutter (FVM `3.50.1`).

## Features
- **Batched Pure-Dart 3D Engine**: Single-pass `Canvas.drawVertices` hardware triangle batching, static world mesh caching, near-plane polygon clipping, Monument Valley warm-vs-cool facet shading, and grounded two-stage contact shadows.
- **Responsive Diorama Camera**: Intimate Stage 1 cart framing that cinematically expands as your town grows, responsive across 16:9 widescreen browsers and 9:16 mobile portrait, with smooth pan, zoom, and horizontal orbit (`Right-drag`, `Shift+drag`, or `Q`/`E`).
- **Living Route 163 Ecosystem**: Sculpted Monument Valley mesas, dry arroyo washes, luminous 3D clouds, depth-sorted utility wires, multi-passenger Camper RVs & Tourist Vans, and 8 landmarks with visual upgrades from **Level 1 through Level 5**.
- **Handcrafted Carved-Wood HUD**: Custom `Bungee` & `Fredoka` typography, live miniature 3D isometric build/upgrade card previews, affordability progress bars with shake feedback, local save/load persistence with offline earnings, and a 360° 3D Object Studio.

## Run
```bash
fvm flutter pub get
fvm flutter run -d web-server
```
