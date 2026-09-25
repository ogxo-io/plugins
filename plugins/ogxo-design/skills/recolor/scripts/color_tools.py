#!/usr/bin/env python3
"""Color math for the recolor skill: WCAG contrast, CVD simulation, OKLCH ramps.

Stdlib only. All values computed, never estimated.

Usage:
    color_tools.py check FG BG [--large] [--ui]
        Contrast ratio + WCAG 2.2 AA/AAA verdicts for one pair.
    color_tools.py matrix PAIRS.json
        Verdict table for a list of pairs:
        [{"fg": "#111", "bg": "#fff", "role": "body text", "large": false}, ...]
    color_tools.py cvd FG BG
        Contrast + OKLab distance under protanopia/deuteranopia/tritanopia.
    color_tools.py ramp HEX [--name primary]
        Tailwind-style 50-950 tonal ramp from a seed color, OKLCH-based,
        gamut-clamped. A starting point to hand-tune, not a final palette.

Exit code 1 when any checked pair fails its AA target.
"""

import json
import re
import sys

# ---------- sRGB <-> linear ----------

def parse_hex(value):
    value = value.strip().lstrip("#")
    if re.fullmatch(r"[0-9a-fA-F]{3}", value):
        value = "".join(ch * 2 for ch in value)
    if not re.fullmatch(r"[0-9a-fA-F]{6}", value):
        raise ValueError(f"not a hex color: #{value}")
    return tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def to_hex(rgb):
    return "#" + "".join(f"{round(max(0.0, min(1.0, c)) * 255):02x}" for c in rgb)


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_srgb(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055


def linearize(rgb):
    return tuple(srgb_to_linear(c) for c in rgb)


# ---------- WCAG contrast ----------

def luminance(rgb):
    r, g, b = linearize(rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(fg, bg):
    lighter, darker = sorted((luminance(fg), luminance(bg)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def verdict(ratio, large=False, ui=False):
    if ui:
        return {"AA": ratio >= 3.0, "AAA": ratio >= 3.0}
    if large:
        return {"AA": ratio >= 3.0, "AAA": ratio >= 4.5}
    return {"AA": ratio >= 4.5, "AAA": ratio >= 7.0}


# ---------- OKLab / OKLCH (Bjorn Ottosson's reference formulas) ----------

def linear_to_oklab(rgb):
    r, g, b = rgb
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = l ** (1 / 3), m ** (1 / 3), s ** (1 / 3)
    return (
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    )


def oklab_to_linear(lab):
    L, a, b = lab
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (
        +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )


def srgb_to_oklch(rgb):
    import math
    L, a, b = linear_to_oklab(linearize(rgb))
    return L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360


def oklch_to_srgb(L, C, h):
    """Returns sRGB tuple or None when out of gamut."""
    import math
    a, b = C * math.cos(math.radians(h)), C * math.sin(math.radians(h))
    lin = oklab_to_linear((L, a, b))
    if any(c < -0.0001 or c > 1.0001 for c in lin):
        return None
    return tuple(linear_to_srgb(c) for c in lin)


def clamp_chroma(L, C, h):
    """Binary-search the largest in-gamut chroma <= C for this L and hue."""
    if oklch_to_srgb(L, C, h) is not None:
        return C
    lo, hi = 0.0, C
    for _ in range(32):
        mid = (lo + hi) / 2
        if oklch_to_srgb(L, mid, h) is not None:
            lo = mid
        else:
            hi = mid
    return lo


def oklab_distance(rgb1, rgb2):
    a = linear_to_oklab(linearize(rgb1))
    b = linear_to_oklab(linearize(rgb2))
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


# ---------- CVD simulation (Machado et al. 2009, severity 1.0, linear RGB) ----------

CVD_MATRICES = {
    "protanopia": ((0.152286, 1.052583, -0.204868),
                   (0.114503, 0.786281, 0.099216),
                   (-0.003882, -0.048116, 1.051998)),
    "deuteranopia": ((0.367322, 0.860646, -0.227968),
                     (0.280085, 0.672501, 0.047413),
                     (-0.011820, 0.042940, 0.968881)),
    "tritanopia": ((1.255528, -0.076749, -0.178779),
                   (-0.078411, 0.930809, 0.147602),
                   (0.004733, 0.691367, 0.303900)),
}


def simulate_cvd(rgb, kind):
    lin = linearize(rgb)
    mat = CVD_MATRICES[kind]
    sim = tuple(max(0.0, min(1.0, sum(m * c for m, c in zip(row, lin)))) for row in mat)
    return tuple(linear_to_srgb(c) for c in sim)


# ---------- commands ----------

def fmt_pair(fg, bg, role="", large=False, ui=False):
    ratio = contrast(fg, bg)
    v = verdict(ratio, large, ui)
    kind = "ui" if ui else ("large" if large else "normal")
    aa = "PASS" if v["AA"] else "FAIL"
    aaa = "PASS" if v["AAA"] else "FAIL"
    label = f"  ({role})" if role else ""
    line = f"{to_hex(fg)} on {to_hex(bg)}  {ratio:5.2f}:1  [{kind}]  AA:{aa}  AAA:{aaa}{label}"
    return line, v["AA"]


def cmd_check(args):
    large, ui = "--large" in args, "--ui" in args
    args = [a for a in args if not a.startswith("--")]
    line, ok = fmt_pair(parse_hex(args[0]), parse_hex(args[1]), large=large, ui=ui)
    print(line)
    return 0 if ok else 1


def cmd_matrix(args):
    with open(args[0], encoding="utf-8") as fh:
        pairs = json.load(fh)
    failed = 0
    for p in pairs:
        line, ok = fmt_pair(parse_hex(p["fg"]), parse_hex(p["bg"]),
                            role=p.get("role", ""), large=p.get("large", False),
                            ui=p.get("ui", False))
        print(line)
        failed += 0 if ok else 1
    print(f"\n{len(pairs) - failed}/{len(pairs)} pairs pass their AA target")
    return 0 if failed == 0 else 1


def cmd_cvd(args):
    fg, bg = parse_hex(args[0]), parse_hex(args[1])
    print(f"original      {to_hex(fg)} on {to_hex(bg)}  "
          f"contrast {contrast(fg, bg):5.2f}:1  dE-OK {oklab_distance(fg, bg):.3f}")
    hard = []
    for kind in CVD_MATRICES:
        sf, sb = simulate_cvd(fg, kind), simulate_cvd(bg, kind)
        d = oklab_distance(sf, sb)
        flag = "  <-- hard to distinguish" if d < 0.06 else ""
        if flag:
            hard.append(kind)
        print(f"{kind:<13} {to_hex(sf)} on {to_hex(sb)}  "
              f"contrast {contrast(sf, sb):5.2f}:1  dE-OK {d:.3f}{flag}")
    if hard:
        print(f"\nWARNING: pair needs a non-color cue for: {', '.join(hard)}")
    return 1 if hard else 0


# Lightness targets per step, matched to Tailwind v4's OKLCH palettes.
RAMP_STEPS = ((50, 0.97), (100, 0.93), (200, 0.88), (300, 0.81), (400, 0.71),
              (500, 0.62), (600, 0.55), (700, 0.49), (800, 0.42), (900, 0.38),
              (950, 0.28))


def cmd_ramp(args):
    name = "color"
    if "--name" in args:
        name = args[args.index("--name") + 1]
    seed = parse_hex(args[0])
    seed_l, seed_c, seed_h = srgb_to_oklch(seed)
    nearest = min(RAMP_STEPS, key=lambda s: abs(s[1] - seed_l))
    print(f"seed {to_hex(seed)} = oklch({seed_l:.3f} {seed_c:.3f} {seed_h:.1f})"
          f"  (closest step: {name}-{nearest[0]})")
    for step, L in RAMP_STEPS:
        # Chroma tapers toward both ends of the ramp; peak stays near the seed.
        taper = 1.0 - 0.72 * abs(L - seed_l) / max(seed_l, 1.0 - seed_l)
        C = clamp_chroma(L, seed_c * max(taper, 0.15), seed_h)
        rgb = oklch_to_srgb(L, C, seed_h)
        print(f"  --{name}-{step}: {to_hex(rgb)};   /* oklch({L:.3f} {C:.3f} {seed_h:.1f}) */")
    return 0


def main():
    commands = {"check": cmd_check, "matrix": cmd_matrix, "cvd": cmd_cvd, "ramp": cmd_ramp}
    if len(sys.argv) < 3 or sys.argv[1] not in commands:
        print(__doc__.strip())
        return 2
    try:
        return commands[sys.argv[1]](sys.argv[2:])
    except (ValueError, OSError, KeyError, IndexError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
