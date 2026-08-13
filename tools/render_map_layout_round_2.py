"""Render the approved-direction round-two campus map as a PNG discussion board."""

from __future__ import annotations

from math import comb
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "design" / "map-layout-round-3.png"
FONT_PATH = ROOT / "assets" / "fonts" / "NotoSansCJKsc-Regular.otf"

C = {
    "bg": "#152019", "panel": "#202C23", "panel2": "#1A251D", "line": "#3B4C3E",
    "text": "#FAF3DF", "muted": "#C9D2BC", "dim": "#98A78F", "grass": "#8EB361",
    "grass2": "#A8C878", "grid": "#789C5C", "deep": "#527D45", "dark_leaf": "#3E673D",
    "path": "#E1C17B", "path_light": "#F0D99A", "path_edge": "#C49A57", "wall": "#E9D3A5", "roof": "#A6533E",
    "water": "#61A1A5", "water2": "#8BC7B6", "gold": "#F0BD46", "blue": "#315F82",
    "outline": "#3B302B", "orange": "#D87943", "locked": "#85C7B8", "white": "#FFFFFF",
}

# Exact draft geometry in tile coordinates. Lake and plaza are locked by user choice.
BUILDINGS = [
    (7, 3, 15, 15, "教学楼 A"),
    (66, 4, 26, 11, "教学楼 B"),
]
LAKE = (4, 47, 24, 20)
LAKE_POINTS = [(6, 51), (9, 48), (15, 47), (22, 49), (27, 53), (28, 58),
               (25, 64), (19, 66), (11, 65), (6, 62), (4, 57)]
PLAZA = (38, 28, 20, 16)
GARDEN = (70, 57, 22, 13)

TREASURES = [
    (3, 18), (12, 20), (23, 18), (34, 18), (45, 18), (56, 18), (67, 18), (78, 18), (91, 18),
    (5, 27), (17, 26), (29, 26), (41, 24), (54, 24), (66, 26), (78, 25), (91, 27),
    (4, 36), (16, 36), (29, 35), (35, 32), (62, 34), (76, 35), (92, 36),
    (4, 44), (16, 44), (31, 44), (42, 47), (54, 47), (67, 45), (79, 44), (92, 45),
    (3, 68), (30, 67), (48, 56), (59, 56), (80, 62), (91, 62), (80, 68), (91, 68),
]

TREES = [(34, 8), (61, 10), (8, 22), (29, 20), (64, 22), (89, 21), (33, 49),
         (61, 50), (93, 47), (39, 62), (52, 63), (66, 60), (31, 58)]
FLOWERS = [(13, 24), (22, 29), (35, 20), (58, 20), (73, 30), (83, 43),
           (32, 53), (43, 57), (57, 58), (67, 51), (93, 29), (4, 24)]


def f(size: int):
    return ImageFont.truetype(str(FONT_PATH), size=size)


def p(origin, scale, cell):
    return (round(origin[0] + cell[0] * scale), round(origin[1] + cell[1] * scale))


def cell_rect(origin, scale, rect):
    x, y, w, h = rect[:4]
    return (*p(origin, scale, (x, y)), *p(origin, scale, (x + w, y + h)))


def bezier(points, steps=55):
    degree = len(points) - 1
    result = []
    for i in range(steps + 1):
        t = i / steps
        result.append(tuple(sum(comb(degree, j) * (1 - t) ** (degree - j) * t ** j * points[j][axis]
                                for j in range(degree + 1)) for axis in (0, 1)))
    return result


def rounded_path(draw, origin, scale, cells, width_tiles=4.2, color=None):
    color = color or C["path"]
    points = [p(origin, scale, cell) for cell in cells]
    width = round(width_tiles * scale)
    edge = width + round(scale * 0.8)
    draw.line(points, fill=C["path_edge"], width=edge, joint="curve")
    draw.line(points, fill=color, width=width, joint="curve")
    radius = width / 2
    for point in (points[0], points[-1]):
        draw.ellipse((point[0] - radius, point[1] - radius, point[0] + radius, point[1] + radius), fill=color)


