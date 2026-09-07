# Order the `blocked` keycap

Recommended: [Max Keyboard — Custom Art & Custom Color Keycaps](https://maxkeyboard.com/custom-art-icon-or-text-cherry-mx-keycaps.html).
Use a **standard Tab-sized, 1.5u keycap**, with the custom legend **`blocked`**.
The exact 1.5u configuration was checked in the live selector on September 5,
2026 at **US$11**, quantity one, before shipping and tax.

| Field | Choose |
| --- | --- |
| Keycap Size | **R3 1x1.5 (Tab / \|)** |
| Keycap Color | **White** (Beige is available if you prefer a warmer cap) |
| Print Area | **TOP Print only** |
| Quantity | **1** |
| Upload Your Artwork | [blocked-tab-upload.svg](blocked-tab-upload.svg) (preferred vector) or [blocked-tab-upload.png](blocked-tab-upload.png) |

The current design uses **Apple SF Compact Regular**, rendered from the font
already installed on the Mac. The lowercase word sits at the **lower-left of
the TOP surface**, as viewed by the person typing. Use the selected **R3 1x1.5
(Tab / \|)** option, White, TOP Print only. The lettering is neutral gray
**sRGB #8B8B8B (RGB 139, 139, 139)**, chosen from Apple’s official product image after comparison with three independent photos.
See [color research and samples](color-research.md).
It is not an official Apple ink specification; ask the printer to confirm the
printed gray on the white cap in the proof.

Paste this into the comments field:

> Print the supplied lowercase “blocked” lettering in neutral gray (sRGB #8B8B8B) on the TOP surface
> of the white R3 1x1.5 Tab keycap. Preserve the supplied font shapes. Set the
> word approximately 9 mm wide, with its visible ink 2 mm from the usable top
> surface's LEFT and FRONT (lower) edges, viewed from the typist's position.
> Do not center the word or enlarge it to fill the key. The transparent canvas
> communicates placement; adjust to your actual printable surface. Please
> provide a placement proof before printing.

The SVG contains outlined lettering only, with no embedded font or live text.
The transparent PNG is 2700 × 1800 px, under 200 KB, satisfying the shown
300 px minimum and 2 MB maximum. Upload **one** of these two files. The
[placement preview](blocked-tab-placement-preview.png) is illustrative and
contains a white key shape; **do not upload the preview as print artwork**.
The 27 × 18 mm artwork canvas conveys layout intent, not verified dimensions
of the vendor's sculpted top surface. The older `blocked-artwork.png` is
superseded by these files.

[Apple identifies SF Compact](https://developer.apple.com/fonts/) as part of
its San Francisco family. This is an Apple-style composition, not a claim that
the exact weight, spacing and geometry match every Apple keyboard generation.
The artwork was rendered with the macOS-bundled font; no font file is included.
[macOS Sequoia's license, section 2E](https://www.apple.com/legal/sla/docs/macOSSequoia.pdf)
addresses display/printing with bundled fonts and separate font-embedding
restrictions. The standalone developer-font download has different terms;
noncommercial intent alone is not blanket font permission.

To regenerate on a Mac with the bundled SF Compact font, run
`swift keycap/make-artwork.swift` from the repository root. The script creates
the two upload files, the placement preview and [artwork-spec.json](artwork-spec.json).
No order or vendor proof has been requested by the project.

Max's [profile guide](https://maxkeyboard.com/mechanical-keycap-layout-and-size-chart.html)
describes OEM profile, and its [keycap guide](https://blog.maxkeyboard.com/dwkb/keycap-types/)
describes colored caps as ABS. This is an MX-compatible, non-shine-through cap.
“Cherry MX compatible” describes the mount, not Cherry profile. The standard
1.5u Tab option is the intended fit; exact external dimensions and stem location
were not verified against a manufacturer drawing. The Blender reference is
approximate, so check seating and free return before final assembly.
The [key mounting guide](../docs/key-mounting.md) explains the centred MX socket,
switch clips, full-travel checks and removal. The hollow socket shown in Blender
is illustrative; it does not replace the manufacturer's moulded cap.

For US delivery, the [shipping policy](https://maxkeyboard.com/shipping-information.html)
lists 3–5 business days for production plus 3–7 business days for standard
ground shipping. That is an estimate, not a guaranteed birthday arrival date;
the shipping charge appears at checkout.

If PBT is more important than a one-cap order,
[Gimsun's custom PBT cap](https://gimsuncustom.com/products/custom-pbt-ansi-layout-keycap-single-key?variant=49847600808247)
offers **Cherry Profile → R3 → 1.5u (Tab)** and dye-sublimation printing at
$3.99 each, but its product-specific minimum is **three caps** ($11.97 before
shipping/tax). Its customizer resets the size, so select it again after opening
the editor. Max remains the selected BOM item.
