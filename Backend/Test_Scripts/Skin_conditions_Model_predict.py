import os
import json
import sys
import numpy as np
import torch
from torch import nn
from torchvision import transforms, models
from PIL import Image

# -----------------------------
# HARD-CODED SETTINGS
# -----------------------------
ROOT_DIR   = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.join(ROOT_DIR, "Skin_conditions_Models")

MODEL_PATH     = os.path.join(MODELS_DIR, "skin_type_best.pth")
TS_MODEL_PATH  = os.path.join(MODELS_DIR, "skin_type_best.torchscript.pt")
LABELS_TXT     = os.path.join(MODELS_DIR, "labels.txt")
CLASS2IDX_JSON = os.path.join(MODELS_DIR, "class_to_idx.json")

IMAGE_PATH   = os.path.join(ROOT_DIR, "test.jpg")
SAVE_JSON_TO = os.path.join(ROOT_DIR, "skin_type_result.json")

# -----------------------------
# Utilities
# -----------------------------
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD  = [0.229, 0.224, 0.225]

SKIN_ALIASES = {
    "oily skin": "Oily Skin", "oily": "Oily Skin",
    "normal skin": "Normal Skin", "normal": "Normal Skin",
    "dry skin": "Dry Skin", "dry": "Dry Skin",
}
SKIN_SET = {"Oily Skin", "Normal Skin", "Dry Skin"}

def build_model_from_arch(arch, n_classes):
    arch = (arch or "resnet50").lower()
    if arch == "resnet18":
        m = models.resnet18(weights=None)
    else:
        m = models.resnet50(weights=None); arch = "resnet50"
    in_feats = m.fc.in_features
    m.fc = nn.Linear(in_feats, n_classes)
    return m, arch

def load_labels_from_files():
    if os.path.isfile(LABELS_TXT):
        try:
            with open(LABELS_TXT, "r", encoding="utf-8") as f:
                classes = [l.strip() for l in f if l.strip()]
            if classes:
                return classes
        except Exception:
            pass
    if os.path.isfile(CLASS2IDX_JSON):
        try:
            with open(CLASS2IDX_JSON, "r", encoding="utf-8") as f:
                m = json.load(f)
            return [name for name, _idx in sorted(m.items(), key=lambda kv: kv[1])]
        except Exception:
            pass
    return None

def get_preprocess(img_size, mean, std):
    return transforms.Compose([
        transforms.Resize((img_size, img_size)),
        transforms.ToTensor(),
        transforms.Normalize(mean=mean, std=std),
    ])

def infer_eager(image_path, device):
    if not os.path.isfile(MODEL_PATH):
        raise FileNotFoundError(f"Model checkpoint not found at {MODEL_PATH}")

    ckpt = torch.load(MODEL_PATH, map_location=device)
    if isinstance(ckpt, dict) and "state_dict" in ckpt:
        state_dict = ckpt["state_dict"]
        classes = ckpt.get("classes", None)
        arch = ckpt.get("arch", "resnet50")
        img_size = int(ckpt.get("img_size", 224))
        norm = ckpt.get("normalization", {"mean": IMAGENET_MEAN, "std": IMAGENET_STD})
        mean, std = norm.get("mean", IMAGENET_MEAN), norm.get("std", IMAGENET_STD)
    else:
        state_dict = ckpt
        classes = None
        arch = "resnet50"
        img_size = 224
        mean, std = IMAGENET_MEAN, IMAGENET_STD

    if classes is None:
        classes = load_labels_from_files()
    if classes is None:
        raise RuntimeError("No class names found. Provide 'classes' in checkpoint OR labels.txt/class_to_idx.json.")

    n_classes = len(classes)
    model, arch = build_model_from_arch(arch, n_classes)
    model.load_state_dict(state_dict, strict=True)
    model.to(device).eval()

    tfm = get_preprocess(img_size, mean, std)
    with Image.open(image_path).convert("RGB") as im:
        x = tfm(im).unsqueeze(0).to(device)

    with torch.no_grad():
        logits = model(x)
        probs = torch.softmax(logits, dim=1)[0].cpu().numpy()

    return classes, probs

