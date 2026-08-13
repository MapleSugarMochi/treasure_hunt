"""Render the map-layout discussion board as a PNG preview."""

from __future__ import annotations

from math import comb
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "design" / "map-layout-round-1.png"
FONT_PATH = ROOT / "assets" / "fonts" / "NotoSansCJKsc-Regular.otf"

COLORS = {
    "bg": "#172018",
    "panel": "#222D24",
    "panel_stroke": "#39483A",
    "text": "#F8F1DC",
    "muted": "#C5CEB4",
    "dim": "#AEB9A0",
    "grass": "#8EB361",
    "grass_light": "#A8C878",
    "grass_dark": "#527D45",
    "path": "#D2AE6E",
    "path_light": "#E8CF91",
    "wall": "#E9D3A5",
    "roof": "#A6533E",
    "lake": "#61A1A5",
    "lake_light": "#8BC7B6",
    "gold": "#F0BD46",
    "player": "#315F82",
    "outline": "#3B302B",
    "orange": "#D87943",
}

CURRENT_TREASURES = [
    (3, 22), (11, 21), (21, 22), (31, 20), (45, 18), (56, 20), (68, 22), (82, 21),
    (92, 24), (6, 31), (18, 32), (29, 30), (39, 29), (52, 28), (64, 30), (76, 31),
    (89, 33), (4, 40), (15, 41), (26, 39), (37, 42), (47, 44), (59, 41), (71, 40),
    (84, 42), (93, 39), (3, 68), (31, 53), (40, 55), (48, 66), (61, 56), (67, 66),
    (93, 55), (34, 3), (48, 4), (57, 4), (3, 3), (93, 3), (34, 68), (93, 68),
]

PROPOSED_TREASURES = [
    (3, 23), (11, 21), (22, 21), (33, 18), (43, 20), (54, 20), (65, 19), (76, 21),
    (90, 23), (4, 31), (31, 28), (64, 28), (91, 31), (4, 40), (31, 42), (65, 42),
    (92, 41), (6, 48), (18, 48), (30, 52), (40, 52), (55, 52), (66, 49), (83, 47),
    (92, 50), (29, 63), (39, 64), (50, 66), (61, 64), (70, 62), (4, 68), (92, 68),
    (4, 4), (35, 4), (48, 4), (61, 4), (92, 4), (34, 68), (66, 68), (92, 57),
]


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_PATH), size=size)


def pt(origin: tuple[float, float], scale: float, cell: tuple[float, float]) -> tuple[int, int]:
    return (round(origin[0] + cell[0] * scale), round(origin[1] + cell[1] * scale))


def rect_from_cells(origin, scale, x, y, width, height):
    left, top = pt(origin, scale, (x, y))
    right, bottom = pt(origin, scale, (x + width, y + height))
    return (left, top, right, bottom)


def draw_grid(draw: ImageDraw.ImageDraw, origin, scale):
    x0, y0 = origin
    for x in range(0, 97, 4):
        px = round(x0 + x * scale)
        draw.line((px, y0, px, y0 + 72 * scale), fill="#74975B", width=1)
    for y in range(0, 73, 4):
        py = round(y0 + y * scale)
        draw.line((x0, py, x0 + 96 * scale, py), fill="#74975B", width=1)


def draw_polyline(draw, origin, scale, cells, width=5):
    draw.line([pt(origin, scale, cell) for cell in cells], fill=COLORS["path"], width=round(width * scale), joint="curve")
    radius = width * scale / 2
    for cell in (cells[0], cells[-1]):
        x, y = pt(origin, scale, cell)
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=COLORS["path"])


def bezier(points, steps=70):
    degree = len(points) - 1
    result = []
    for i in range(steps + 1):
        t = i / steps
        x = sum(comb(degree, j) * ((1 - t) ** (degree - j)) * (t**j) * points[j][0] for j in range(degree + 1))
        y = sum(comb(degree, j) * ((1 - t) ** (degree - j)) * (t**j) * points[j][1] for j in range(degree + 1))
        result.append((x, y))
    return result


def draw_building(draw, origin, scale, x, y, width, height):
    box = rect_from_cells(origin, scale, x, y, width, height)
    draw.rounded_rectangle(box, radius=round(scale), fill=COLORS["wall"], outline=COLORS["outline"], width=4)
    draw.rectangle(rect_from_cells(origin, scale, x + 1, y + 1, width - 2, 3), fill=COLORS["roof"])


def draw_treasures(draw, origin, scale, treasures):
    radius = max(5, round(scale * 1.25))
    for cell in treasures:
        x, y = pt(origin, scale, cell)
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=COLORS["gold"], outline=COLORS["outline"], width=2)
    x, y = pt(origin, scale, (48, 36))
    radius = round(scale * 2)
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=COLORS["player"], outline=COLORS["text"], width=3)


