from __future__ import annotations
import os
from dataclasses import dataclass
from typing import List, Optional, Dict, Any, Sequence, Tuple

import numpy as np
from PIL import Image

import torch
from torch import nn
from torchvision import models, transforms


# ===========================
# Image preprocessing
# ===========================
def preprocess_bgr_cv2(img_bgr: np.ndarray, size: int = 224) -> torch.Tensor:
    """
    Convert a cv2 BGR image (H, W, 3) uint8 to a normalized tensor (1, 3, H, W).
    """
    if img_bgr is None:
        raise ValueError("img_bgr is None; please pass a valid cv2 image array")
    if img_bgr.ndim != 3 or img_bgr.shape[2] != 3:
        raise ValueError(f"Expected (H,W,3) BGR image, got shape={img_bgr.shape}")

    img_rgb = img_bgr[..., ::-1]
    pil = Image.fromarray(img_rgb)

    tfm = transforms.Compose([
        transforms.Resize((size, size), interpolation=transforms.InterpolationMode.BILINEAR),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406],
                             std=[0.229, 0.224, 0.225]),
    ])
    return tfm(pil).unsqueeze(0)


# ===========================
# Model construction helpers
# ===========================
def build_backbone(arch: str, num_classes: int) -> nn.Module:
    """
    Build a torchvision backbone and replace the classifier to `num_classes`.
    Supported: resnet18/resnet50, efficientnet_b0/b3.
    """
    arch = arch.lower()
    if arch == "resnet18":
        m = models.resnet18(weights=None)
        m.fc = nn.Linear(m.fc.in_features, num_classes)
        return m
    if arch == "resnet50":
        m = models.resnet50(weights=None)
        m.fc = nn.Linear(m.fc.in_features, num_classes)
        return m
    if arch == "efficientnet_b0":
        m = models.efficientnet_b0(weights=None)
        m.classifier[-1] = nn.Linear(m.classifier[-1].in_features, num_classes)
        return m
    if arch == "efficientnet_b3":
        m = models.efficientnet_b3(weights=None)
        m.classifier[-1] = nn.Linear(m.classifier[-1].in_features, num_classes)
        return m
    raise ValueError(f"Unsupported arch '{arch}'. Extend build_backbone() to match your model.")


def _load_labels_from_ckpt(ckpt: dict) -> Optional[List[str]]:
    if isinstance(ckpt, dict):
        if "label_cols" in ckpt:
            return ckpt["label_cols"]
        if "labels" in ckpt:
            return ckpt["labels"]
    return None


# ===========================
# Model runner
# ===========================
@dataclass
class ModelRunner:
    weights_path: str
    labels: Optional[List[str]] = None
    arch: str = "resnet50"
    activation: str = "sigmoid"

    _model: Optional[nn.Module] = None
    _device: Optional[torch.device] = None

    def _ensure_loaded(self):
        if self._model is not None:
            return

        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self._device = device

        path = self.weights_path
        if not os.path.isfile(path):
            raise FileNotFoundError(f"Weights not found: {path}")

        if path.endswith((".pt", ".ts", ".torchscript")):
            m = torch.jit.load(path, map_location=device)
            m.eval()
            self._model = m.to(device)
            if self.labels is None:
                raise ValueError("For TorchScript weights, provide 'labels' list.")
            return

        ckpt = torch.load(path, map_location="cpu")
        state_dict = ckpt["state_dict"] if (isinstance(ckpt, dict) and "state_dict" in ckpt) else ckpt

        labels = self.labels or _load_labels_from_ckpt(ckpt)
        if labels is None:
            raise ValueError("Label names not provided and not found in checkpoint ('label_cols'/'labels').")

        m = build_backbone(self.arch, num_classes=len(labels))

        def _strip_prefix(sd, prefix="module."):
            return { (k[len(prefix):] if k.startswith(prefix) else k): v for k, v in sd.items() }

        try:
            m.load_state_dict(state_dict, strict=False)
        except RuntimeError:
            m.load_state_dict(_strip_prefix(state_dict), strict=False)

        self._model = m.to(device).eval()
        self.labels = labels

    @torch.no_grad()
    def predict_from_bgr(self, img_bgr: np.ndarray, size: int = 224, topk: Optional[int] = None) -> Dict[str, Any]:
        """
        Returns:
          {
            "all_results": [{"label": str, "prob": float}, ...],  # sorted desc
            "top": (label, prob) or None,
          }
        """
        self._ensure_loaded()
        x = preprocess_bgr_cv2(img_bgr, size=size).to(self._device)

        logits = self._model(x)
        if isinstance(logits, (list, tuple)):
            logits = logits[0]
        if logits.ndim == 1:
            logits = logits.unsqueeze(0)

        if self.activation == "softmax":
            probs = torch.softmax(logits, dim=1)[0]
        else:
            probs = torch.sigmoid(logits)[0]

        probs_np = probs.detach().float().cpu().numpy()
        labels = self.labels or [f"class_{i}" for i in range(probs_np.shape[0])]

        pairs = list(zip(labels, probs_np.tolist()))
        pairs.sort(key=lambda x: x[1], reverse=True)

        if topk is not None:
            pairs = pairs[:topk]

        top = pairs[0] if pairs else None

        return {
            "all_results": [{"label": n, "prob": float(p)} for (n, p) in pairs],
            "top": top
        }


