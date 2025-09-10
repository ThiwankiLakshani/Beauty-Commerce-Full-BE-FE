#!/usr/bin/env python3
import os
import json
import numpy as np
from typing import Tuple, Dict, Any, Optional

import torch
from torch import nn
from torchvision import transforms, models
from PIL import Image

# =========================
# PATHS
# =========================
ROOT_DIR = os.path.dirname(os.path.abspath(__file__))

# (A) Skin-type / conditions model
COND_DIR       = os.path.join(ROOT_DIR, "Skin_conditions_Models")
COND_PTH       = os.path.join(COND_DIR, "skin_type_best.pth")
COND_TS        = os.path.join(COND_DIR, "skin_type_best.torchscript.pt")
COND_LABELS    = os.path.join(COND_DIR, "labels.txt")
COND_CLASS2IDX = os.path.join(COND_DIR, "class_to_idx.json")

# (B) Lesions (Fitzpatrick-like) multi-label model
LESIONS_DIR    = os.path.join(ROOT_DIR, "Skin_dis_Models")
LESIONS_PTH    = os.path.join(LESIONS_DIR, "best_model.pth")
LESIONS_LABELS = os.path.join(LESIONS_DIR, "labels.txt")

# =========================
# CONFIG
# =========================
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD  = [0.229, 0.224, 0.225]

LESIONS_IMG_SIZE      = 384

FINAL_MIN_PROB        = 0.30
COMBINE_METHOD        = "noisy_or"
EPSILON               = 0.050

# =========================
# CANONICALIZATION
# =========================
SKIN_ALIASES = {
    "oily skin": "Oily Skin", "oily": "Oily Skin",
    "normal skin": "Normal Skin", "normal": "Normal Skin",
    "dry skin": "Dry Skin", "dry": "Dry Skin",
}
SKIN_SET = {"Oily Skin", "Normal Skin", "Dry Skin"}

CONCERN_MAP = {
    "Acne": "Acne & Breakouts",
    "Blackheads": "Blackheads & Congestion",
    "Wrinkles": "Fine Lines & Wrinkles",
    "Dark Spots": "Dark Spots & Pigmentation",

    "Papule": "Inflamed Bumps (Papules)",
    "Pustule": "Whiteheads / Pustules",
    "Comedo": "Comedones (Clogged Pores)",
    "Nodule": "Deep Nodules",

    "Brown(Hyperpigmentation)": "Brown Hyperpigmentation",
    "Macule": "Flat Spots (Macules)",
    "White(Hypopigmentation)": "Light Spots (Hypopigmentation)",

    "Erythema": "Redness & Irritation",
    "Telangiectasia": "Broken Capillaries",
    "Wheal": "Hives / Wheals",

    "Patch": "Dry Patches & Roughness",
    "Plaque": "Thick Patches (Plaques)",
    "Scale": "Flaky Skin (Scaling)",
    "Crust": "Scabbing & Crusts",

    "Scar": "Scarring",
    "Atrophy": "Skin Thinning (Atrophy)",
    "Induration": "Firmness & Thickening (Induration)",
    "Sclerosis": "Hardening (Sclerosis)",

    "Erosion": "Surface Erosion",
    "Ulcer": "Deep Ulceration",

    "Yellow": "Uneven Tone (Yellowish)",
    "Purple": "Discoloration (Purplish)",
    "Black": "Discoloration (Darkening)",
}
IGNORE_CLASSES = {"Do not consider this image"}

# =========================
# GLOBAL CACHES
# =========================
_DEVICE: Optional[str] = None

_COND_CACHE = {
    "model": None,
    "classes": None,
    "img_size": 224,
    "mean": IMAGENET_MEAN,
    "std": IMAGENET_STD,
    "kind": None,
}

_LESIONS_CACHE = {
    "model": None,
    "labels": None,
    "img_size": LESIONS_IMG_SIZE,
    "mean": IMAGENET_MEAN,
    "std": IMAGENET_STD,
}