def label_center(draw, box, text, font, fill):
    bounds = draw.textbbox((0, 0), text, font=font)
    draw.text(((box[0] + box[2] - (bounds[2] - bounds[0])) / 2,
               (box[1] + box[3] - (bounds[3] - bounds[1])) / 2 - bounds[1]), text, font=font, fill=fill)


def draw_building(draw, origin, scale, item):
    box = cell_rect(origin, scale, item)
    draw.rounded_rectangle(box, radius=10, fill=C["wall"], outline=C["outline"], width=4)
    x, y, w, _h = item[:4]
    draw.rectangle(cell_rect(origin, scale, (x + 1, y + 1, w - 2, 3)), fill=C["roof"])
    label_center(draw, box, item[4], f(13), C["outline"])


def draw_tree(draw, origin, scale, cell):
    x, y = p(origin, scale, cell)
    r = scale * 1.7
    draw.ellipse((x - r, y - r, x + r, y + r), fill=C["dark_leaf"], outline=C["outline"], width=2)
    draw.ellipse((x - r * .25, y - r * .75, x + r * .9, y + r * .35), fill=C["deep"])


def draw_flower(draw, origin, scale, cell):
    x, y = p(origin, scale, cell)
    r = max(3, scale * .45)
    draw.ellipse((x - r, y - r, x + r, y + r), fill=C["orange"])
    draw.ellipse((x - r * .3, y - r * .3, x + r * .3, y + r * .3), fill=C["gold"])


def badge(draw, x, y, number, title, accent):
    draw.ellipse((x, y, x + 34, y + 34), fill=accent)
    label_center(draw, (x, y, x + 34, y + 34), str(number), f(15), C["bg"])
    draw.text((x + 46, y + 3), title, font=f(17), fill=C["text"])