# ===========================
# Mapping (Lesions -> Beauticulture concern names)
# ===========================
LESION_TO_CONCERN: Dict[str, Optional[str]] = {
    "Papule": "Acne", "Pustule": "Acne", "Nodule": "Acne", "Cyst": "Acne",
    "Comedo": "Blackheads",
    "Dome-shaped": "Bumps", "Acuminate": "Bumps", "Umbilicated": "Bumps",

    "Brown(Hyperpigmentation)": "Dark Spots",
    "Pigmented": "Dark Spots",
    "Poikiloderma": "Dark Spots",

    "Erythema": "Redness", "Salmon": "Redness",
    "Telangiectasia": "Broken Capillaries",
    "Purpura/Petechiae": "Bruising/Discoloration", "Purple": "Bruising/Discoloration",

    "Scale": "Dryness/Flaking", "Xerosis": "Dryness/Flaking", "Fissure": "Dryness/Flaking",
    "Plaque": "Texture/Roughness", "Patch": "Texture/Roughness",
    "Lichenification": "Texture/Roughness", "Sclerosis": "Texture/Roughness",

    "Erosion": "Wound/Barrier Damage", "Ulcer": "Wound/Barrier Damage", "Friable": "Wound/Barrier Damage",
    "Exudate": "Oozing/Crusting", "Crust": "Oozing/Crusting",

    "Scar": "Scarring", "Atrophy": "Fine Lines/Wrinkles",

    "Vesicle": "Blistering", "Bulla": "Blistering",

    "White(Hypopigmentation)": "Hypopigmentation",
    "Blue": "Discoloration", "Black": "Discoloration", "Gray": "Discoloration", "Translucent": "Discoloration",

    "Warty/Papillomatous": "Warts/Skin Growth", "Pedunculated": "Skin Tag",
    "Exophytic/Fungating": "Abnormal Growth",

    "Wheal": "Hives",

    "Induration": "Inflammation/Swelling",
    "Abscess": "Inflammation/Swelling",
    "Do not consider this image": None,
    "Burrow": "Abnormal Finding",
}


# ===========================
# Combination logic (your spec)
# ===========================
def _pick_skin_type(prob_map: Dict[str, float], skin_type_labels: Sequence[str]) -> Dict[str, float]:
    best_label = max(skin_type_labels, key=lambda k: prob_map.get(k, 0.0))
    return {"label": best_label, "prob": float(prob_map.get(best_label, 0.0))}


def _skin_concerns_from_conditions(all_results: List[Dict[str, Any]],
                                   skin_type_labels: Sequence[str],
                                   threshold: float = 0.15) -> List[Dict[str, float]]:
    out = []
    for d in all_results:
        lbl, p = d["label"], float(d["prob"])
        if lbl in skin_type_labels:
            continue
        if p >= threshold:
            out.append({"label": lbl, "prob": p})
    out.sort(key=lambda x: x["prob"], reverse=True)
    return out


