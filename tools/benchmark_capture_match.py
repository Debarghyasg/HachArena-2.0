#!/usr/bin/env python3
"""
Benchmark the capture ↔ reference YOLO match latency on THIS server's hardware.

This is the main latency risk in the checkout-capture pipeline, so measure it
early on the target machine. Each iteration runs YOLO on TWO images (the
captured checkout frame + the SKU reference image), exactly like production
(api/main.py :: score_capture_match).

Usage:
    python tools/benchmark_capture_match.py                     # synthetic 640x640, 30 runs
    python tools/benchmark_capture_match.py --n 50 --size 640
    python tools/benchmark_capture_match.py --model api/AI_Model/best_final.pt \
        --checkout store-data/checkout-captures/1/CAP-123.jpg \
        --reference store-data/reference-images/1/8901030823437.jpg

Interpreting the result:
  - The match runs FIRE-AND-FORGET off the checkout critical path, so it does
    not block the cashier. Still, keep it well under a second so the audit
    score is available promptly and the box isn't saturated at peak scan rate.
  - Rule of thumb: p95 < ~250 ms on CPU is comfortable; if it's higher, use a
    smaller model (e.g. yolov8n/yolov10n), reduce --size (imgsz), or add a GPU.

Requires ultralytics + opencv installed (same deps as the FastAPI engine).
"""
import argparse
import math
import os
import sys
import time


def _percentile(sorted_vals, p):
    if not sorted_vals:
        return 0.0
    idx = min(len(sorted_vals) - 1, int(math.ceil(p / 100 * len(sorted_vals))) - 1)
    return round(sorted_vals[idx], 1)


def main():
    ap = argparse.ArgumentParser(description="Benchmark capture↔reference YOLO match latency.")
    ap.add_argument("--model", default=os.path.join("api", "AI_Model", "best_final.pt"),
                    help="Path to YOLO weights (falls back to yolov8n.pt).")
    ap.add_argument("--n", type=int, default=30, help="Number of timed iterations.")
    ap.add_argument("--size", type=int, default=640, help="Synthetic image size (ignored if --checkout/--reference given).")
    ap.add_argument("--checkout", default=None, help="Optional real captured image path.")
    ap.add_argument("--reference", default=None, help="Optional real reference image path.")
    ap.add_argument("--target-p95-ms", type=float, default=250.0, help="Pass/fail threshold for the p95 verdict.")
    args = ap.parse_args()

    try:
        import cv2
        import numpy as np
        from ultralytics import YOLO
        from rapidfuzz import fuzz
    except Exception as e:
        print(f"✗ Missing deps ({e}). Install: pip install ultralytics opencv-python rapidfuzz numpy")
        sys.exit(2)

    model_path = args.model if os.path.exists(args.model) else "yolov8n.pt"
    print(f"Loading model: {model_path}")
    model = YOLO(model_path)

    def _make_img(path, fallback_size):
        if path and os.path.exists(path):
            img = cv2.imread(path)
            if img is not None:
                return img
            print(f"⚠  could not read {path} — using synthetic image")
        return np.random.randint(0, 255, (fallback_size, fallback_size, 3), dtype=np.uint8)

    checkout_img = _make_img(args.checkout, args.size)
    reference_img = _make_img(args.reference, args.size)

    def _top(img):
        res = model(img, verbose=False)
        dets = [(model.names[int(b.cls)], float(b.conf)) for r in res for b in r.boxes]
        dets.sort(key=lambda d: d[1], reverse=True)
        return dets[0] if dets else None

    def _score():
        ck, rf = _top(checkout_img), _top(reference_img)
        if not ck or not rf:
            return None
        label_sim = max(fuzz.ratio(ck[0].lower(), rf[0].lower()),
                        fuzz.token_set_ratio(ck[0].lower(), rf[0].lower())) / 100.0
        return round(label_sim * math.sqrt(ck[1] * rf[1]), 3)

    # Warm-up (first inference pays a one-off init cost — exclude from timings).
    print("Warming up…")
    _score()

    print(f"Timing {args.n} iterations (2 images each)…")
    lat = []
    last_score = None
    for _ in range(args.n):
        t0 = time.perf_counter()
        last_score = _score()
        lat.append((time.perf_counter() - t0) * 1000)
    lat.sort()

    mean = round(sum(lat) / len(lat), 1)
    p50, p95 = _percentile(lat, 50), _percentile(lat, 95)
    print("\n── Capture↔Reference match latency ─────────────────────────")
    print(f"  model      : {model_path}")
    print(f"  iterations : {args.n}")
    print(f"  sample score: {last_score}")
    print(f"  mean       : {mean} ms")
    print(f"  p50        : {p50} ms")
    print(f"  p95        : {p95} ms")
    print(f"  min / max  : {round(lat[0],1)} / {round(lat[-1],1)} ms")
    verdict = "PASS ✅" if p95 <= args.target_p95_ms else "REVIEW ⚠"
    print(f"  p95 vs {args.target_p95_ms}ms target: {verdict}")
    print("────────────────────────────────────────────────────────────")


if __name__ == "__main__":
    main()