def draw_current_map(draw, origin, scale):
    map_box = rect_from_cells(origin, scale, 0, 0, 96, 72)
    draw.rounded_rectangle(map_box, radius=12, fill=COLORS["grass"], outline=COLORS["grass_light"], width=4)
    draw_grid(draw, origin, scale)
    draw_polyline(draw, origin, scale, [(2, 36), (94, 36)])
    draw_polyline(draw, origin, scale, [(48, 2), (48, 70)])
    draw_polyline(draw, origin, scale, [(4, 23), (31, 25), (48, 36)])
    draw_polyline(draw, origin, scale, [(48, 36), (70, 28), (92, 24)])
    draw_polyline(draw, origin, scale, [(48, 36), (65, 47), (93, 68)])
    draw_polyline(draw, origin, scale, [(48, 36), (34, 52), (29, 68)])
    draw.rounded_rectangle(rect_from_cells(origin, scale, 42, 31, 13, 11), radius=7, fill=COLORS["path_light"])
    draw_building(draw, origin, scale, 5, 4, 25, 13)
    draw_building(draw, origin, scale, 63, 6, 26, 12)
    draw_building(draw, origin, scale, 70, 49, 20, 15)
    draw.rounded_rectangle(rect_from_cells(origin, scale, 6, 48, 22, 17), radius=16, fill=COLORS["lake"], outline=COLORS["outline"], width=4)
    for y in (53, 59):
        draw.line([pt(origin, scale, (8, y)), pt(origin, scale, (26, y - 1))], fill=COLORS["lake_light"], width=4)
    draw.rounded_rectangle(rect_from_cells(origin, scale, 35, 8, 6, 12), radius=8, fill=COLORS["grass_dark"])
    draw.rounded_rectangle(rect_from_cells(origin, scale, 52, 51, 5, 12), radius=8, fill=COLORS["grass_dark"])
    draw_treasures(draw, origin, scale, CURRENT_TREASURES)


def draw_proposed_map(draw, origin, scale):
    map_box = rect_from_cells(origin, scale, 0, 0, 96, 72)
    draw.rounded_rectangle(map_box, radius=12, fill=COLORS["grass"], outline=COLORS["grass_light"], width=4)
    draw_grid(draw, origin, scale)

    ring_cells = []
    segments = [
        [(20, 22), (12, 29), (12, 45), (21, 53)],
        [(21, 53), (33, 64), (65, 64), (79, 53)],
        [(79, 53), (90, 44), (90, 29), (79, 21)],
        [(79, 21), (66, 13), (34, 13), (20, 22)],
    ]
    for segment in segments:
        ring_cells.extend(bezier(segment))
    draw_polyline(draw, origin, scale, ring_cells)
    for cells in [[(48, 15), (48, 29)], [(48, 43), (48, 61)], [(16, 36), (37, 36)], [(59, 36), (86, 36)]]:
        draw_polyline(draw, origin, scale, cells)

    draw.rounded_rectangle(rect_from_cells(origin, scale, 37, 28, 22, 16), radius=15, fill=COLORS["path_light"], outline=COLORS["outline"], width=4)
    draw_building(draw, origin, scale, 5, 5, 25, 12)
    draw_building(draw, origin, scale, 66, 5, 25, 12)
    draw_building(draw, origin, scale, 6, 52, 20, 12)
    draw_building(draw, origin, scale, 72, 52, 19, 12)

    lake = [pt(origin, scale, p) for p in [(8, 27), (12, 22), (24, 23), (28, 29), (31, 35), (27, 43), (17, 44), (7, 43), (4, 34)]]
    draw.polygon(lake, fill=COLORS["lake"], outline=COLORS["outline"])
    draw.line([pt(origin, scale, (9, 31)), pt(origin, scale, (28, 30))], fill=COLORS["lake_light"], width=4)
    draw.line([pt(origin, scale, (9, 38)), pt(origin, scale, (27, 37))], fill=COLORS["lake_light"], width=4)
    x, y = pt(origin, scale, (78, 34))
    draw.ellipse((x - 7 * scale, y - 7 * scale, x + 7 * scale, y + 7 * scale), fill=COLORS["grass_dark"], outline=COLORS["outline"], width=4)
    x, y = pt(origin, scale, (83, 39))
    draw.ellipse((x - 5 * scale, y - 5 * scale, x + 5 * scale, y + 5 * scale), fill="#6F914D")
    draw_treasures(draw, origin, scale, PROPOSED_TREASURES)

    for index, cell in enumerate([(48, 27), (15, 25), (82, 31), (48, 58)], start=1):
        x, y = pt(origin, scale, cell)
        radius = 13
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=COLORS["bg"], outline=COLORS["text"], width=2)
        label = str(index)
        box = draw.textbbox((0, 0), label, font=font(14))
        draw.text((x - (box[2] - box[0]) / 2, y - 11), label, font=font(14), fill=COLORS["text"])


