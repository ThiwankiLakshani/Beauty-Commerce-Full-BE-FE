import os
import json
import sys
import numpy as np
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

# I/O
IMAGE_PATH     = os.path.join(ROOT_DIR, "test.jpg")
SAVE_JSON_TO   = os.path.join(ROOT_DIR, "combined_result.json")

print(IMAGE_PATH)
# =========================
# CONFIG
# =========================
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD  = [0.229, 0.224, 0.225]

LESIONS_IMG_SIZE      = 384
LESIONS_DETECT_THRESH = 0.30

FINAL_MIN_PROB        = 0.30
FINAL_TOPK_MAIN       = 25
FINAL_TOPK_LOW        = 25
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
# HELPERS
# =========================
def get_preprocess(img_size, mean=IMAGENET_MEAN, std=IMAGENET_STD):
    return transforms.Compose([
        transforms.Resize((img_size, img_size)),
        transforms.ToTensor(),
        transforms.Normalize(mean=mean, std=std),
    ])

def combine_probs(values):
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

def canonical_skin_name(name):
    return SKIN_ALIASES.get((name or "").strip().lower())

def fmt_row(name, p):
    display = "<0.001" if (p > 0.0 and p < 1e-3) else f"{p:.3f}"
    return f"  {name:28s} {display}"

# =========================
# (A) CONDITIONS MODEL
# =========================
def build_model_from_arch(arch, n_classes):
    arch = (arch or "resnet50").lower()
    if arch == "resnet18":
        m = models.resnet18(weights=None)
    else:
        m = models.resnet50(weights=None); arch = "resnet50"
    in_feats = m.fc.in_features
    m.fc = nn.Linear(in_feats, n_classes)
    return m, arch

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

def cond_load_labels():
    classes = None
    if os.path.isfile(COND_LABELS):
        classes = _read_lines(COND_LABELS)
    if not classes and os.path.isfile(COND_CLASS2IDX):
        classes = _read_labels_map(COND_CLASS2IDX)
    return classes

def run_conditions_model(image_path, device):
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
            classes = cond_load_labels()
        if classes is None:
            raise RuntimeError("Skin-conditions model: class names not found.")

        model = torch.jit.load(COND_TS, map_location=device)
        model.eval()
        tfm = get_preprocess(img_size, mean, std)
        with Image.open(image_path).convert("RGB") as im:
            x = tfm(im).unsqueeze(0).to(device)
        with torch.no_grad():
            out = model(x)
            if isinstance(out, (list, tuple)):
                out = out[0]
            probs = torch.softmax(out, dim=1)[0].cpu().numpy()
        return classes, probs, "torchscript"

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
        arch = "resnet50"

    if classes is None:
        classes = cond_load_labels()
    if classes is None:
        raise RuntimeError("Skin-conditions model: class names not found.")

    model, _ = build_model_from_arch(arch, len(classes))
    model.load_state_dict(state_dict, strict=True)
    model.to(device).eval()

    tfm = get_preprocess(img_size, mean, std)
    with Image.open(image_path).convert("RGB") as im:
        x = tfm(im).unsqueeze(0).to(device)
    with torch.no_grad():
        logits = model(x)
        probs = torch.softmax(logits, dim=1)[0].cpu().numpy()
    return classes, probs, "eager (.pth)"

def pick_skin_type(classes, probs):
    skin_items = []
    for i, name in enumerate(classes):
        canon = canonical_skin_name(name)
        if canon in SKIN_SET:
            skin_items.append((canon, float(probs[i])))
    if not skin_items:
        return None
    skin_items.sort(key=lambda z: -z[1])
    return skin_items[0]

def conditions_non_skin(classes, probs):
    items = []
    for i, name in enumerate(classes):
        if name in IGNORE_CLASSES:
            continue
        if canonical_skin_name(name):
            continue
        items.append((name, float(probs[i])))
    items.sort(key=lambda z: -z[1])
    return items

