"""Test semua debug images dengan SAHI v2 - cek mana yang detect ayam/cabai"""
import sys, os, time
sys.path.insert(0, os.path.dirname(__file__))

from PIL import Image
from ultralytics import YOLO
import logging
logging.getLogger("ultralytics").setLevel(logging.WARNING)

MODEL_PATH = os.path.join(os.path.dirname(__file__), '..', 'assets', 'models', 'best.pt')
model = YOLO(MODEL_PATH)

from detect_server import run_inference

DEBUG_DIR = os.path.join(os.path.dirname(__file__), '..', 'uploads', 'debug')
images = sorted([f for f in os.listdir(DEBUG_DIR) if f.endswith('.jpg')])

# Test pada gambar terakhir - inference pada SETIAP tile secara individual
test_img = os.path.join(DEBUG_DIR, images[-1])
img = Image.open(test_img)
w, h = img.size
print(f"Image: {w}x{h}")

print(f"\n{'='*50}")
print("Per-tile analysis (mana tile yang detect ayam/cabai?)")
print(f"{'='*50}")

TILE_SIZE = 512
STRIDE = 384

# Juga test full image di beberapa resolusi 
for imgsz in [512, 640, 1024]:
    dets = run_inference(img, conf=0.15, imgsz=imgsz)
    labels = [f"{d['label']}({d['confidence']:.0%})" for d in dets]
    print(f"\nFull image @ imgsz={imgsz}: {labels}")

print(f"\n--- Individual tiles @ conf=0.15 ---")
tile_idx = 0
for y in range(0, h, STRIDE):
    for x in range(0, w, STRIDE):
        x2 = min(x + TILE_SIZE, w)
        y2 = min(y + TILE_SIZE, h)
        if (x2 - x) < TILE_SIZE * 0.6 or (y2 - y) < TILE_SIZE * 0.6:
            continue
        
        tile = img.crop((x, y, x2, y2))
        dets = run_inference(tile, conf=0.15, imgsz=TILE_SIZE)
        
        if dets:
            labels = [f"{d['label']}({d['confidence']:.0%})" for d in dets]
            print(f"  Tile [{x}:{x2}, {y}:{y2}]: {labels}")
        tile_idx += 1

print(f"\nTotal tiles: {tile_idx}")