def infer_torchscript(image_path, device):
    if not os.path.isfile(TS_MODEL_PATH):
        raise FileNotFoundError

    img_size, mean, std = 224, IMAGENET_MEAN, IMAGENET_STD
    classes = None
    if os.path.isfile(MODEL_PATH):
        ckpt = torch.load(MODEL_PATH, map_location=device)
        if isinstance(ckpt, dict):
            img_size = int(ckpt.get("img_size", 224))
            norm = ckpt.get("normalization", {"mean": IMAGENET_MEAN, "std": IMAGENET_STD})
            mean, std = norm.get("mean", IMAGENET_MEAN), norm.get("std", IMAGENET_STD)
            classes = ckpt.get("classes", None)

    if classes is None:
        classes = load_labels_from_files()
    if classes is None:
        raise RuntimeError("No class names found. Provide 'classes' in checkpoint OR labels.txt/class_to_idx.json.")

    model = torch.jit.load(TS_MODEL_PATH, map_location=device)
    model.eval()

    tfm = get_preprocess(img_size, mean, std)
    with Image.open(image_path).convert("RGB") as im:
        x = tfm(im).unsqueeze(0).to(device)

    with torch.no_grad():
        out = model(x)
        if isinstance(out, (list, tuple)):
            out = out[0]
        probs = torch.softmax(out, dim=1)[0].cpu().numpy()

    return classes, probs

def canonical_skin_name(name: str) -> str | None:
    key = name.strip().lower()
    return SKIN_ALIASES.get(key, None)

def split_skin_vs_concerns(ranked):
    """
    ranked: list[(label, prob)] sorted desc.
    Returns:
      skin_top: (label, prob) or None
      concerns: list[(label, prob)] = ONLY non-skin classes
               (exclude all of: Oily/Normal/Dry)
    """
    skin_candidates = []
    for n, p in ranked:
        canon = canonical_skin_name(n)
        if canon in SKIN_SET:
            skin_candidates.append((canon, n, p))

    if skin_candidates:
        top = max(skin_candidates, key=lambda z: z[2])
        skin_top = (top[1], top[2])
    else:
        skin_top = ranked[0] if ranked else None

    concerns = [(n, p) for (n, p) in ranked if canonical_skin_name(n) is None]
    return skin_top, concerns


def main():
    if not os.path.isfile(IMAGE_PATH):
        print(f"[ERROR] Image not found: {IMAGE_PATH}", file=sys.stderr)
        sys.exit(1)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    torch.set_grad_enabled(False)

    try:
        classes, probs = infer_torchscript(IMAGE_PATH, device)
        used = "torchscript"
    except Exception:
        classes, probs = infer_eager(IMAGE_PATH, device)
        used = "eager (.pth)"

    ranked = sorted([(classes[i], float(probs[i])) for i in range(len(classes))],
                    key=lambda z: -z[1])

    skin_top, concerns = split_skin_vs_concerns(ranked)

    print(f"\nImage:  {IMAGE_PATH}")
    print(f"Device: {device} | Model: {used}")

    print("\nAll results (sorted by probability):")
    for name, p in ranked:
        print(f"  {name:20s} {p:.3f}")

    if skin_top:
        print("\nSkin Type (top of Dry/Normal/Oily):")
        print(f"  {skin_top[0]:20s} {skin_top[1]:.3f}")
    else:
        print("\nSkin Type (top of Dry/Normal/Oily):")
        print("  (none of Dry/Normal/Oily present; used overall top instead)")

    print("\nConcerns (non-skin classes only):")
    if not concerns:
        print("  (none)")
    else:
        for name, p in concerns:
            print(f"  {name:20s} {p:.3f}")

    out_dir = os.path.dirname(SAVE_JSON_TO)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    json_payload = {
        "image": IMAGE_PATH,
        "device": device,
        "model_kind": used,
        "skin_type": None if not skin_top else {"label": skin_top[0], "prob": round(skin_top[1], 6)},
        "concerns": [{"label": n, "prob": round(p, 6)} for n, p in concerns],
        "all_results": [{"label": n, "prob": round(p, 6)} for n, p in ranked],
    }

    with open(SAVE_JSON_TO, "w", encoding="utf-8") as f:
        json.dump(json_payload, f, indent=2)

    print(f"\nSaved JSON to: {SAVE_JSON_TO}")

if __name__ == "__main__":
    main()