# =========================
# HELPERS
# =========================
def _ensure_device():
    global _DEVICE
    if _DEVICE is None:
        _DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
    return _DEVICE

def _pil_from_image(image) -> Image.Image:
    if isinstance(image, Image.Image):
        return image.convert("RGB")
    if isinstance(image, np.ndarray):
        if image.ndim != 3 or image.shape[2] not in (3, 4):
            raise TypeError("NumPy array must be HxWxC with 3 or 4 channels (RGB/RGBA).")
        if image.dtype != np.uint8:
            image = image.astype(np.uint8)
        if image.shape[2] == 4:
            image = image[:, :, :3]
        return Image.fromarray(image, mode="RGB")
    raise TypeError("image must be a PIL.Image.Image or a NumPy RGB array.")

def _get_preprocess(img_size, mean=IMAGENET_MEAN, std=IMAGENET_STD):
    return transforms.Compose([
        transforms.Resize((img_size, img_size)),
        transforms.ToTensor(),
        transforms.Normalize(mean=mean, std=std),
    ])

def _combine_probs(values):
    if not values:
        return 0.0
    if COMBINE_METHOD == "max":
        return max(values)
    if COMBINE_METHOD == "avg":
        return float(sum(values) / len(values))

    prod = 1.0
    for p in values:
        prod *= (1.0 - float(p))
    return 1.0 - prod

def _canonical_skin_name(name: str) -> Optional[str]:
    return SKIN_ALIASES.get((name or "").strip().lower())

# =========================
# LOADERS: CONDITIONS MODEL
# =========================
def _read_lines(path_str):
    try:
        with open(path_str, "r", encoding="utf-8") as f:
            return [l.strip() for l in f if l.strip()]
    except Exception:
        return None

def _read_labels_map(path_str):
    try:
        with open(path_str, "r", encoding="utf-8") as f:
            m = json.load(f)
        return [name for name, _idx in sorted(m.items(), key=lambda kv: kv[1])]
    except Exception:
        return None

def _cond_load_labels():
    classes = None
    if os.path.isfile(COND_LABELS):
        classes = _read_lines(COND_LABELS)
    if not classes and os.path.isfile(COND_CLASS2IDX):
        classes = _read_labels_map(COND_CLASS2IDX)
    return classes

def _build_model_from_arch(arch, n_classes):
    arch = (arch or "resnet50").lower()
    if arch == "resnet18":
        m = models.resnet18(weights=None)
    else:
        m = models.resnet50(weights=None); arch = "resnet50"
    in_feats = m.fc.in_features
    m.fc = nn.Linear(in_feats, n_classes)
    return m

def _ensure_conditions_loaded(device: str):
    if _COND_CACHE["model"] is not None:
        return
    classes = None
    img_size, mean, std = 224, IMAGENET_MEAN, IMAGENET_STD

    if os.path.isfile(COND_TS):
        if os.path.isfile(COND_PTH):
            ckpt = torch.load(COND_PTH, map_location=device)
            if isinstance(ckpt, dict):
                img_size = int(ckpt.get("img_size", 224))
                norm = ckpt.get("normalization", {"mean": IMAGENET_MEAN, "std": IMAGENET_STD})
                mean, std = norm.get("mean", IMAGENET_MEAN), norm.get("std", IMAGENET_STD)
                classes = ckpt.get("classes", None)
        if classes is None:
            classes = _cond_load_labels()
        if classes is None:
            raise RuntimeError("Skin-conditions model: class names not found (labels.txt/class_to_idx.json).")
        model = torch.jit.load(COND_TS, map_location=device)
        model.eval()
        _COND_CACHE.update({
            "model": model, "classes": classes, "img_size": img_size,
            "mean": mean, "std": std, "kind": "torchscript"
        })
        return

    if not os.path.isfile(COND_PTH):
        raise FileNotFoundError(f"Skin-conditions model not found at {COND_PTH}")
    ckpt = torch.load(COND_PTH, map_location=device)
    if isinstance(ckpt, dict) and "state_dict" in ckpt:
        state_dict = ckpt["state_dict"]
        classes = ckpt.get("classes", None)
        arch = ckpt.get("arch", "resnet50")
        img_size = int(ckpt.get("img_size", 224))
        norm = ckpt.get("normalization", {"mean": IMAGENET_MEAN, "std": IMAGENET_STD})
        mean, std = norm.get("mean", IMAGENET_MEAN), norm.get("std", IMAGENET_STD)
    else:
        state_dict = ckpt
        classes = _cond_load_labels()
        arch = "resnet50"
    if classes is None:
        classes = _cond_load_labels()
    if classes is None:
        raise RuntimeError("Skin-conditions model: class names not found.")
    model = _build_model_from_arch(arch, len(classes))
    model.load_state_dict(state_dict, strict=True)
    model.to(device).eval()
    _COND_CACHE.update({
        "model": model, "classes": classes, "img_size": img_size,
        "mean": mean, "std": std, "kind": 'eager (.pth)'
    })

