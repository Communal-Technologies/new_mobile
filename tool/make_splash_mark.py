"""The purple mark Android 12+ centres on the launch window.

Until now this app declared nothing for the platform splash, so Android drew the
adaptive launcher foreground at a size of its own choosing — which meant the
launch screen silently resized whenever the launcher icon did. This writes the
mark as its own drawable, ink-cropped, so res/drawable/splash_mark.xml can set
the size in dp and the collector and Meet can declare the same number.

Run after tool/refit_launcher_mark.py.

    python3 tool/make_splash_mark.py
"""

from PIL import Image

SRC = "assets/images/launcher_icon_foreground.png"
OUT = "android/app/src/main/res/drawable-nodpi/brand_mark_purple.png"

im = Image.open(SRC).convert("RGBA")
art = im.crop(im.split()[3].getbbox())
side = max(art.size)
square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
square.paste(art, ((side - art.width) // 2, (side - art.height) // 2))
square.resize((1024, 1024), Image.LANCZOS).save(OUT)
print(f"{OUT}: mark {art.size[0]}x{art.size[1]} in a {side}px square")
