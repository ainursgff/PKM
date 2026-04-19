import sys
import os
import json
import time
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from PIL import Image, ImageOps
from ultralytics import YOLO

# Matikan log spam dari ultralytics
logging.getLogger("ultralytics").setLevel(logging.WARNING)

# Directory untuk simpan debug image
DEBUG_DIR = os.path.join(os.path.dirname(__file__), '..', 'uploads', 'debug')
os.makedirs(DEBUG_DIR, exist_ok=True)

print("AI Daemon: Memuat PyTorch Model ke RAM...")
try:
    model_path = sys.argv[1] if len(sys.argv) > 1 else 'assets/models/best.pt'
    model = YOLO(model_path)
    print(f"AI Daemon: Model berhasil dimuat! ({model_path})")
    print(f"AI Daemon: Classes: {list(model.names.values())}")
    print(f"AI Daemon: Siap menerima deteksi pada port 5001.")
except Exception as e:
    print(f"Gagal memuat model YOLO: {str(e)}")
    sys.exit(1)


def iou_calc(box1, box2):
    """Hitung IoU antara dua bounding box [x1,y1,x2,y2]"""
    x1 = max(box1[0], box2[0])
    y1 = max(box1[1], box2[1])
    x2 = min(box1[2], box2[2])
    y2 = min(box1[3], box2[3])
    inter = max(0, x2 - x1) * max(0, y2 - y1)
    area1 = (box1[2] - box1[0]) * (box1[3] - box1[1])
    area2 = (box2[2] - box2[0]) * (box2[3] - box2[1])
    union = area1 + area2 - inter
    return inter / union if union > 0 else 0


def nms_cross_class(detections, iou_threshold=0.4):
    """
    Cross-class NMS: Jika dua box APAPUN kelasnya overlap > threshold,
    simpan yang confidence tertinggi, buang yang lain.
    
    Ini menyelesaikan masalah dimana:
    - SAPI 29% dan TERONG 54% overlap pada piring yang sama
    - Dua tile berbeda mendeteksi objek sama sebagai kelas berbeda
    """
    if not detections:
        return []
    detections.sort(key=lambda x: x['confidence'], reverse=True)
    keep = []
    while detections:
        best = detections.pop(0)
        keep.append(best)
        remaining = []
        for det in detections:
            overlap = iou_calc(best['box'], det['box'])
            if overlap > iou_threshold:
                # Suppress: box ini overlap dengan box confidence lebih tinggi
                print(f"  [NMS] Suppress {det['label']}({det['confidence']:.0%}) "
                      f"overlaps {best['label']}({best['confidence']:.0%}) IoU={overlap:.2f}")
                continue
            remaining.append(det)
        detections = remaining
    return keep


def run_inference(img, conf=0.25, imgsz=512):
    """Single-pass inference pada satu gambar/tile"""
    results = model(img, verbose=False, conf=conf, iou=0.45, imgsz=imgsz, max_det=30)
    dets = []
    for r in results:
        for box in r.boxes:
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            conf_val = float(box.conf[0])
            cls_idx = int(box.cls[0])
            label = model.names[cls_idx]
            dets.append({
                "label": label.upper(),
                "confidence": round(conf_val, 4),
                "box": [x1, y1, x2, y2]
            })
    return dets


