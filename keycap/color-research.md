# White Apple keyboard legend color

Research date: September 7, 2026.

**No public Apple ink formulation, Pantone reference, measured CIELAB target,
or official sRGB legend specification was found.** The final upload uses
**sRGB #8B8B8B (139, 139, 139)** as a photo-based visual match, not an exact
Apple manufacturing specification. This replaces the earlier unsampled
design choice #6E6E73.

## Specification search

Apple's [Magic Keyboard technical specifications](https://support.apple.com/en-ca/121955)
do not publish a legend-color target. Its
[recycler guide](https://www.apple.com/recycling/recycler-guides/pdf/products/accessories/Magic_Keyboard_Recycler_Guide_English.pdf)
describes material categories, and its
[Regulated Substances Specification](https://www.apple.com/environment/pdf/Apple_Regulated_Substances_Specification.pdf)
addresses chemical restrictions; neither supplies a keyboard legend ink/color recipe.
These sources do not establish the exact marking process for this keyboard, either.

## Four reference images inspected

| Reference | Sampled legends | Median pixel RGB values |
| --- | --- | --- |
| [Apple official MJLX4 product image](https://store.storeimages.cdn-apple.com/1/as-images.apple.com/is/MJLX4?wid=4000&hei=4000&fmt=jpeg&qlt=90&.v=1785993102206), from the [Magic Keyboard product page](https://www.apple.com/shop/product/mjlx4ll/a/magic-keyboard-usb-c-us-english) | Q, A, control | (139,139,139), (139,140,140), (139,139,139) |
| [F. Kawabata's close-up](https://note.com/kawabata/n/n1211c0fff562) | Q, A, tab | (79,84,82), (73,78,77), (85,90,91) |
| [Applesfera keyboard close-up](https://www.applesfera.com/tutoriales/como-borrar-texto-adelante-nuestro-mac-ipad) | Q, A, tab | (121,122,127), (120,120,126), (148,149,154) |
| [AppleInsider keyboard photograph](https://appleinsider.com/inside/iphone/tips/how-to-access-extended-characters-like-the-degree-symbol-on-iphone-and-mac) | shift, return, delete | (133,135,128), (118,121,113), (107,109,97) |

The official image provides a consistent neutral-gray target and the largest
image for sampling. The other photographs show substantially different
exposure, color casts, focus and viewing angles. Their nearby white key
surfaces differ too. The Applesfera image also uses an older key/font style,
so it is only a general gray-on-white appearance reference. These are not
four calibrated measurements of one identical physical object.

The chosen #8B8B8B follows the recurring official-image median. It is **not**
an average of all photos or a claim that photographed RGB reveals an ink formula.

## Sampling method and limits

[color-samples.json](color-samples.json) records original image URLs, SHA-256
digests, dimensions, all 12 legend/white-patch rectangles, thresholds and results.
Images were downloaded temporarily for analysis and are not redistributed here.
Coordinates refer to the original image pixels, with the origin at top-left.

For each hand-selected legend rectangle, take a nearby clean key-surface patch.
Compute its median RGB and weighted encoded-RGB luminance
`0.2126 R + 0.7152 G + 0.0722 B`. Select legend-rectangle pixels below 75% of
that patch luminance, then calculate their per-channel medians. This excludes
the white key background and many antialiased edge pixels. It does not remove
all blur, JPEG artifacts, reflections or lighting effects. The threshold is
an analysis heuristic, not a calibrated reflectance measurement. None of the
downloaded images contained an ICC profile; sRGB was assumed.

An exact physical color match would require a measured reference key or an
Apple manufacturing color target, followed by the printer matching the color
on its actual white keycap material. A hex value alone cannot specify the ink,
coating, substrate or printer profile. No CMYK or Pantone equivalent is claimed.

## Order instruction

Use the current SVG or PNG, select **White / TOP Print only / R3 1x1.5 Tab**, and
ask the vendor:

> Print the supplied lettering in neutral gray, targeting sRGB #8B8B8B on the
> white keycap. This is an Apple-keyboard-inspired photo match, not a Pantone
> specification. Preserve the supplied type shapes and lower-left placement:
> word 9 mm wide, visible ink about 2 mm from the usable left and front edges
> of the TOP surface. Please provide a placement/color proof before printing.