def main():
    image = Image.new("RGB", (1600, 1050), C["bg"])
    draw = ImageDraw.Draw(image)
    draw.ellipse((1250, -360, 1800, 220), fill="#1C3423")
    draw.ellipse((-250, 830, 300, 1320), fill="#17302E")

    draw.text((58, 38), "校园寻宝 · 地图布局讨论板 03", font=f(38), fill=C["text"])
    draw.text((58, 91), "本轮调整：自然湖岸 / 右下开放花园 / 正方形教学楼 A；环形主路与中央广场保持不变。", font=f(18), fill=C["muted"])
    draw.rounded_rectangle((1322, 47, 1540, 89), radius=21, fill=C["locked"])
    label_center(draw, (1322, 47, 1540, 89), "第三轮：确认场地形状", f(14), C["bg"])

    # Map panel
    draw.rounded_rectangle((44, 136, 1116, 977), radius=26, fill="#0F1711")
    draw.rounded_rectangle((38, 128, 1110, 969), radius=26, fill=C["panel"], outline=C["gold"], width=2)
    draw.text((68, 151), "方案 A3｜湖畔花园环", font=f(25), fill=C["text"])
    draw.text((68, 188), "粗黄线是唯一主环路；湖岸改为不规则曲线，右下花园通过十字小径接入主环。", font=f(15), fill=C["muted"])

    origin, scale = (66, 224), 10.55
    map_box = cell_rect(origin, scale, (0, 0, 96, 72))
    draw.rounded_rectangle(map_box, radius=16, fill=C["grass"], outline=C["grass2"], width=4)
    for x in range(0, 97, 4):
        px, _ = p(origin, scale, (x, 0))
        draw.line((px, origin[1], px, origin[1] + 72 * scale), fill=C["grid"], width=1)
    for y in range(0, 73, 4):
        _, py = p(origin, scale, (0, y))
        draw.line((origin[0], py, origin[0] + 96 * scale, py), fill=C["grid"], width=1)

    # Main loop: a single unmistakable circuit that bends around the locked southwest lake.
    ring = []
    for segment in [
        [(18, 21), (31, 20), (48, 19), (64, 20), (78, 21)],
        [(78, 20), (90, 27), (91, 40), (84, 48)],
        [(84, 48), (73, 56), (48, 56), (31, 52)],
        [(31, 52), (27, 47), (18, 45), (12, 39)],
        [(12, 39), (7, 32), (11, 25), (18, 21)],
    ]:
        ring.extend(bezier(segment))
    rounded_path(draw, origin, scale, ring, 4.4)

    # Four clear spokes/shortcuts. They never create maze-like branches.
    for route in [[(48, 19), (48, 28)], [(58, 36), (90, 36)], [(48, 44), (48, 56)], [(38, 36), (12, 36)]]:
        rounded_path(draw, origin, scale, route, 2.7, C["path"])

    # Locked lake, now expressed as a tile-friendly irregular shoreline.
    lake_box = cell_rect(origin, scale, LAKE)
    lake_polygon = [p(origin, scale, point) for point in LAKE_POINTS]
    draw.polygon(lake_polygon, fill=C["water"])
    draw.line(lake_polygon + [lake_polygon[0]], fill=C["outline"], width=5, joint="curve")
    draw.line([p(origin, scale, (8, 54)), p(origin, scale, (15, 52)), p(origin, scale, (23, 54))],
              fill=C["water2"], width=5, joint="curve")
    draw.line([p(origin, scale, (7, 59)), p(origin, scale, (14, 58)), p(origin, scale, (24, 60))],
              fill=C["water2"], width=5, joint="curve")
    draw.rounded_rectangle((lake_box[0] + 18, lake_box[1] + 18, lake_box[0] + 154, lake_box[1] + 50), radius=16, fill=C["bg"])
    draw.text((lake_box[0] + 34, lake_box[1] + 23), "锁定 · 自然湖岸", font=f(13), fill=C["locked"])

    plaza_box = cell_rect(origin, scale, PLAZA)
    draw.rounded_rectangle(plaza_box, radius=22, fill=C["path"], outline=C["outline"], width=5)
    for y in (32, 40):
        draw.line((*p(origin, scale, (41, y)), *p(origin, scale, (55, y))), fill=C["path_edge"], width=3)
    label_center(draw, plaza_box, "中央广场", f(17), C["outline"])
    sx, sy = p(origin, scale, (48, 36))
    draw.ellipse((sx - 12, sy - 12, sx + 12, sy + 12), fill=C["blue"], outline=C["white"], width=3)

    for building in BUILDINGS:
        draw_building(draw, origin, scale, building)

    # Southeast walkable flower garden replaces the former activity-room building.
    garden_box = cell_rect(origin, scale, GARDEN)
    draw.rounded_rectangle(garden_box, radius=18, fill=C["grass2"], outline=C["deep"], width=4)
    rounded_path(draw, origin, scale, [(81, 55), (81, 70)], 1.8, C["path_light"])
    rounded_path(draw, origin, scale, [(70, 63), (92, 63)], 1.8, C["path_light"])
    for bed in [(72, 58, 7, 3), (83, 58, 7, 3), (72, 65, 7, 3), (83, 65, 7, 3)]:
        box = cell_rect(origin, scale, bed)
        draw.rounded_rectangle(box, radius=7, fill=C["deep"], outline=C["outline"], width=2)
        bx, by, bw, bh = bed
        for fx in (bx + 1.5, bx + 3.5, bx + 5.5):
            for fy in (by + 1, by + bh - 1):
                draw_flower(draw, origin, scale, (fx, fy))
    garden_title_box = cell_rect(origin, scale, (77, 61, 8, 4))
    draw.rounded_rectangle(garden_title_box, radius=10, fill=C["bg"])
    label_center(draw, garden_title_box, "花园", f(13), C["text"])
    for cell in TREES:
        draw_tree(draw, origin, scale, cell)
    for cell in FLOWERS:
        draw_flower(draw, origin, scale, cell)

    # Exact 40 candidate points.
    for cell in TREASURES:
        x, y = p(origin, scale, cell)
        r = 6
        draw.ellipse((x - r, y - r, x + r, y + r), fill=C["gold"], outline=C["outline"], width=2)

    # Region labels.
    regions = [((18, 21), "北庭院"), ((18, 45), "湖畔"), ((84, 29), "林荫道"), ((73, 53), "南花园")]
    for index, (cell, name) in enumerate(regions, start=1):
        x, y = p(origin, scale, cell)
        draw.ellipse((x - 15, y - 15, x + 15, y + 15), fill=C["bg"], outline=C["text"], width=2)
        label_center(draw, (x - 15, y - 15, x + 15, y + 15), str(index), f(14), C["text"])
        draw.rounded_rectangle((x + 20, y - 15, x + 92, y + 15), radius=15, fill=C["bg"])
        label_center(draw, (x + 20, y - 15, x + 92, y + 15), name, f(13), C["muted"])

    # Right decision column.
    draw.rounded_rectangle((1140, 128, 1558, 969), radius=26, fill=C["panel"], outline=C["line"], width=2)
    draw.text((1170, 157), "本版空间逻辑", font=f(24), fill=C["text"])
    draw.text((1170, 199), "一条主环 + 四条短捷径", font=f(18), fill=C["gold"])
    draw.text((1170, 229), "没有死路，不需要记路线。", font=f(14), fill=C["muted"])

    badge(draw, 1170, 276, 1, "北庭院", C["gold"])
    draw.text((1170, 319), "教学楼 A 改为正方形体量；\n与横向教学楼 B 形成对比。", font=f(14), fill=C["muted"], spacing=7)
    badge(draw, 1170, 383, 2, "湖畔", C["water"])
    draw.text((1170, 426), "西南湖区改为多折点自然岸线；\n主环仍从北缘经过。", font=f(14), fill=C["muted"], spacing=7)
    badge(draw, 1170, 490, 3, "林荫道", C["deep"])
    draw.text((1170, 533), "树木集中在东侧形成记忆点，\n仍保留一条宽阔通行带。", font=f(14), fill=C["muted"], spacing=7)
    badge(draw, 1170, 597, 4, "南花园", C["orange"])
    draw.text((1170, 640), "移除园艺活动室，改为可进入的\n四块花圃与十字小径。", font=f(14), fill=C["muted"], spacing=7)

    draw.line((1170, 703, 1528, 703), fill=C["line"], width=2)
    draw.text((1170, 728), "已锁定", font=f(15), fill=C["locked"])
    draw.text((1250, 728), "自然湖岸 / 中央广场 / 环路", font=f(15), fill=C["text"])
    draw.text((1170, 766), "保持", font=f(15), fill=C["dim"])
    draw.text((1250, 766), "96 × 72 格 / 40 个宝箱点", font=f(15), fill=C["text"])
    draw.text((1170, 804), "主路", font=f(15), fill=C["dim"])
    draw.text((1250, 804), "完整闭环，宽约 4 格", font=f(15), fill=C["text"])
    draw.text((1170, 842), "捷径", font=f(15), fill=C["dim"])
    draw.text((1250, 842), "仅 4 条，全部直达广场", font=f(15), fill=C["text"])

    draw.rounded_rectangle((1170, 890, 1528, 942), radius=18, fill=C["gold"])
    label_center(draw, (1170, 890, 1528, 942), "下一步：确认 A3 布局", f(17), C["bg"])

    draw.text((54, 1005), "请回复：A3确认；或继续指出要改变的岸线、建筑、道路或花园形状。", font=f(16), fill=C["muted"])
    image.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
