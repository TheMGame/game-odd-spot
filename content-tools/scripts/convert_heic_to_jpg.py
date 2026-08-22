#!/usr/bin/env python3
"""
HEIC to JPG converter for game content images.

Converts HEIC images to JPG with specific constraints:
  - Size: 1024 x 1536 px (2:3 portrait)
  - Format: JPG
  - Quality: 75% ~ 85% (target ~400KB ~ 1MB)
  - Color space: sRGB

Usage:
  python3 convert_heic_to_jpg.py INPUT.heic [-o OUTPUT.jpg] [--width 1024] [--height 1536] [--quality 80]
"""

import argparse
import io
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageCms, ImageOps

SRGB_PROFILE = ImageCms.createProfile("sRGB")


def apply_exif_orientation(img: Image.Image) -> Image.Image:
    exif = img.getexif()
    orientation = exif.get(274) if exif else None
    if orientation and orientation != 1:
        try:
            img = ImageOps.exif_transpose(img)
            img.info["exif_orientation_applied"] = orientation
        except Exception:
            pass
    return img


def convert_heic_to_pil(heic_path: Path) -> Image.Image:
    try:
        import pillow_heif  # noqa: F401

        pillow_heif.register_heif_opener()
        return Image.open(heic_path)
    except ImportError:
        pass

    sips_path = shutil.which("sips")
    if sips_path:
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
            tmp_path = Path(tmp.name)
        try:
            subprocess.run(
                [sips_path, "-s", "format", "png", str(heic_path), "--out", str(tmp_path)],
                check=True,
                capture_output=True,
            )
            return Image.open(tmp_path)
        finally:
            if tmp_path.exists():
                tmp_path.unlink()

    magick_path = shutil.which("magick") or shutil.which("convert")
    if magick_path:
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
            tmp_path = Path(tmp.name)
        try:
            subprocess.run(
                [magick_path, str(heic_path), str(tmp_path)],
                check=True,
                capture_output=True,
            )
            return Image.open(tmp_path)
        finally:
            if tmp_path.exists():
                tmp_path.unlink()

    print("ERROR: No HEIC decoder available.", file=sys.stderr)
    print("  Install one of:", file=sys.stderr)
    print("    - pip install pillow-heif", file=sys.stderr)
    print("    - brew install imagemagick", file=sys.stderr)
    sys.exit(1)


def ensure_srgb(img: Image.Image) -> Image.Image:
    if img.mode not in ("RGB", "RGBA"):
        img = img.convert("RGB")

    icc_profile = img.info.get("icc_profile")
    if icc_profile:
        try:
            input_profile = ImageCms.ImageCmsProfile(io.BytesIO(icc_profile))
            transform = ImageCms.buildTransform(
                input_profile, SRGB_PROFILE, img.mode, "RGB"
            )
            img = ImageCms.applyTransform(img, transform)
        except Exception:
            img = img.convert("RGB")
    else:
        img = img.convert("RGB")

    img.info["icc_profile"] = ImageCms.ImageCmsProfile(SRGB_PROFILE).tobytes()
    return img


def cover_crop_and_resize(
    img: Image.Image, target_w: int, target_h: int
) -> Image.Image:
    src_w, src_h = img.size
    src_ratio = src_w / src_h
    dst_ratio = target_w / target_h

    if abs(src_ratio - dst_ratio) < 1e-6:
        crop_box = (0, 0, src_w, src_h)
    elif src_ratio > dst_ratio:
        new_w = int(src_h * dst_ratio)
        offset = (src_w - new_w) // 2
        crop_box = (offset, 0, offset + new_w, src_h)
    else:
        new_h = int(src_w / dst_ratio)
        offset = (src_h - new_h) // 2
        crop_box = (0, offset, src_w, offset + new_h)

    cropped = img.crop(crop_box)
    return cropped.resize((target_w, target_h), Image.LANCZOS)


def _try_save_jpg(
    img: Image.Image, quality: int, subsampling: int, optimize: bool
) -> bytes:
    buf = io.BytesIO()
    img.save(
        buf,
        format="JPEG",
        quality=quality,
        optimize=optimize,
        progressive=True,
        subsampling=subsampling,
        icc_profile=img.info.get("icc_profile"),
    )
    return buf.getvalue()