# =========================
# LOADERS: LESIONS MODEL
# =========================
def _build_lesions_model(n_classes):
    m = models.resnet50(weights=None)
    in_feats = m.fc.in_features
    m.fc = nn.Linear(in_feats, n_classes)
    return m

def _lesions_load_labels_or_infer(state_dict, labels_txt):
    label_cols = None
    if labels_txt and os.path.isfile(labels_txt):
        label_cols = _read_lines(labels_txt)
    if label_cols:
        return label_cols
    out = None
    for k, v in state_dict.items():
        if k.endswith("fc.weight"):
            out = v.shape[0]; break
    if out is None:
        raise RuntimeError("Lesions model: cannot infer class count; provide labels.txt.")
    return [f"Label_{i}" for i in range(int(out))]

def _ensure_lesions_loaded(device: str):
    if _LESIONS_CACHE["model"] is not None:
        return
    if not os.path.isfile(LESIONS_PTH):
        raise FileNotFoundError(f"Lesions model not found at {LESIONS_PTH}")
    ckpt = torch.load(LESIONS_PTH, map_location=device)
    if isinstance(ckpt, dict) and "state_dict" in ckpt:
        state_dict = ckpt["state_dict"]
        label_cols = ckpt.get("label_cols", None)
    else:
        state_dict = ckpt
        label_cols = None
    labels = label_cols or _lesions_load_labels_or_infer(state_dict, LESIONS_LABELS)
    model = _build_lesions_model(len(labels))
    model.load_state_dict(state_dict, strict=True)
    model.to(device).eval()
    _LESIONS_CACHE.update({
        "model": model, "labels": labels, "img_size": LESIONS_IMG_SIZE,
        "mean": IMAGENET_MEAN, "std": IMAGENET_STD
    })

# =========================
# INFERENCE HELPERS
# =========================
@torch.no_grad()
def _infer_conditions(image_pil: Image.Image, device: str) -> Tuple[list, np.ndarray]:
    _ensure_conditions_loaded(device)
    tfm = _get_preprocess(_COND_CACHE["img_size"], _COND_CACHE["mean"], _COND_CACHE["std"])
    x = tfm(image_pil).unsqueeze(0).to(device)
    model = _COND_CACHE["model"]
    out = model(x)
    if isinstance(out, (list, tuple)):
        out = out[0]
    probs = torch.softmax(out, dim=1)[0].detach().cpu().numpy()
    return _COND_CACHE["classes"], probs