def panel(draw, box, stroke=COLORS["panel_stroke"]):
    x0, y0, x1, y1 = box
    draw.rounded_rectangle((x0 + 6, y0 + 10, x1 + 6, y1 + 10), radius=24, fill="#101611")
    draw.rounded_rectangle(box, radius=24, fill=COLORS["panel"], outline=stroke, width=2)


def draw_card(draw, x, accent, number, title, lines, footer):
    box = (x, 776, x + 360, 950)
    draw.rounded_rectangle(box, radius=20, fill=COLORS["panel"], outline=COLORS["panel_stroke"], width=2)
    draw.ellipse((x + 16, 793, x + 48, 825), fill=accent)
    draw.text((x + 27, 799), str(number), font=font(15), fill=COLORS["bg"])
    draw.text((x + 60, 794), title, font=font(19), fill=COLORS["text"])
    for index, line in enumerate(lines):
        draw.text((x + 24, 843 + index * 29), line, font=font(15), fill=COLORS["muted"])
    draw.text((x + 24, 926), footer, font=font(13), fill=COLORS["dim"])


def main():
    image = Image.new("RGB", (1600, 1020), COLORS["bg"])
    draw = ImageDraw.Draw(image)
    draw.ellipse((1260, -330, 1750, 220), fill="#1D3021")
    draw.ellipse((-170, 780, 330, 1250), fill="#18302E")

    draw.text((64, 34), "校园寻宝 · 地图布局讨论板 01", font=font(38), fill=COLORS["text"])
    draw.text((64, 84), "先定空间骨架，再改 Godot。比例均为 96 × 72 格；黄点是宝箱候选点，蓝点是出生点。", font=font(18), fill=COLORS["muted"])
    draw.rounded_rectangle((1327, 43, 1536, 85), radius=21, fill=COLORS["gold"])
    draw.text((1360, 53), "本轮：选择路线气质", font=font(14), fill=COLORS["bg"])

    panel(draw, (48, 128, 764, 668))
    panel(draw, (796, 128, 1552, 668), COLORS["gold"])
    draw.text((80, 145), "现状｜十字主轴 + 放射支路", font=font(24), fill=COLORS["text"])
    draw.text((80, 181), "优点：方向直接　问题：中心过强、边角割裂、南区两块障碍形成长绕行", font=font(15), fill=COLORS["muted"])
    draw.text((828, 145), "草案 A｜环形四区 + 中央活动场", font=font(24), fill=COLORS["text"])
    draw.text((828, 181), "目标：路线有选择但不迷路；每 8–12 秒遇到一个清晰地标；适合 2–3 分钟展会体验", font=font(15), fill=COLORS["muted"])

    draw_current_map(draw, (108, 216), 5.45)
    draw_proposed_map(draw, (870, 216), 5.45)
    draw.rounded_rectangle((83, 611, 700, 648), radius=18, fill=COLORS["bg"])
    draw.text((102, 618), "观察：宝箱点覆盖均匀，但路线体验主要是从中心沿直线走到外围。", font=font(15), fill=COLORS["muted"])
    draw.rounded_rectangle((831, 611, 1516, 648), radius=18, fill=COLORS["bg"])
    draw.text((850, 618), "1 中央活动场　2 水景记忆点　3 林地捷径　4 南门缓冲区", font=font(15), fill=COLORS["muted"])

    draw.text((64, 697), "请你先拍板 4 件事", font=font(24), fill=COLORS["text"])
    draw.text((64, 735), "直接回复“1A、2B、3A、4保留湖”即可；也可以在图上描述你想移动的区域。", font=font(15), fill=COLORS["muted"])

    draw_card(draw, 48, COLORS["gold"], 1, "路线骨架", ["A　环形主路（草案，推荐）", "B　保留十字轴，仅重排建筑", "C　更自由、更多岔路的探索型"], "影响：迷路概率 / 路线重复感")
    draw_card(draw, 430, COLORS["lake"], 2, "探索难度", ["A　轻松：主路一眼能懂", "B　适中：地标之间有小绕路", "C　挑战：建筑后方藏点更多"], "建议展会短局选 B")
    draw_card(draw, 812, COLORS["orange"], 3, "视觉气质", ["A　校园花园：湖、树、花坛为主", "B　科技节：广场、展台、导视为主", "C　两者各半"], "影响：后续需要新增哪些美术素材")
    draw_card(draw, 1194, COLORS["roof"], 4, "必须保留", ["告诉我哪些不能动：", "湖 / 教学楼 / 凉亭 / 中央广场", "或是否要贴近真实校园平面"], "这会决定草案 A 的下一轮形状")

    draw.text((48, 980), "设计原则：不改变 96×72 尺寸与 40 个候选点数量；最终仍会做可达性、净空和碰撞测试。", font=font(13), fill=COLORS["dim"])
    image.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