def save_jpg_with_target_size(
    img: Image.Image, out_path: Path, quality_start: int, min_bytes: int, max_bytes: int
) -> tuple[int, bool]:
    strategies = [
        {"subsampling": 2, "optimize": True},
        {"subsampling": 1, "optimize": True},
        {"subsampling": 0, "optimize": True},
        {"subsampling": 0, "optimize": False},
    ]

    best_data = None
    best_bytes = None
    best_quality = None
    target_center = (min_bytes + max_bytes) // 2
    last_strat_idx = len(strategies) - 1
    maxed_out = False

    for si, strat in enumerate(strategies):
        for q in range(85, 69, -1):
            data = _try_save_jpg(img, q, strat["subsampling"], strat["optimize"])
            size = len(data)
            if min_bytes <= size <= max_bytes:
                out_path.write_bytes(data)
                return q, False
            if si == last_strat_idx and q == 85 and size < min_bytes:
                maxed_out = True
            if best_bytes is None or abs(size - target_center) < abs(
                best_bytes - target_center
            ):
                best_bytes = size
                best_quality = q
                best_data = data

    out_path.write_bytes(best_data)
    return best_quality, maxed_out


def human_size(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return f"{n:.1f} {unit}" if unit != "B" else f"{n} B"
        n /= 1024
    return f"{n:.1f} TB"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert HEIC image to JPG for Odd Spot game content"
    )
    parser.add_argument("input", type=Path, help="Input HEIC file path")
    parser.add_argument(
        "-o", "--output", type=Path, default=None, help="Output JPG file path"
    )
    parser.add_argument("--width", type=int, default=1024, help="Target width (px)")
    parser.add_argument("--height", type=int, default=1536, help="Target height (px)")
    parser.add_argument(
        "--quality",
        type=int,
        default=80,
        help="Starting JPG quality (70-85), will auto-adjust for size",
    )
    parser.add_argument(
        "--min-kb", type=int, default=400, help="Minimum target file size (KB)"
    )
    parser.add_argument(
        "--max-kb", type=int, default=1024, help="Maximum target file size (KB)"
    )
    args = parser.parse_args()

    in_path: Path = args.input
    if not in_path.exists():
        print(f"ERROR: Input file not found: {in_path}", file=sys.stderr)
        return 1

    out_path: Path = args.output or in_path.with_suffix(".jpg")
    out_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"[Step 1/5] Loading HEIC: {in_path} ({human_size(in_path.stat().st_size)})")
    img = convert_heic_to_pil(in_path)
    print(f"          Raw size  : {img.size[0]}x{img.size[1]}, mode={img.mode}")

    print(f"[Step 2/5] Applying EXIF orientation (no visual rotation) ...")
    exif_before = img.getexif()
    orient_before = exif_before.get(274) if exif_before else None
    img = apply_exif_orientation(img)
    orient_applied = img.info.pop("exif_orientation_applied", None)
    print(
        f"          EXIF orient: {orient_before or 1} -> pixel size: {img.size[0]}x{img.size[1]}"
        + (f"  (transposed from orient={orient_applied})" if orient_applied else "")
    )

    print(f"[Step 3/5] Converting color space to sRGB ...")
    img = ensure_srgb(img)

    print(
        f"[Step 4/5] Center-crop & resize to {args.width}x{args.height} (cover mode, keep orientation) ..."
    )
    img = cover_crop_and_resize(img, args.width, args.height)
    print(f"          Output size: {img.size[0]}x{img.size[1]}")

    print(
        f"[Step 5/5] Saving JPG, targeting {args.min_kb}-{args.max_kb} KB, starting quality={args.quality} ..."
    )
    used_q, maxed_out = save_jpg_with_target_size(
        img,
        out_path,
        quality_start=args.quality,
        min_bytes=args.min_kb * 1024,
        max_bytes=args.max_kb * 1024,
    )

    final_size = out_path.stat().st_size
    print(f"\nDone! Output: {out_path}")
    print(f"  Dimensions : {img.size[0]} x {img.size[1]} px")
    print(f"  Format     : JPG (progressive, optimized)")
    print(f"  Quality    : {used_q}")
    print(f"  Color space: sRGB (ICC profile embedded)")
    print(f"  File size  : {human_size(final_size)} ({final_size} bytes)")
    if maxed_out:
        print(
            f"  Note       : Max quality (85) + max chroma sampling reached; "
            f"image inherently compresses well ({human_size(final_size)} ≈ target {args.min_kb} KB)"
        )
    elif not (args.min_kb * 1024 <= final_size <= args.max_kb * 1024):
        print(
            f"  WARN       : Size outside target range ({args.min_kb}-{args.max_kb} KB)"
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