# =========================
# (B) LESIONS MODEL
# =========================
def build_lesions_model(n_classes):
    m = models.resnet50(weights=None)
    in_feats = m.fc.in_features
    m.fc = nn.Linear(in_feats, n_classes)
    return m

def lesions_load_labels_or_infer(state_dict, labels_txt):
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
        raise RuntimeError("Cannot infer lesions class count; provide labels.txt.")
    return [f"Label_{i}" for i in range(int(out))]

def run_lesions_model(image_path, device):
    if not os.path.isfile(LESIONS_PTH):
        raise FileNotFoundError(f"Lesions model not found at {LESIONS_PTH}")

    ckpt = torch.load(LESIONS_PTH, map_location=device)
    if isinstance(ckpt, dict) and "state_dict" in ckpt:
        state_dict = ckpt["state_dict"]
        label_cols = ckpt.get("label_cols", None)
    else:
        state_dict = ckpt
        label_cols = None

    labels = label_cols or lesions_load_labels_or_infer(state_dict, LESIONS_LABELS)

    model = build_lesions_model(len(labels))
    model.load_state_dict(state_dict, strict=True)
    model.to(device).eval()

    tfm = get_preprocess(LESIONS_IMG_SIZE, IMAGENET_MEAN, IMAGENET_STD)
    with Image.open(image_path).convert("RGB") as im:
        x = tfm(im).unsqueeze(0).to(device)
    with torch.no_grad():
        logits = model(x)
        probs = torch.sigmoid(logits)[0].cpu().numpy()
    return labels, probs

# =========================
# MAP + COMBINE
# =========================
def collect_concerns_from_conditions(classes, probs):
    out = {}
    for i, raw in enumerate(classes):
        if raw in IGNORE_CLASSES:
            continue
        if canonical_skin_name(raw):
            continue
        bucket = CONCERN_MAP.get(raw)
        if not bucket:
            continue
        out.setdefault(bucket, []).append(float(probs[i]))
    return out

def collect_concerns_from_lesions(labels, probs, use_threshold_for_collect=False):
    """
    If use_threshold_for_collect=False, collect ALL probs so low concerns
    can be shown after combining. Set True only for printing 'Detected' in [B].
    """
    out = {}
    for i, raw in enumerate(labels):
        if raw in IGNORE_CLASSES:
            continue
        p = float(probs[i])
        if use_threshold_for_collect and p < LESIONS_DETECT_THRESH:
            continue
        bucket = CONCERN_MAP.get(raw)
        if not bucket:
            continue
        out.setdefault(bucket, []).append(p)
    return out

def combine_concern_buckets(a, b):
    merged = {}
    keys = set(a.keys()) | set(b.keys())
    for k in keys:
        vals = []
        if k in a: vals += a[k]
        if k in b: vals += b[k]
        merged[k] = combine_probs(vals)
    return merged