def sahi_detect(img):
    """
    SAHI: Slicing Aided Hyper Inference — Versi 2 (anti-ghost)
    
    Perubahan dari v1:
    1. Full-image conf dinaikkan ke 0.25 (dari 0.20) → kurangi noise
    2. Tile conf dinaikkan ke 0.30 (dari 0.25) → kurangi ghost dari background
    3. Cross-class NMS → hapus overlap beda kelas (SAPI vs TERONG di area sama)
    4. Post-filter conf minimum 0.25 → hanya tampilkan deteksi yang yakin
    5. Box area filter 2% → hapus box artefak kecil
    """
    w, h = img.size
    all_detections = []

    # ═══════════════════════════════════════════════
    # PASS 1: Full-image inference di 640
    # Menangkap objek besar yang terlihat dalam konteks penuh
    # ═══════════════════════════════════════════════
    full_dets = run_inference(img, conf=0.25, imgsz=640)
    all_detections.extend(full_dets)
    print(f"[SAHI] Pass 1 - Full image (640): {len(full_dets)} dets")

    # ═══════════════════════════════════════════════
    # PASS 2: Tile-based inference di 512 (= training size)
    # Tile 512x512 dengan stride 384 (overlap ~25%)
    # Conf lebih ketat (0.30) karena tile partial sering
    # menghasilkan false positive pada background/edges
    # ═══════════════════════════════════════════════
    TILE_SIZE = 512
    STRIDE = 384  # overlap = (512-384)/512 = 25%
    tile_count = 0

    for y in range(0, h, STRIDE):
        for x in range(0, w, STRIDE):
            x2 = min(x + TILE_SIZE, w)
            y2 = min(y + TILE_SIZE, h)

            # Skip tile terlalu kecil (< 60% tile_size)
            if (x2 - x) < TILE_SIZE * 0.6 or (y2 - y) < TILE_SIZE * 0.6:
                continue

            tile = img.crop((x, y, x2, y2))
            tile_dets = run_inference(tile, conf=0.30, imgsz=TILE_SIZE)

            # Map koordinat tile → koordinat gambar penuh
            for det in tile_dets:
                det['box'][0] += x
                det['box'][1] += y
                det['box'][2] += x
                det['box'][3] += y
                all_detections.append(det)

            tile_count += 1

    print(f"[SAHI] Pass 2 - {tile_count} tiles ({TILE_SIZE}x{TILE_SIZE}): "
          f"{len(all_detections) - len(full_dets)} tile dets")
    print(f"[SAHI] Total raw: {len(all_detections)} detections before NMS")

    # ═══════════════════════════════════════════════
    # PASS 3: Cross-class NMS (agresif)
    # IoU 0.3 → lebih agresif menghapus overlap
    # ═══════════════════════════════════════════════
    merged = nms_cross_class(all_detections, iou_threshold=0.3)
    print(f"[SAHI] After NMS: {len(merged)} detections")

    # ═══════════════════════════════════════════════
    # PASS 4: Post-filter — hapus ghost
    # - Confidence minimum 0.25 (25%)
    # - Box area minimum 2% dari gambar
    # ═══════════════════════════════════════════════
    img_area = w * h
    min_box_area = img_area * 0.02
    filtered = []
    for det in merged:
        bx = det['box']
        box_area = (bx[2] - bx[0]) * (bx[3] - bx[1])
        if det['confidence'] >= 0.25 and box_area >= min_box_area:
            det['box'] = [round(v, 2) for v in det['box']]
            filtered.append(det)
        else:
            reason = []
            if det['confidence'] < 0.25:
                reason.append(f"conf={det['confidence']:.0%}<25%")
            if box_area < min_box_area:
                reason.append(f"area={box_area/img_area:.1%}<2%")
            print(f"  [FILTER] Removed {det['label']}({det['confidence']:.0%}): {', '.join(reason)}")

    return filtered


class DetectionHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_POST(self):
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            req_data = json.loads(post_data.decode('utf-8'))
            image_path = req_data.get("image_path")

            if not image_path:
                self.send_error_resp(400, "image_path tidak ditemukan")
                return

            if not os.path.exists(image_path):
                self.send_error_resp(400, f"File tidak ditemukan: {image_path}")
                return

            # ── Buka & proses gambar ──
            file_size = os.path.getsize(image_path)
            print(f"\n[YOLO] ═══════════════════════════════════")
            print(f"[YOLO] File: {os.path.basename(image_path)} ({file_size/1024:.1f} KB)")

            try:
                img = Image.open(image_path)
                img.load()
            except Exception:
                from PIL import ImageFile
                ImageFile.LOAD_TRUNCATED_IMAGES = True
                img = Image.open(image_path)
                img.load()
                ImageFile.LOAD_TRUNCATED_IMAGES = False
                print(f"[YOLO] ⚠️  Recovered truncated image")

            raw_mode = img.mode
            img = ImageOps.exif_transpose(img)

            if img.mode != 'RGB':
                print(f"[YOLO] Converting {img.mode} → RGB")
                img = img.convert('RGB')

            w, h = img.size
            print(f"[YOLO] Image: {w}x{h} (was {raw_mode})")

            # Simpan debug image
            debug_path = os.path.join(DEBUG_DIR, f"debug_{int(time.time())}.jpg")
            img.save(debug_path, quality=95)

            # ── SAHI Detection v2 ──
            start = time.time()
            detections = sahi_detect(img)
            elapsed = time.time() - start

            labels = [f"{d['label']}({d['confidence']:.0%})" for d in detections]
            print(f"[YOLO] ✅ FINAL: {len(detections)} objects in {elapsed:.1f}s: {labels}")
            print(f"[YOLO] ═══════════════════════════════════\n")

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(detections).encode('utf-8'))

        except Exception as e:
            import traceback
            print(f"[YOLO] ❌ ERROR: {str(e)}")
            traceback.print_exc()
            self.send_error_resp(500, str(e))

    def send_error_resp(self, code, msg):
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({"error": msg}).encode('utf-8'))


if __name__ == '__main__':
    port = 5001
    server_address = ('127.0.0.1', port)
    httpd = HTTPServer(server_address, DetectionHandler)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
