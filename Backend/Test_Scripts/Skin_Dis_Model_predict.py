#!/usr/bin/env python3
import os
import json
import sys
import numpy as np
import torch
from torch import nn
from torchvision import transforms, models
from PIL import Image

# -----------------------------
# HARD-CODED SETTINGS (strings)
# -----------------------------
ROOT_DIR   = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.join(ROOT_DIR, "Skin_dis_Models")

MODEL_PATH   = os.path.join(MODELS_DIR, "best_model.pth")
LABELS_TXT   = os.path.join(MODELS_DIR, "labels.txt")
IMAGE_PATH   = "test.jpg"
IMG_SIZE     = 384
THRESHOLD    = 0.30
TOPK_PRINT   = 25
SAVE_JSON_TO = "result.json"
DO_SKIN_EST  = True

SAVE_JSON_TO = os.path.join(ROOT_DIR, "skin_type_result.json")
# -----------------------------
# Model & transforms
# -----------------------------
def build_model(n_classes: int):
    model = models.resnet50(weights=None)
    in_feats = model.fc.in_features
    model.fc = nn.Linear(in_feats, n_classes)
    return model

def _read_labels_from_txt(path_str):
    try:
        with open(path_str, "r", encoding="utf-8") as f:
            return [l.strip() for l in f.readlines() if l.strip()]
    except Exception:
        return None

def load_checkpoint(model_path_str, device, labels_txt_str=None):
    ckpt = torch.load(model_path_str, map_location=device)

    if isinstance(ckpt, dict) and "state_dict" in ckpt:
        state_dict = ckpt["state_dict"]
        label_cols = ckpt.get("label_cols", None)
    else:
        state_dict = ckpt
        label_cols = None

    if label_cols is None and labels_txt_str and os.path.isfile(labels_txt_str):
        label_cols = _read_labels_from_txt(labels_txt_str)

    if label_cols is not None:
        n_classes = len(label_cols)
    else:
        out = None
        for k, v in state_dict.items():
            if k.endswith("fc.weight"):
                out = v.shape[0]
                break
        if out is None:
            raise RuntimeError("Could not infer number of classes; provide labels.txt or ensure fc.weight exists in state_dict")
        n_classes = int(out)
        label_cols = [f"Label_{i}" for i in range(n_classes)]

    model = build_model(n_classes)
    model.load_state_dict(state_dict, strict=True)
    model.to(device).eval()
    return model, label_cols

def get_transforms(img_size=384):
    return transforms.Compose([
        transforms.Resize((img_size, img_size)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485,0.456,0.406], std=[0.229,0.224,0.225]),
    ])

def predict_image(image_path_str, model, device, label_names, img_size=384):
    tfm = get_transforms(img_size)
    with Image.open(image_path_str).convert("RGB") as im:
        x = tfm(im).unsqueeze(0).to(device)

    with torch.no_grad():
        logits = model(x)
        probs = torch.sigmoid(logits)[0].detach().cpu().numpy()

    results = [(label_names[i], float(probs[i])) for i in range(len(label_names))]
    results.sort(key=lambda z: -z[1])
    return results

def filter_by_threshold(results, threshold: float):
    return [(n, p) for (n, p) in results if p >= threshold]

def estimate_fitzpatrick_rough(image_path_str):
    """Very rough, heuristic Fitzpatrick-like 1..6 guess. Requires OpenCV. Returns dict or None."""
    try:
        import cv2
        import numpy as np
    except Exception:
        return None

    bgr = cv2.imread(image_path_str)
    if bgr is None:
        return None
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)

    lower1 = np.array([0, 30, 50], dtype=np.uint8)
    upper1 = np.array([25,255,255], dtype=np.uint8)
    mask1  = cv2.inRange(hsv, lower1, upper1)

    lower2 = np.array([160,30,50], dtype=np.uint8)
    upper2 = np.array([179,255,255], dtype=np.uint8)
    mask2  = cv2.inRange(hsv, lower2, upper2)

    mask = cv2.bitwise_or(mask1, mask2)
    lab  = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB)
    L    = lab[:,:,0][mask>0]
    if L.size == 0:
        L = lab[:,:,0].reshape(-1)
    meanL = float(np.mean(L))

    bins = [60, 80, 100, 130, 160]
    fitz = 1
    for b in bins:
        if meanL > b:
            fitz += 1
    fitz = int(min(fitz, 6))
    return {"estimated_fitzpatrick": fitz, "mean_L": meanL}

def to_json_dict(image_path_str, all_results, detected, threshold, skin_info=None):
    return {
        "image": image_path_str,
        "threshold": threshold,
        "predictions_sorted": [{"label": n, "prob": round(p, 6)} for n, p in all_results],
        "detected": [{"label": n, "prob": round(p, 6)} for n, p in detected],
        "skin_estimate": skin_info,
    }

# -----------------------------
# Main (no args)
# -----------------------------
def main():
    if not os.path.isfile(MODEL_PATH):
        print(f"[ERROR] Model not found at {MODEL_PATH}", file=sys.stderr)
        sys.exit(1)
    if not os.path.isfile(IMAGE_PATH):
        print(f"[ERROR] Image not found at {IMAGE_PATH}", file=sys.stderr)
        sys.exit(1)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    torch.set_grad_enabled(False)

    model, label_names = load_checkpoint(MODEL_PATH, device, labels_txt_str=LABELS_TXT)
    all_results = predict_image(IMAGE_PATH, model, device, label_names, img_size=IMG_SIZE)
    detected = filter_by_threshold(all_results, THRESHOLD)

    skin_info = estimate_fitzpatrick_rough(IMAGE_PATH) if DO_SKIN_EST else None

    print(f"\nImage:  {IMAGE_PATH}")
    print(f"Device: {device}")
    if skin_info:
        print(f"Rough skin-tone estimate (Fitz 1–6): {skin_info.get('estimated_fitzpatrick')} "
              f"(mean L* ~ {skin_info.get('mean_L'):.1f})")

    print("\nAll concerns (sorted by probability):")
    to_show = all_results if TOPK_PRINT is None else all_results[:TOPK_PRINT]
    for n, p in to_show:
        print(f"  {n:28s} {p:.3f}")

    print(f"\nDetected (>= {THRESHOLD:.2f}):")
    if not detected:
        print("  (none)")
    else:
        for n, p in detected:
            print(f"  {n:28s} {p:.3f}")

    out_dir = os.path.dirname(SAVE_JSON_TO)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    with open(SAVE_JSON_TO, "w", encoding="utf-8") as f:
        json.dump(to_json_dict(IMAGE_PATH, all_results, detected, THRESHOLD, skin_info=skin_info), f, indent=2)
    print(f"\nSaved JSON to: {SAVE_JSON_TO}")

if __name__ == "__main__":
    main()