# =========================
# MAIN
# =========================
def main():
    if not os.path.isfile(IMAGE_PATH):
        print(f"[ERROR] Image not found: {IMAGE_PATH}", file=sys.stderr)
        sys.exit(1)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    torch.set_grad_enabled(False)

    cond_classes, cond_probs, cond_kind = run_conditions_model(IMAGE_PATH, device)
    lesions_labels, lesions_probs = run_lesions_model(IMAGE_PATH, device)

    ranked_cond = sorted([(cond_classes[i], float(cond_probs[i])) for i in range(len(cond_classes))],
                         key=lambda z: -z[1])
    skin_type = pick_skin_type(cond_classes, cond_probs)
    non_skin = conditions_non_skin(cond_classes, cond_probs)

    print(f"\n[ A ] Skin-Type / Conditions Model")
    print(f"Image:  {IMAGE_PATH}")
    print(f"Device: {device} | Model: {cond_kind}")

    print("\nAll results (sorted by probability):")
    for name, p in ranked_cond:
        print(fmt_row(name, p))

    print("\nSkin Type (single top among Oily/Normal/Dry):")
    if skin_type:
        print(fmt_row(skin_type[0], skin_type[1]))
    else:
        print("  (none found)")

    print("\nConcerns (non-skin classes only):")
    if not non_skin:
        print("  (none)")
    else:
        for name, p in non_skin:
            print(fmt_row(name, p))

    ranked_lesions = sorted([(lesions_labels[i], float(lesions_probs[i])) for i in range(len(lesions_labels))],
                            key=lambda z: -z[1])
    detected_lesions = [(n, p) for (n, p) in ranked_lesions if p >= LESIONS_DETECT_THRESH]

    print(f"\n[ B ] Lesions Model")
    print(f"Image:  {IMAGE_PATH}")
    print(f"Device: {device}")

    print("\nAll concerns (sorted by probability):")
    for name, p in ranked_lesions:
        print(fmt_row(name, p))

    print(f"\nDetected (>= {LESIONS_DETECT_THRESH:.2f}):")
    if not detected_lesions:
        print("  (none)")
    else:
        for name, p in detected_lesions:
            print(fmt_row(name, p))

    concerns_a_all = collect_concerns_from_conditions(cond_classes, cond_probs)
    concerns_b_all = collect_concerns_from_lesions(lesions_labels, lesions_probs, use_threshold_for_collect=False)
    combined_concerns = combine_concern_buckets(concerns_a_all, concerns_b_all)

    main_concerns = [(k, v) for k, v in combined_concerns.items() if v >= (FINAL_MIN_PROB - EPSILON)]
    low_concerns  = [(k, v) for k, v in combined_concerns.items()
                     if (v > EPSILON and v < (FINAL_MIN_PROB - EPSILON))]

    main_concerns.sort(key=lambda z: -z[1])
    low_concerns.sort(key=lambda z: -z[1])

    if FINAL_TOPK_MAIN is not None:
        main_concerns = main_concerns[:FINAL_TOPK_MAIN]
    if FINAL_TOPK_LOW is not None:
        low_concerns = low_concerns[:FINAL_TOPK_LOW]

    print(f"\n[ C ] Final Combined (mapped buckets; {COMBINE_METHOD})")
    print("\nSkin Type:")
    if skin_type:
        print(fmt_row(skin_type[0], skin_type[1]))
    else:
        print("  (not available)")

    print(f"\nMain Concerns (combined ≥ {FINAL_MIN_PROB:.2f}):")
    if not main_concerns:
        print("  (none)")
    else:
        for name, p in main_concerns:
            print(fmt_row(name, p))

    print(f"\nLow Concerns (combined < {FINAL_MIN_PROB:.2f}):")
    if not low_concerns:
        print("  (none)")
    else:
        for name, p in low_concerns:
            print(fmt_row(name, p))

    payload = {
        "image": IMAGE_PATH,
        "device": device,
        "combine_method": COMBINE_METHOD,
        "skin_type": None if not skin_type else {"label": skin_type[0], "prob": round(skin_type[1], 6)},
        "conditions_model": {
            "model_kind": cond_kind,
            "all": [{"label": n, "prob": round(p, 6)} for n, p in ranked_cond],
            "non_skin": [{"label": n, "prob": round(p, 6)} for n, p in non_skin],
        },
        "lesions_model": {
            "all": [{"label": n, "prob": round(p, 6)} for n, p in ranked_lesions],
            "detected": [{"label": n, "prob": round(p, 6)} for n, p in detected_lesions],
            "threshold": LESIONS_DETECT_THRESH,
        },
        "final": {
            "main_concerns": [{"label": n, "prob": round(p, 6)} for n, p in main_concerns],
            "low_concerns":  [{"label": n, "prob": round(p, 6)} for n, p in low_concerns],
            "final_min_prob": FINAL_MIN_PROB,
            "epsilon": EPSILON,
        }
    }
    out_dir = os.path.dirname(SAVE_JSON_TO)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    with open(SAVE_JSON_TO, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
    print(f"\nSaved JSON to: {SAVE_JSON_TO}")

if __name__ == "__main__":
    main()