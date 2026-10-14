# -*- coding: utf-8 -*-
# 生成君势力标记三件套：jun.png / jun-magatama.png / jun-back.png
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = r"C:\Users\32168\Desktop\FreeKill-release\packages\AAA new sanguo\image\kingdom"
FONT_BD = r"C:\Windows\Fonts\msyhbd.ttc"
FONT = r"C:\Windows\Fonts\msyh.ttc"

def load_font(path, size):
    return ImageFont.truetype(path, size)

def draw_text_center(draw, xy, text, font, fill, stroke_width=0, stroke_fill=None):
    bbox = draw.textbbox((0, 0), text, font=font, stroke_width=stroke_width)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    x = xy[0] - w / 2 - bbox[0]
    y = xy[1] - h / 2 - bbox[1]
    draw.text((x, y), text, font=font, fill=fill, stroke_width=stroke_width, stroke_fill=stroke_fill)

def make_jun_icon():
    S = 50
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, S - 1, S - 1], fill=None, outline=(230, 190, 90, 255), width=3)
    d.ellipse([4, 4, S - 4, S - 4], fill=(58, 36, 96, 255))
    for i in range(18):
        alpha = int(120 * (1 - i / 18))
        d.ellipse([5 + i * 0.4, 5 + i * 0.4, S - 5 - i * 0.4, S - 5 - i * 0.4], fill=(90, 55, 150, alpha))
    font = load_font(FONT_BD, 34)
    draw_text_center(d, (S / 2, S / 2 + 1), "君", font, fill=(245, 205, 120, 255), stroke_width=2, stroke_fill=(70, 40, 10, 255))
    img = img.filter(ImageFilter.SMOOTH)
    img.save(OUT + r"\jun.png")

def make_magatama():
    W, H = 14, 16
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 2, W - 2, H - 2], fill=(235, 195, 100, 255))
    d.ellipse([1, 1, W - 2, H - 2], fill=(245, 215, 130, 255))
    d.ellipse([4, 8, W - 5, H - 3], fill=(255, 235, 170, 255))
    img.save(OUT + r"\jun-magatama.png")

def make_back():
    W, H = 175, 233
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, H], fill=(74, 52, 38, 255))
    for i in range(60):
        alpha = int(20 * (1 - i / 60))
        d.ellipse([-30 + i, -30 + i, W + 30 - i, H + 30 - i], fill=(120, 80, 50, alpha))
    d.rectangle([6, 6, W - 7, H - 7], outline=(215, 175, 90, 255), width=3)
    d.rectangle([12, 12, W - 13, H - 13], outline=(150, 110, 55, 255), width=1)
    for (cx, cy) in [(14, 14), (W - 14, 14), (14, H - 14), (W - 14, H - 14)]:
        d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], outline=(230, 195, 110, 255), width=2)
    mx, my, mr = 46, 46, 26
    d.ellipse([mx - mr, my - mr, mx + mr, my + mr], fill=(72, 42, 110, 255), outline=(235, 200, 110, 255), width=3)
    d.ellipse([mx - mr + 4, my - mr + 4, mx + mr - 4, my + mr - 4], fill=(100, 62, 150, 180))
    font = load_font(FONT_BD, 30)
    draw_text_center(d, (mx, my + 1), "君", font, fill=(250, 215, 130, 255), stroke_width=2, stroke_fill=(60, 35, 8, 255))
    for yy in range(90, H - 20, 14):
        d.line([26, yy, 26, yy + 8], fill=(215, 175, 90, 200), width=2)
    d.arc([W - 70, H - 70, W - 12, H - 12], 0, 360, fill=(215, 175, 90, 220), width=3)
    d.ellipse([W - 52, H - 52, W - 30, H - 30], outline=(230, 195, 110, 220), width=2)
    img.save(OUT + r"\jun-back.png")

make_jun_icon()
make_magatama()
make_back()
print("DONE")
