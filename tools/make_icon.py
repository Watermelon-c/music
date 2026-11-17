"""生成 App 图标（1024x1024）：紫色渐变圆角底 + 白色圆 + 音符"""
from PIL import Image, ImageDraw, ImageFont

S = 1024
TOP = (91, 33, 182)     # 5B21B6
BOTTOM = (124, 77, 255)  # 7C4DFF

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

grad = Image.new("RGB", (S, S))
d = ImageDraw.Draw(grad)
for y in range(S):
    t = y / (S - 1)
    d.line([(0, y), (S, y)],
           fill=tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))

mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=230, fill=255)
img.paste(grad, (0, 0), mask)

dr = ImageDraw.Draw(img)
cx, cy, r = S // 2, S // 2, 336

dr.ellipse([cx - r - 24, cy - r - 24, cx + r + 24, cy + r + 24], fill=(255, 255, 255, 38))
dr.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 255))

font = ImageFont.truetype("C:/Windows/Fonts/seguisym.ttf", 520)
text = "\u266a"
bbox = dr.textbbox((0, 0), text, font=font)
w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
dr.text((cx - w / 2 - bbox[0], cy - h / 2 - bbox[1] - 18), text,
        font=font, fill=(91, 33, 182, 255))

out = "assets/icon/icon.png"
img.save(out)
print("saved", out, img.size)
