"""Refit the Communal mark inside the adaptive launcher canvas.

Android masks the 108dp adaptive canvas down to 72dp of visible icon, so a mark
drawn at 44% of the canvas — which is what all three apps shipped — reads at two
thirds of the icon a launcher actually paints, and looks small in a drawer next
to icons that fill theirs. This rescales the mark in place, centred, to a share
of the canvas. The mark's own geometry is untouched: it is the padding that
changes, and the alpha is resampled once from the 1024px original rather than
from an already-scaled copy.

The member app's files are the fleet's geometry source — the collector's and
Meet's icons are derived from them — so this runs here and the other two
regenerate from the result.

    python3 tool/refit_launcher_mark.py
"""

from PIL import Image

FILE = "assets/images/launcher_icon_foreground.png"

# The mark's larger dimension as a share of the canvas. 0.52 of 108dp is 78% of
# the 72dp the mask leaves visible, which fills the icon without pushing the
# mark's own bulk into the corners a round mask cuts off.
#
# This is the whole size, which is only true because all three pubspecs set
# adaptive_icon_foreground_inset: 0. The generator's default inset is 16%, and it
# is applied on top of whatever this file produces — so with the default, a mark
# measured here at 78% of the icon lands at 53% on the phone.
TARGET = 0.52


def refit(path, target):
    im = Image.open(path).convert("RGBA")
    side = im.width
    box = im.getbbox()
    art = im.crop(box)
    scale = (target * side) / max(art.size)
    grown = art.resize(
        (max(1, round(art.width * scale)), max(1, round(art.height * scale))),
        Image.LANCZOS,
    )
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(grown, ((side - grown.width) // 2, (side - grown.height) // 2))
    out.save(path)
    return art.size, grown.size


before, after = refit(FILE, TARGET)
print(f"{FILE}: mark {before[0]}x{before[1]} -> {after[0]}x{after[1]}")