def _agg_lesions_to_concerns_by_max(lesion_results: List[Dict[str, Any]],
                                    mapping: Dict[str, Optional[str]]) -> Dict[str, float]:
    """
    Map lesion labels -> concern names and aggregate by **maximum** probability per concern.
    """
    agg: Dict[str, float] = {}
    for d in lesion_results:
        lesion_label = d["label"]
        p = float(d["prob"])
        concern = mapping.get(lesion_label)
        if not concern:
            continue
        if concern not in agg or p > agg[concern]:
            agg[concern] = p
    return agg


def _split_other_concerns(agg_concern_probs: Dict[str, float],
                          high_thr: float = 0.30,
                          low_thr: float = 0.15) -> Tuple[List[Dict[str, float]], List[Dict[str, float]]]:
    other, low = [], []
    for lbl, p in agg_concern_probs.items():
        if p >= high_thr:
            other.append({"label": lbl, "prob": float(p)})
        elif p >= low_thr:
            low.append({"label": lbl, "prob": float(p)})
    other.sort(key=lambda x: x["prob"], reverse=True)
    low.sort(key=lambda x: x["prob"], reverse=True)
    return other, low


def run_combined_AI_from_cv2(
    img_bgr: np.ndarray,
    lesions_runner: ModelRunner,
    conditions_runner: ModelRunner,
    size: int = 224,
    skin_type_labels: Sequence[str] = ("Oily Skin", "Dry Skin", "Normal Skin"),
    cond_threshold: float = 0.15,
    lesion_high_thr: float = 0.30,
    lesion_low_thr: float = 0.15,
    lesion_mapping: Dict[str, Optional[str]] = LESION_TO_CONCERN,
) -> Dict[str, Any]:

    cond_raw = conditions_runner.predict_from_bgr(img_bgr, size=size, topk=None)
    lesion_raw = lesions_runner.predict_from_bgr(img_bgr, size=size, topk=None)

    cond_map = {d["label"]: float(d["prob"]) for d in cond_raw["all_results"]}
    skin_type = _pick_skin_type(cond_map, skin_type_labels)

    skin_concerns = _skin_concerns_from_conditions(cond_raw["all_results"], skin_type_labels, threshold=cond_threshold)

    agg = _agg_lesions_to_concerns_by_max(lesion_raw["all_results"], lesion_mapping)

    other_concerns, low_concerns = _split_other_concerns(agg, high_thr=lesion_high_thr, low_thr=lesion_low_thr)

    return {
        "skin_type": skin_type,
        "skin_concerns": skin_concerns,
        "other_concerns": other_concerns,
        "low_concerns": low_concerns,
    }


# ===========================
# Merge helper (optional)
# ===========================
def merge_concerns_sections(combined: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
    """
    Merge 'skin_concerns', 'other_concerns', and 'low_concerns' into a single dict:
      { label: {"prob": float, "source": [ ... ]}, ... }

    - Uses the **max** probability when a label appears in multiple sections.
    - Source tags:
        "conditions"   -> from skin_concerns (conditions model)
        "lesions"      -> from other_concerns (lesion mapping, >=0.30)
        "lesions-low"  -> from low_concerns (lesion mapping, 0.15–0.30)
    """
    merged: Dict[str, Dict[str, Any]] = {}

    for d in combined.get("skin_concerns", []):
        lbl, p = d["label"], float(d["prob"])
        merged[lbl] = {"prob": p, "source": ["conditions"]}

    for d in combined.get("other_concerns", []):
        lbl, p = d["label"], float(d["prob"])
        if lbl in merged:
            merged[lbl]["prob"] = max(merged[lbl]["prob"], p)
            if "lesions" not in merged[lbl]["source"]:
                merged[lbl]["source"].append("lesions")
        else:
            merged[lbl] = {"prob": p, "source": ["lesions"]}

    for d in combined.get("low_concerns", []):
        lbl, p = d["label"], float(d["prob"])
        if lbl in merged:
            merged[lbl]["prob"] = max(merged[lbl]["prob"], p)
            if "lesions-low" not in merged[lbl]["source"]:
                merged[lbl]["source"].append("lesions-low")
        else:
            merged[lbl] = {"prob": p, "source": ["lesions-low"]}

    return merged