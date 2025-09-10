# ===========================
# IMPORTS
# ===========================
import cv2

from AI_Comb_Models_Logicals import ModelRunner, run_combined_AI_from_cv2


# ===========================
# AI INFERENCE FUNCTION
# ===========================
def run_simple_ai(img):
    lesions = ModelRunner(
        weights_path="Skin_dis_Models/best_model.pth",
        labels=[
            "Erythema","Patch","Papule","Plaque","Macule","Pustule","Crust",
            "Brown(Hyperpigmentation)","Sclerosis","Do not consider this image","Scar",
            "Comedo","Atrophy","Telangiectasia","Yellow","White(Hypopigmentation)",
            "Wheal","Purple","Nodule","Black","Erosion","Scale","Ulcer","Induration",
            "Friable","Exophytic/Fungating","Cyst","Excoriation","Warty/Papillomatous",
            "Exudate","Poikiloderma","Dome-shaped","Acuminate","Vesicle","Bulla","Blue",
            "Umbilicated","Lichenification","Purpura/Petechiae","Pedunculated","Xerosis",
            "Fissure","Salmon","Gray","Translucent","Abscess","Burrow","Flat topped","Pigmented"
        ],
        arch="resnet50",
        activation="sigmoid",
    )

    conditions = ModelRunner(
        weights_path="Skin_conditions_Models/skin_type_best.pth",
        labels=["Acne","Dark Spots","Oily Skin","Normal Skin","Blackheads","Dry Skin","Wrinkles"],
        arch="resnet50",
        activation="sigmoid",
    )

    img_bgr = cv2.imread(img)

    combined = run_combined_AI_from_cv2(
        img_bgr, lesions_runner=lesions, conditions_runner=conditions,
        size=224, cond_threshold=0.15, lesion_high_thr=0.30, lesion_low_thr=0.15
    )

    return combined


# ===========================
# MAIN EXECUTION
# ===========================
img = "test.jpg"
result = run_simple_ai(img)

print(result)