@torch.no_grad()
def _infer_lesions(image_pil: Image.Image, device: str) -> Tuple[list, np.ndarray]:
    _ensure_lesions_loaded(device)
    tfm = _get_preprocess(_LESIONS_CACHE["img_size"], _LESIONS_CACHE["mean"], _LESIONS_CACHE["std"])
    x = tfm(image_pil).unsqueeze(0).to(device)
    logits = _LESIONS_CACHE["model"](x)
    probs = torch.sigmoid(logits)[0].detach().cpu().numpy()
    return _LESIONS_CACHE["labels"], probs

def _pick_skin_type(classes, probs) -> Optional[Tuple[str, float]]:
    skin_items = []
    for i, name in enumerate(classes):
        canon = _canonical_skin_name(name)
        if canon in SKIN_SET:
            skin_items.append((canon, float(probs[i])))
    if not skin_items:
        return None
    skin_items.sort(key=lambda z: -z[1])
    return skin_items[0]

def _collect_concerns_from_conditions(classes, probs) -> Dict[str, list]:
    out = {}
    for i, raw in enumerate(classes):
        if raw in IGNORE_CLASSES:
            continue
        if _canonical_skin_name(raw):
            continue
        bucket = CONCERN_MAP.get(raw)
        if not bucket:
            continue
        out.setdefault(bucket, []).append(float(probs[i]))
    return out

def _collect_concerns_from_lesions(labels, probs) -> Dict[str, list]:
    out = {}
    for i, raw in enumerate(labels):
        if raw in IGNORE_CLASSES:
            continue
        p = float(probs[i])
        bucket = CONCERN_MAP.get(raw)
        if not bucket:
            continue
        out.setdefault(bucket, []).append(p)
    return out

def _combine_concern_buckets(a: Dict[str, list], b: Dict[str, list]) -> Dict[str, float]:
    merged = {}
    keys = set(a.keys()) | set(b.keys())
    for k in keys:
        vals = []
        if k in a: vals += a[k]
        if k in b: vals += b[k]
        merged[k] = _combine_probs(vals)
    return merged

# =========================
# PUBLIC API
# =========================
def analyze_face_skin(image) -> Dict[str, Any]:

    device = _ensure_device()
    torch.set_grad_enabled(False)

    pil = _pil_from_image(image)

    cond_classes, cond_probs = _infer_conditions(pil, device)
    lesions_labels, lesions_probs = _infer_lesions(pil, device)

    skin_type = _pick_skin_type(cond_classes, cond_probs)

    concerns_a_all = _collect_concerns_from_conditions(cond_classes, cond_probs)
    concerns_b_all = _collect_concerns_from_lesions(lesions_labels, lesions_probs)
    combined_concerns = _combine_concern_buckets(concerns_a_all, concerns_b_all)

    main_concerns = [(k, v) for k, v in combined_concerns.items() if v >= (FINAL_MIN_PROB - EPSILON)]
    low_concerns  = [(k, v) for k, v in combined_concerns.items() if (v > EPSILON and v < (FINAL_MIN_PROB - EPSILON))]

    main_concerns.sort(key=lambda z: -z[1])
    low_concerns.sort(key=lambda z: -z[1])

    result = {
        "combine_method": COMBINE_METHOD,
        "skin_type": None if not skin_type else {"label": skin_type[0], "prob": round(float(skin_type[1]), 6)},
        "main_concerns": [{"label": n, "prob": round(float(p), 6)} for n, p in main_concerns],
        "low_concerns":  [{"label": n, "prob": round(float(p), 6)} for n, p in low_concerns],
        "thresholds": {"final_min_prob": FINAL_MIN_PROB, "epsilon": EPSILON},
    }
    return result


# =========================
# usage
# =========================
from PIL import Image
img = Image.open("../test.jpg").convert("RGB")
out = analyze_face_skin(img)

import json; print(json.dumps(out, indent=2))



# NumPy array:
import cv2, numpy as np
arr = cv2.cvtColor(cv2.imread("../test.jpg"), cv2.COLOR_BGR2RGB)  # HxWx3 RGB
out = analyze_face_skin(arr)
print(json.dumps(out, indent=2))
