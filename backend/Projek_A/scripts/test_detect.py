"""
SmartCooks AI Diagnostic Tool
Menguji model YOLO secara langsung tanpa melalui Flutter/Node.js pipeline.
Ini akan mengungkap apakah masalah ada di model atau di pipeline.
"""
import sys
import os
import json
from PIL import Image, ImageOps, ImageDraw, ImageFont, ExifTags

# Path model
MODEL_PATH = os.path.join(os.path.dirname(__file__), '..', 'assets', 'models', 'best.pt')

def get_exif_data(img):
    """Ambil semua data EXIF yang relevan"""
    exif_info = {}
    try:
        exif_data = img._getexif()
        if exif_data:
            for tag_id, value in exif_data.items():
                tag = ExifTags.TAGS.get(tag_id, tag_id)
                if tag in ('Orientation', 'ImageWidth', 'ImageLength', 'Make', 'Model'):
                    exif_info[tag] = value
    except Exception as e:
        exif_info['error'] = str(e)
    return exif_info

def test_image(image_path, model):
    """Test satu gambar dengan diagnostik penuh"""
    print(f"\n{'='*60}")
    print(f"[DIAGNOSA] File: {image_path}")
    print(f"{'='*60}")

    if not os.path.exists(image_path):
        print(f"  ❌ File tidak ditemukan!")
        return

    # 1. File info
    file_size = os.path.getsize(image_path)
    print(f"  📁 Ukuran file: {file_size:,} bytes ({file_size/1024:.1f} KB)")

    # 2. Buka gambar
    img_raw = Image.open(image_path)
    print(f"  📐 Dimensi RAW (sebelum EXIF): {img_raw.size[0]}x{img_raw.size[1]}")
    print(f"  🎨 Mode: {img_raw.mode}")
    print(f"  📄 Format: {img_raw.format}")

    # 3. EXIF data
    exif = get_exif_data(img_raw)
    print(f"  📋 EXIF: {json.dumps(exif, indent=4, default=str)}")

    # 4. EXIF Transpose
    img = ImageOps.exif_transpose(img_raw)
    print(f"  📐 Dimensi SETELAH EXIF transpose: {img.size[0]}x{img.size[1]}")

    # 5. Test inference di berbagai ukuran
    test_configs = [
        {"imgsz": 640, "conf": 0.10, "augment": False, "label": "640 (training size)"},
        {"imgsz": 640, "conf": 0.10, "augment": True,  "label": "640+TTA"},
        {"imgsz": 1024, "conf": 0.10, "augment": False, "label": "1024 (large)"},
        {"imgsz": 1024, "conf": 0.10, "augment": True,  "label": "1024+TTA"},
    ]

    import time
    for cfg in test_configs:
        start = time.time()
        results = model(
            img,
            verbose=False,
            conf=cfg["conf"],
            iou=0.45,
            imgsz=cfg["imgsz"],
            augment=cfg["augment"],
            max_det=20,
        )
        elapsed = time.time() - start

        detections = []
        for r in results:
            for box in r.boxes:
                conf_val = float(box.conf[0])
                cls_idx = int(box.cls[0])
                label = model.names[cls_idx]
                detections.append(f"{label}({conf_val:.0%})")

        print(f"\n  🔍 [{cfg['label']}] → {len(detections)} objek ({elapsed:.2f}s)")
        if detections:
            for d in detections:
                print(f"     ✅ {d}")
        else:
            print(f"     ❌ Tidak ada deteksi!")

    print(f"\n{'='*60}\n")


if __name__ == '__main__':
    print("Memuat model YOLO...")
    from ultralytics import YOLO
    import logging
    logging.getLogger("ultralytics").setLevel(logging.WARNING)

    model = YOLO(MODEL_PATH)
    print(f"Model dimuat: {MODEL_PATH}")
    print(f"Classes: {model.names}")

    # Test dengan gambar yang ada di uploads/ atau dari argumen
    if len(sys.argv) > 1:
        for path in sys.argv[1:]:
            test_image(path, model)
    else:
        # Cari gambar di uploads/
        uploads_dir = os.path.join(os.path.dirname(__file__), '..', 'uploads')
        images = [f for f in os.listdir(uploads_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
        if images:
            for img_file in images:
                test_image(os.path.join(uploads_dir, img_file), model)
        else:
            print("Tidak ada gambar di uploads/. Berikan path gambar sebagai argumen:")
            print(f"  python {sys.argv[0]} path/to/image.jpg")
