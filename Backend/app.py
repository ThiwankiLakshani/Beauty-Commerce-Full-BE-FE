import base64
import csv
import io
import os
import re
import threading
import uuid
from datetime import timedelta, datetime
from functools import wraps
from pathlib import Path
from urllib.parse import urljoin

# -------- AI imports --------
import cv2
from bson import ObjectId
from dotenv import load_dotenv
from flask import (
    Flask, Blueprint, request, jsonify, render_template,
    redirect, url_for, session, flash, abort, Response
)
from flask_cors import CORS
from flask_jwt_extended import (
    JWTManager, create_access_token, create_refresh_token,
    jwt_required, get_jwt_identity
)
from flask_pymongo import PyMongo
from flask_wtf import CSRFProtect
from flask_wtf.csrf import generate_csrf
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from wtforms import Form, StringField, PasswordField, FloatField
from wtforms.validators import DataRequired, Email, Length, Optional

from AI_Comb_Models_Logicals import (
    ModelRunner, run_combined_AI_from_cv2,
    merge_concerns_sections
)

load_dotenv()

# =============================================================================
# App setup
# =============================================================================
app = Flask(__name__, template_folder="templates", static_folder="static")

# --- Core config ---
app.config["MONGO_URI"] = os.getenv("MONGO_URI", "mongodb://localhost:27017/beauty_commerce")
app.config["JWT_SECRET_KEY"] = os.getenv("JWT_SECRET_KEY", "dev-secret-change-me")
app.config["JWT_ACCESS_TOKEN_EXPIRES"] = timedelta(hours=6)
app.config["JWT_REFRESH_TOKEN_EXPIRES"] = timedelta(days=30)
app.config["JWT_TOKEN_LOCATION"] = ["headers"]
app.config["SECRET_KEY"] = os.getenv("FLASK_SECRET_KEY", "dev-session-secret-change-me")
app.config["WTF_CSRF_TIME_LIMIT"] = 60 * 60 * 8

# --- Uploads ---
app.config["MAX_CONTENT_LENGTH"] = 12 * 1024 * 1024
UPLOAD_PRODUCTS_DIR = os.path.join(app.static_folder, "uploads", "products")
UPLOAD_FACES_DIR = os.path.join(app.static_folder, "uploads", "faces")
os.makedirs(UPLOAD_PRODUCTS_DIR, exist_ok=True)
os.makedirs(UPLOAD_FACES_DIR, exist_ok=True)
ALLOWED_IMG_EXT = {".png", ".jpg", ".jpeg", ".webp"}

mongo = PyMongo(app)
jwt = JWTManager(app)
csrf = CSRFProtect(app)

CORS(app, resources={
    r"/api/*": {"origins": "*"},
    r"/static/*": {"origins": "*"},
})

# =============================================================================
# Indexes & seed docs
# =============================================================================
with app.app_context():
    mongo.db.users.create_index("email", unique=True)
    mongo.db.users.create_index([("role", 1), ("is_active", 1)])
    mongo.db.products.create_index("sku", unique=True)
    mongo.db.products.create_index("slug")
    mongo.db.products.create_index([("name", "text"), ("brand", "text"), ("sku", "text")])
    mongo.db.categories.create_index("slug", unique=True)
    mongo.db.reviews.create_index([("product_id", 1), ("created_at", -1)])
    mongo.db.wishlists.create_index("user_id", unique=True)
    mongo.db.carts.create_index("user_id", unique=True)
    mongo.db.orders.create_index([("created_at", -1)])
    mongo.db.orders.create_index("status")
    mongo.db.orders.create_index("user_id")
    mongo.db.ai_profiles.create_index("user_id", unique=True)

    if not mongo.db.settings.find_one({"_id": "app"}):
        mongo.db.settings.insert_one({
            "_id": "app",
            "store_name": "Beauty Commerce",
            "currency_default": "LKR",
            "tax_rate": 0.0,
            "shipping_flat_rate": 0.0,
            "updated_at": datetime.utcnow(),
        })
    if not mongo.db.attributes.find_one({"_id": "face"}):
        mongo.db.attributes.insert_one({
            "_id": "face",
            "skin_types": [
                {"key": "oily_skin", "label": "Oily Skin"},
                {"key": "dry_skin", "label": "Dry Skin"},
                {"key": "normal_skin", "label": "Normal Skin"},
            ],
            "concerns": [
                {"key": "acne", "label": "Acne"},
                {"key": "blackheads", "label": "Blackheads"},
                {"key": "bumps", "label": "Bumps"},
                {"key": "dark_spots", "label": "Dark Spots"},
                {"key": "redness", "label": "Redness"},
                {"key": "broken_capillaries", "label": "Broken Capillaries"},
                {"key": "bruising_discoloration", "label": "Bruising/Discoloration"},
                {"key": "dryness_flaking", "label": "Dryness/Flaking"},
                {"key": "texture_roughness", "label": "Texture/Roughness"},
                {"key": "wound_barrier_damage", "label": "Wound/Barrier Damage"},
                {"key": "oozing_crusting", "label": "Oozing/Crusting"},
                {"key": "scarring", "label": "Scarring"},
                {"key": "fine_lines_wrinkles", "label": "Fine Lines/Wrinkles"},
                {"key": "blistering", "label": "Blistering"},
                {"key": "hypopigmentation", "label": "Hypopigmentation"},
                {"key": "discoloration", "label": "Discoloration"},
                {"key": "warts_skin_growth", "label": "Warts/Skin Growth"},
                {"key": "skin_tag", "label": "Skin Tag"},
                {"key": "abnormal_growth", "label": "Abnormal Growth"},
                {"key": "hives", "label": "Hives"},
                {"key": "inflammation_swelling", "label": "Inflammation/Swelling"},
                {"key": "abnormal_finding", "label": "Abnormal Finding"},
            ],
            "updated_at": datetime.utcnow(),
        })

# =============================================================================
# Helpers & Jinja
# =============================================================================
def user_to_dict(doc):
    if not doc:
        return None
    return {
        "id": str(doc["_id"]),
        "name": doc.get("name"),
        "email": doc.get("email"),
        "role": doc.get("role", "user"),
        "is_active": bool(doc.get("is_active", True)),
        "created_at": doc.get("created_at").isoformat() if doc.get("created_at") else None,
    }

def admin_exists() -> bool:
    return mongo.db.users.count_documents({"role": "admin"}) > 0

def get_admin_user():
    admin_id = session.get("admin_id")
    if not admin_id:
        return None
    try:
        return mongo.db.users.find_one({"_id": ObjectId(admin_id), "role": "admin"})
    except Exception:
        return None

def admin_login_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        if not get_admin_user():
            return redirect(url_for("admin_auth"))
        return view(*args, **kwargs)
    return wrapped

@app.context_processor
def inject_globals():
    a = get_admin_user()
    return {"admin": user_to_dict(a) if a else None, "csrf_token": generate_csrf}

@app.template_filter("currency")
def currency(v):
    try:
        settings = mongo.db.settings.find_one({"_id": "app"}) or {}
        cur = settings.get("currency_default", "LKR")
        return f"{cur} {float(v):,.2f}"
    except Exception:
        return "LKR 0.00"

@app.template_filter("dt")
def dt_filter(v):
    if isinstance(v, datetime):
        return v.strftime("%Y-%m-%d %H:%M")
    return v

@app.template_filter("status_chip")
def status_chip(st):
    st = (st or "").lower()
    if st in ["paid", "completed", "shipped", "processing"]:
        klass = "bg-green-100 text-green-800"
    elif st in ["pending"]:
        klass = "bg-yellow-100 text-yellow-800"
    elif st in ["canceled", "refunded"]:
        klass = "bg-red-100 text-red-800"
    else:
        klass = "bg-gray-100 text-gray-800"
    return f'<span class="px-2 py-0.5 rounded-full text-xs {klass}">{st.capitalize() if st else "Unknown"}</span>'

def safe_count(collection, filt=None):
    try:
        return mongo.db[collection].count_documents(filt or {})
    except Exception:
        return 0

def safe_sum_orders(match=None):
    try:
        pipeline = [
            {"$match": match or {}},
            {"$group": {"_id": None, "total": {"$sum": {"$ifNull": ["$total", 0]}}}},
        ]
        res = list(mongo.db.orders.aggregate(pipeline))
        return (res[0]["total"] if res else 0.0)
    except Exception:
        return 0.0

def slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")

# ---------- ABSOLUTE URL HELPER ----------
def abs_url(path: str | None) -> str | None:
    """
    Returns an absolute URL for a possibly-relative static path.
    - Leaves http(s) URLs untouched.
    - Returns None if input is falsy.
    """
    if not path:
        return None
    if str(path).startswith(("http://", "https://")):
        return path
    return urljoin(request.host_url, str(path).lstrip("/"))

def save_image(file_storage, folder="products"):
    if not file_storage or file_storage.filename == "":
        return None
    filename = secure_filename(file_storage.filename)
    ext = Path(filename).suffix.lower()
    if ext not in ALLOWED_IMG_EXT:
        return None
    new_name = f"{uuid.uuid4().hex}{ext}"
    base_dir = UPLOAD_PRODUCTS_DIR if folder == "products" else UPLOAD_FACES_DIR
    dest_path = os.path.join(base_dir, new_name)
    file_storage.save(dest_path)
    return f"/static/uploads/{folder}/{new_name}"

def delete_image_if_local(web_path: str):
    if not web_path:
        return
    if not web_path.startswith("/static/uploads/"):
        return
    disk_path = os.path.join(app.root_path, web_path.lstrip("/"))
    try:
        if os.path.exists(disk_path):
            os.remove(disk_path)
    except Exception:
        pass

def product_or_404(product_id):
    try:
        _id = ObjectId(product_id)
    except Exception:
        abort(404)
    doc = mongo.db.products.find_one({"_id": _id})
    if not doc:
        abort(404)
    return doc

def order_or_404(order_id):
    try:
        _id = ObjectId(order_id)
    except Exception:
        abort(404)
    doc = mongo.db.orders.find_one({"_id": _id})
    if not doc:
        abort(404)
    return doc

def _settings():
    return mongo.db.settings.find_one({"_id": "app"}) or {
        "currency_default": "LKR", "tax_rate": 0.0, "shipping_flat_rate": 0.0
    }

def compute_pricing(items):
    settings = _settings()
    tax_rate = float(settings.get("tax_rate", 0.0))
    shipping = float(settings.get("shipping_flat_rate", 0.0))
    currency = settings.get("currency_default", "LKR")

    line_items, subtotal = [], 0.0
    for it in items:
        pid = it.get("product_id")
        qty = max(1, int(it.get("qty", 1)))
        try:
            p = mongo.db.products.find_one({"_id": ObjectId(pid)})
        except Exception:
            p = None
        if not p:
            continue
        price = float(p.get("price", 0.0))
        sub = price * qty
        subtotal += sub
        line_items.append({
            "product_id": str(p["_id"]), "name": p.get("name"),
            "sku": p.get("sku"), "qty": qty, "price": price,
            "subtotal": sub,
            "hero_image": abs_url(p.get("hero_image"))
        })

    tax_total = round(subtotal * (tax_rate / 100.0), 2)
    total = round(subtotal + tax_total + shipping, 2)
    return {
        "currency": currency,
        "items": line_items,
        "subtotal": round(subtotal, 2),
        "tax_total": tax_total,
        "shipping_total": shipping,
        "total": total
    }

# =============================================================================
# Simple WTForms for admin
# =============================================================================
class AdminLoginForm(Form):
    email = StringField("email", [DataRequired(), Email()])
    password = PasswordField("password", [DataRequired(), Length(min=8)])

class AdminRegisterForm(Form):
    name = StringField("name", [DataRequired(), Length(min=2)])
    email = StringField("email", [DataRequired(), Email()])
    password = PasswordField("password", [DataRequired(), Length(min=8)])
    confirm = PasswordField("confirm", [DataRequired(), Length(min=8)])

class SettingsForm(Form):
    store_name = StringField("store_name", [DataRequired(), Length(min=2)])
    currency_default = StringField("currency_default", [DataRequired(), Length(min=2, max=6)])
    tax_rate = FloatField("tax_rate", [Optional()])
    shipping_flat_rate = FloatField("shipping_flat_rate", [Optional()])

# =============================================================================
# Admin Audit Log helper
# =============================================================================
def log_admin(action, resource, resource_id=None, meta=None):
    a = get_admin_user()
    mongo.db.admin_logs.insert_one({
        "at": datetime.utcnow(),
        "admin_id": str(a["_id"]) if a else None,
        "admin_email": a.get("email") if a else None,
        "admin_name": a.get("name") if a else None,
        "action": action,
        "resource": resource,
        "resource_id": str(resource_id) if resource_id else None,
        "meta": meta or {},
    })

# =============================================================================
# AI: Model loading (lazy, thread-safe) and helpers
# =============================================================================
_lesions_runner = None
_conditions_runner = None
_model_lock = threading.Lock()

SKIN_LESIONS_WEIGHTS = os.getenv("SKIN_LESIONS_WEIGHTS", "Skin_dis_Models/best_model.pth")
SKIN_COND_WEIGHTS = os.getenv("SKIN_COND_WEIGHTS", "Skin_conditions_Models/skin_type_best.pth")

def _ensure_models():
    global _lesions_runner, _conditions_runner
    if _lesions_runner is not None and _conditions_runner is not None:
        return
    with _model_lock:
        if _lesions_runner is None:
            _lesions_runner = ModelRunner(
                weights_path=SKIN_LESIONS_WEIGHTS,
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
        if _conditions_runner is None:
            _conditions_runner = ModelRunner(
                weights_path=SKIN_COND_WEIGHTS,
                labels=["Acne","Dark Spots","Oily Skin","Normal Skin","Blackheads","Dry Skin","Wrinkles"],
                arch="resnet50",
                activation="sigmoid",
            )

def _read_image_from_request() -> tuple[str, str]:
    """
    Returns (disk_web_path, disk_abs_path).
    Supports multipart file 'file' OR base64 in JSON 'image_base64'.
    """
    if "file" in request.files:
        web = save_image(request.files["file"], folder="faces")
        if not web:
            raise ValueError("Unsupported image type.")
        abs_path = os.path.join(app.root_path, web.lstrip("/"))
        return web, abs_path

    data = request.get_json(silent=True) or {}
    img_b64 = data.get("image_base64")
    if img_b64:
        if "," in img_b64:
            img_b64 = img_b64.split(",", 1)[1]
        try:
            raw = base64.b64decode(img_b64)
        except Exception:
            raise ValueError("Invalid base64 image.")
        fname = f"{uuid.uuid4().hex}.jpg"
        abs_path = os.path.join(UPLOAD_FACES_DIR, fname)
        with open(abs_path, "wb") as f:
            f.write(raw)
        web = f"/static/uploads/faces/{fname}"
        return web, abs_path

    raise ValueError("No image provided. Send multipart 'file' or JSON 'image_base64'.")

SKIN_LABEL_TO_KEY = {
    "Oily Skin": "oily_skin",
    "Dry Skin": "dry_skin",
    "Normal Skin": "normal_skin",
}

# =============================================================================
# API (MOBILE/FLUTTER) — v1 Blueprint
# =============================================================================
api = Blueprint("api", __name__, url_prefix="/api")
csrf.exempt(api)

# -------------------- Auth --------------------
@api.post("/auth/register")
def api_register():
    data = request.get_json(force=True) or {}
    name = (data.get("name") or "").strip()
    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""
    if not name or not email or not password:
        return jsonify({"error": "Name, email, and password are required."}), 400
    if len(password) < 8:
        return jsonify({"error": "Password must be at least 8 characters."}), 400
    if "@" not in email or "." not in email.split("@")[-1]:
        return jsonify({"error": "Invalid email format."}), 400
    try:
        doc = {
            "name": name, "email": email,
            "password_hash": generate_password_hash(password),
            "role": "user", "is_active": True,
            "addresses": [],
            "created_at": datetime.utcnow(),
        }
        res = mongo.db.users.insert_one(doc)
        doc["_id"] = res.inserted_id
    except Exception:
        return jsonify({"error": "Email already in use."}), 409
    access = create_access_token(identity=str(doc["_id"]))
    refresh = create_refresh_token(identity=str(doc["_id"]))
    return jsonify({"access_token": access, "refresh_token": refresh, "user": user_to_dict(doc)}), 201

@api.post("/auth/login")
def api_login():
    data = request.get_json(force=True) or {}
    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""
    if not email or not password:
        return jsonify({"error": "Email and password are required."}), 400
    user = mongo.db.users.find_one({"email": email})
    if not user or not user.get("is_active", True):
        return jsonify({"error": "Invalid email or account inactive."}), 401
    if not check_password_hash(user.get("password_hash", ""), password):
        return jsonify({"error": "Invalid email or password."}), 401
    access = create_access_token(identity=str(user["_id"]))
    refresh = create_refresh_token(identity=str(user["_id"]))
    return jsonify({"access_token": access, "refresh_token": refresh, "user": user_to_dict(user)}), 200

@api.post("/auth/refresh")
@jwt_required(refresh=True)
def api_refresh():
    uid = get_jwt_identity()
    access = create_access_token(identity=uid)
    return jsonify({"access_token": access})

@api.get("/auth/me")
@jwt_required()
def api_me():
    uid = get_jwt_identity()
    try:
        user = mongo.db.users.find_one({"_id": ObjectId(uid)})
    except Exception:
        user = None
    if not user:
        return jsonify({"error": "User not found."}), 404
    return jsonify({"user": user_to_dict(user)}), 200

@api.post("/auth/password/request-reset")
def api_password_request_reset():
    email = (request.get_json(force=True) or {}).get("email") or ""
    email = email.strip().lower()
    if not email:
        return jsonify({"error": "Email required."}), 400
    token = uuid.uuid4().hex
    mongo.db.password_resets.insert_one({
        "email": email, "token": token, "created_at": datetime.utcnow(), "used": False
    })
    return jsonify({"ok": True})

@api.post("/auth/password/reset")
def api_password_reset():
    data = request.get_json(force=True) or {}
    token = (data.get("token") or "").strip()
    newpw = data.get("password") or ""
    if len(newpw) < 8:
        return jsonify({"error": "Password must be at least 8 characters."}), 400
    pr = mongo.db.password_resets.find_one({"token": token, "used": False})
    if not pr:
        return jsonify({"error": "Invalid or used token."}), 400
    user = mongo.db.users.find_one({"email": pr["email"]})
    if not user:
        return jsonify({"error": "User not found."}), 404
    mongo.db.users.update_one({"_id": user["_id"]}, {"$set": {"password_hash": generate_password_hash(newpw)}})
    mongo.db.password_resets.update_one({"_id": pr["_id"]}, {"$set": {"used": True}})
    return jsonify({"ok": True})

# -------------------- Catalog / Discovery --------------------
@api.get("/categories")
def api_categories():
    cats = list(mongo.db.categories.find().sort("name", 1))
    out = [{"id": str(c["_id"]), "name": c.get("name"), "slug": c.get("slug"), "item_types": c.get("item_types", [])} for c in cats]
    return jsonify({"items": out})

@api.get("/attributes")
def api_attributes():
    attrs = mongo.db.attributes.find_one({"_id": "face"}) or {"skin_types": [], "concerns": []}
    return jsonify(attrs)

@api.get("/products")
def api_products():
    q = (request.args.get("q") or "").strip()
    category = (request.args.get("category") or "").strip()
    item_type = (request.args.get("item_type") or "").strip()
    concern = (request.args.get("concern") or "").strip()
    skin_type = (request.args.get("skin_type") or "").strip()
    page = max(1, int(request.args.get("page", 1)))
    per_page = min(int(request.args.get("per_page", 20)), 100)
    sort = (request.args.get("sort") or "-created_at").strip()

    filt = {"visibility": "public", "status": {"$ne": "archived"}}
    if q:
        filt["$text"] = {"$search": q}
    if category:
        try:
            cat = mongo.db.categories.find_one({"_id": ObjectId(category)})
            filt["category_id"] = str(cat["_id"]) if cat else None
        except Exception:
            filt["category"] = category
    if item_type:
        filt["item_type"] = item_type
    if concern:
        filt["concerns"] = concern
    if skin_type:
        filt["skin_types"] = skin_type

    sort_spec = [("created_at", -1)]
    if sort == "price":
        sort_spec = [("price", 1)]
    elif sort == "-price":
        sort_spec = [("price", -1)]
    elif sort == "name":
        sort_spec = [("name", 1)]
    elif sort == "-name":
        sort_spec = [("name", -1)]

    cur = (mongo.db.products
           .find(filt)
           .sort(sort_spec)
           .skip((page-1)*per_page)
           .limit(per_page))
    items = []
    for p in cur:
        items.append({
            "id": str(p["_id"]), "name": p.get("name"), "brand": p.get("brand"),
            "price": p.get("price", 0), "currency": p.get("currency", "LKR"),
            "hero_image": abs_url(p.get("hero_image")),
            "slug": p.get("slug"),
            "sku": p.get("sku"), "stock": p.get("stock", 0),
            "category": p.get("category"), "item_type": p.get("item_type"),
        })

    return jsonify({"items": items, "page": page, "per_page": per_page})

@api.get("/products/<id_or_slug>")
def api_product_detail(id_or_slug):
    p = None
    try:
        p = mongo.db.products.find_one({"_id": ObjectId(id_or_slug)})
    except Exception:
        p = mongo.db.products.find_one({"slug": id_or_slug})
    if not p or p.get("status") == "archived":
        return jsonify({"error": "Product not found."}), 404
    data = {
        "id": str(p["_id"]), "name": p.get("name"), "brand": p.get("brand"),
        "price": p.get("price", 0), "currency": p.get("currency", "LKR"),
        "stock": p.get("stock", 0), "status": p.get("status", "draft"),
        "hero_image": abs_url(p.get("hero_image")),
        "gallery": [abs_url(x) for x in (p.get("gallery") or [])],
        "alt_text": p.get("alt_text"), "short_description": p.get("short_description"),
        "description_html": p.get("description_html"), "sku": p.get("sku"),
        "category": p.get("category"), "item_type": p.get("item_type"),
        "skin_types": p.get("skin_types", []), "concerns": p.get("concerns", []),
        "size_volume": p.get("size_volume"), "country_of_origin": p.get("country_of_origin"),
        "slug": p.get("slug"), "tags": p.get("tags", []),
        "rating_avg": round(p.get("rating_avg", 0.0), 2),
        "rating_count": int(p.get("rating_count", 0)),
    }
    return jsonify(data)

@api.get("/products/<product_id>/related")
def api_product_related(product_id):
    try:
        p = mongo.db.products.find_one({"_id": ObjectId(product_id)})
    except Exception:
        return jsonify({"items": []})
    if not p:
        return jsonify({"items": []})
    filt = {
        "_id": {"$ne": p["_id"]},
        "category": p.get("category"),
        "visibility": "public", "status": {"$ne": "archived"}
    }
    cur = mongo.db.products.find(filt).sort("created_at", -1).limit(8)
    items = [{"id": str(x["_id"]), "name": x.get("name"),
              "price": x.get("price", 0), "currency": x.get("currency", "LKR"),
              "hero_image": abs_url(x.get("hero_image"))} for x in cur]
    return jsonify({"items": items})

@api.get("/search")
def api_search():
    q = (request.args.get("q") or "").strip()
    if not q:
        return jsonify({"items": []})
    print(q)
    cur = mongo.db.products.find({"$text": {"$search": q}, "visibility": "public"}).limit(20)
    items = [{"id": str(p["_id"]), "name": p.get("name"), "brand": p.get("brand"),
              "price": p.get("price", 0), "hero_image": abs_url(p.get("hero_image"))} for p in cur]
    print(items)
    return jsonify({"items": items})

@api.get("/home")
def api_home():
    new_arrivals = list(mongo.db.products.find({"visibility": "public"}).sort("created_at", -1).limit(8))
    top_rated = list(mongo.db.products.find({"rating_count": {"$gt": 2}}).sort("rating_avg", -1).limit(8))
    budget = list(mongo.db.products.find({"price": {"$lte": 2500}, "visibility": "public"}).sort("created_at", -1).limit(8))
    def pmap(p):
        return {"id": str(p["_id"]), "name": p.get("name"), "price": p.get("price", 0),
                "currency": p.get("currency", "LKR"), "hero_image": abs_url(p.get("hero_image"))}
    return jsonify({
        "new_arrivals": [pmap(x) for x in new_arrivals],
        "top_rated": [pmap(x) for x in top_rated],
        "budget_picks": [pmap(x) for x in budget],
    })

# -------------------- Reviews --------------------
@api.get("/products/<product_id>/reviews")
def api_reviews_list(product_id):
    try:
        _ = ObjectId(product_id)
    except Exception:
        return jsonify({"items": []})
    cur = mongo.db.reviews.find({"product_id": product_id}).sort("created_at", -1).limit(100)
    items = []
    for r in cur:
        items.append({
            "id": str(r["_id"]),
            "rating": int(r.get("rating", 0)),
            "title": r.get("title"),
            "body": r.get("body"),
            "user_name": r.get("user_name"),
            "created_at": r.get("created_at").isoformat() if r.get("created_at") else None
        })
    return jsonify({"items": items})

@api.post("/products/<product_id>/reviews")
@jwt_required()
def api_reviews_create(product_id):
    uid = get_jwt_identity()
    try:
        user = mongo.db.users.find_one({"_id": ObjectId(uid)})
        prod = mongo.db.products.find_one({"_id": ObjectId(product_id)})
    except Exception:
        user, prod = None, None
    if not user or not prod:
        return jsonify({"error": "Invalid user or product."}), 400
    data = request.get_json(force=True) or {}
    rating = int(data.get("rating", 0))
    if rating < 1 or rating > 5:
        return jsonify({"error": "Rating must be 1..5."}), 400
    doc = {
        "product_id": str(prod["_id"]),
        "user_id": str(user["_id"]),
        "user_name": user.get("name"),
        "rating": rating,
        "title": (data.get("title") or "").strip(),
        "body": (data.get("body") or "").strip(),
        "created_at": datetime.utcnow()
    }
    res = mongo.db.reviews.insert_one(doc)
    agg = list(mongo.db.reviews.aggregate([
        {"$match": {"product_id": str(prod["_id"])}},
        {"$group": {"_id": None, "average": {"$avg": "$rating"}, "count": {"$sum": 1}}}
    ]))
    if agg:
        mongo.db.products.update_one({"_id": prod["_id"]},
                                     {"$set": {"rating_avg": float(agg[0]["average"]),
                                               "rating_count": int(agg[0]["count"])}})
    return jsonify({"id": str(res.inserted_id)}), 201

@api.delete("/reviews/<review_id>")
@jwt_required()
def api_reviews_delete(review_id):
    uid = get_jwt_identity()
    try:
        r = mongo.db.reviews.find_one({"_id": ObjectId(review_id)})
    except Exception:
        r = None
    if not r or r.get("user_id") != uid:
        return jsonify({"error": "Not found or not allowed."}), 404
    mongo.db.reviews.delete_one({"_id": ObjectId(review_id)})
    prod_id = r.get("product_id")
    agg = list(mongo.db.reviews.aggregate([
        {"$match": {"product_id": prod_id}},
        {"$group": {"_id": None, "average": {"$avg": "$rating"}, "count": {"$sum": 1}}}
    ]))
    p = mongo.db.products.find_one({"_id": ObjectId(prod_id)})
    if p:
        avg = float(agg[0]["average"]) if agg else 0.0
        cnt = int(agg[0]["count"]) if agg else 0
        mongo.db.products.update_one({"_id": p["_id"]}, {"$set": {"rating_avg": avg, "rating_count": cnt}})
    return jsonify({"ok": True})

# -------------------- Wishlist --------------------
@api.get("/wishlist")
@jwt_required()
def api_wishlist_get():
    uid = get_jwt_identity()
    wl = mongo.db.wishlists.find_one({"user_id": uid}) or {"items": []}
    product_ids = wl.get("items", [])
    prods = list(mongo.db.products.find({"_id": {"$in": [ObjectId(pid) for pid in product_ids]}}))
    items = [{"id": str(p["_id"]), "name": p.get("name"), "price": p.get("price", 0),
              "currency": p.get("currency", "LKR"), "hero_image": abs_url(p.get("hero_image"))} for p in prods]
    return jsonify({"items": items})

@api.post("/wishlist/<product_id>")
@jwt_required()
def api_wishlist_add(product_id):
    uid = get_jwt_identity()
    try:
        _ = ObjectId(product_id)
    except Exception:
        return jsonify({"error": "Invalid product."}), 400
    mongo.db.wishlists.update_one({"user_id": uid}, {"$addToSet": {"items": product_id}}, upsert=True)
    return jsonify({"ok": True})

@api.delete("/wishlist/<product_id>")
@jwt_required()
def api_wishlist_remove(product_id):
    uid = get_jwt_identity()
    mongo.db.wishlists.update_one({"user_id": uid}, {"$pull": {"items": product_id}})
    return jsonify({"ok": True})

# -------------------- Addresses --------------------
@api.get("/addresses")
@jwt_required()
def api_addresses_list():
    uid = get_jwt_identity()
    u = mongo.db.users.find_one({"_id": ObjectId(uid)})
    return jsonify({"items": u.get("addresses", [])})

@api.post("/addresses")
@jwt_required()
def api_addresses_create():
    uid = get_jwt_identity()
    data = request.get_json(force=True) or {}
    addr = {
        "id": uuid.uuid4().hex,
        "name": (data.get("name") or "").strip(),
        "line1": (data.get("line1") or "").strip(),
        "line2": (data.get("line2") or "").strip(),
        "city": (data.get("city") or "").strip(),
        "region": (data.get("region") or "").strip(),
        "postal_code": (data.get("postal_code") or "").strip(),
        "country": (data.get("country") or "LK").strip().upper(),
        "phone": (data.get("phone") or "").strip(),
        "is_default": bool(data.get("is_default", False)),
        "created_at": datetime.utcnow()
    }
    if addr["is_default"]:
        mongo.db.users.update_one({"_id": ObjectId(uid)}, {"$set": {"addresses.$[].is_default": False}})
    mongo.db.users.update_one({"_id": ObjectId(uid)}, {"$push": {"addresses": addr}})
    return jsonify(addr), 201

@api.put("/addresses/<addr_id>")
@jwt_required()
def api_addresses_update(addr_id):
    uid = get_jwt_identity()
    data = request.get_json(force=True) or {}
    if data.get("is_default"):
        mongo.db.users.update_one({"_id": ObjectId(uid)}, {"$set": {"addresses.$[].is_default": False}})
    u = mongo.db.users.find_one({"_id": ObjectId(uid)})
    addrs = u.get("addresses", [])
    new_list = []
    for a in addrs:
        if a.get("id") == addr_id:
            a.update({
                "name": (data.get("name") or a.get("name", "")).strip(),
                "line1": (data.get("line1") or a.get("line1", "")).strip(),
                "line2": (data.get("line2") or a.get("line2", "")).strip(),
                "city": (data.get("city") or a.get("city", "")).strip(),
                "region": (data.get("region") or a.get("region", "")).strip(),
                "postal_code": (data.get("postal_code") or a.get("postal_code", "")).strip(),
                "country": (data.get("country") or a.get("country", "LK")).strip().upper(),
                "phone": (data.get("phone") or a.get("phone", "")).strip(),
                "is_default": bool(data.get("is_default", a.get("is_default", False))),
                "updated_at": datetime.utcnow()
            })
        new_list.append(a)
    mongo.db.users.update_one({"_id": ObjectId(uid)}, {"$set": {"addresses": new_list}})
    return jsonify({"ok": True})

@api.delete("/addresses/<addr_id>")
@jwt_required()
def api_addresses_delete(addr_id):
    uid = get_jwt_identity()
    mongo.db.users.update_one({"_id": ObjectId(uid)}, {"$pull": {"addresses": {"id": addr_id}}})
    return jsonify({"ok": True})

# -------------------- Cart & Checkout --------------------
@api.get("/cart")
@jwt_required()
def api_cart_get():
    uid = get_jwt_identity()
    cart = mongo.db.carts.find_one({"user_id": uid}) or {"items": []}
    price = compute_pricing(cart.get("items", []))
    return jsonify({"items": price["items"], "pricing": price})

@api.post("/cart")
@jwt_required()
def api_cart_add():
    uid = get_jwt_identity()
    data = request.get_json(force=True) or {}
    pid = data.get("product_id")
    qty = max(1, int(data.get("qty", 1)))
    if not pid:
        return jsonify({"error": "product_id required"}), 400
    cart = mongo.db.carts.find_one({"user_id": uid}) or {"user_id": uid, "items": []}
    merged = False
    for it in cart["items"]:
        if it.get("product_id") == pid:
            it["qty"] = it.get("qty", 1) + qty
            merged = True
            break
    if not merged:
        cart["items"].append({"product_id": pid, "qty": qty})
    mongo.db.carts.update_one({"user_id": uid}, {"$set": {"items": cart["items"], "updated_at": datetime.utcnow()}}, upsert=True)
    return jsonify({"ok": True})

@api.put("/cart/items/<product_id>")
@jwt_required()
def api_cart_update_item(product_id):
    uid = get_jwt_identity()
    qty = max(0, int((request.get_json(force=True) or {}).get("qty", 1)))
    cart = mongo.db.carts.find_one({"user_id": uid}) or {"items": []}
    new_items = []
    for it in cart["items"]:
        if it.get("product_id") == product_id:
            if qty > 0:
                it["qty"] = qty
                new_items.append(it)
        else:
            new_items.append(it)
    mongo.db.carts.update_one({"user_id": uid}, {"$set": {"items": new_items, "updated_at": datetime.utcnow()}}, upsert=True)
    return jsonify({"ok": True})

@api.delete("/cart/items/<product_id>")
@jwt_required()
def api_cart_delete_item(product_id):
    uid = get_jwt_identity()
    mongo.db.carts.update_one({"user_id": uid}, {"$pull": {"items": {"product_id": product_id}}})
    return jsonify({"ok": True})

@api.post("/cart/clear")
@jwt_required()
def api_cart_clear():
    uid = get_jwt_identity()
    mongo.db.carts.update_one({"user_id": uid}, {"$set": {"items": [], "updated_at": datetime.utcnow()}}, upsert=True)
    return jsonify({"ok": True})

@api.post("/cart/price")
def api_cart_price():
    data = request.get_json(force=True) or {}
    items = data.get("items", [])
    price = compute_pricing(items)
    return jsonify(price)

@api.post("/checkout")
@jwt_required(optional=True)
def api_checkout():
    data = request.get_json(force=True) or {}
    items = data.get("items")

    user_id = get_jwt_identity()

    if (not items) and user_id:
        cart = mongo.db.carts.find_one({"user_id": user_id}) or {"items": []}
        items = cart.get("items", [])

    if not items:
        return jsonify({"error": "No items to checkout."}), 400

    price_resp = compute_pricing(items)

    email = (data.get("email") or "").strip().lower()
    name = (data.get("name") or "").strip()

    if not email and user_id:
        u = mongo.db.users.find_one({"_id": ObjectId(user_id)})
        if u:
            email = (u.get("email") or "").strip().lower()
            if not name:
                name = (u.get("name") or "").strip()

    if not email:
        return jsonify({"error": "Email is required."}), 400

    shipping_address = data.get("shipping_address") or {}
    payment_method = (data.get("payment_method") or "cod").lower()

    now = datetime.utcnow()
    order_doc = {
        "order_no": f"BC-{now.strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}",
        "user_id": user_id,
        "email": email,
        "name": name,
        "items": price_resp["items"],
        "subtotal": price_resp["subtotal"],
        "shipping_total": price_resp["shipping_total"],
        "tax_total": price_resp["tax_total"],
        "total": price_resp["total"],
        "currency": price_resp["currency"],
        "status": "processing" if payment_method == "cod" else "pending",
        "shipping_address": shipping_address,
        "payment_method": payment_method,
        "created_at": now, "updated_at": now,
        "admin_notes": []
    }
    res = mongo.db.orders.insert_one(order_doc)

    if user_id and order_doc["status"] in ["processing", "paid"]:
        mongo.db.carts.update_one({"user_id": user_id}, {"$set": {"items": []}})

    return jsonify({
        "order_id": str(res.inserted_id),
        "order_no": order_doc["order_no"],
        "status": order_doc["status"]
    }), 201

@api.post("/payments/create-intent")
@jwt_required()
def api_payments_create_intent():
    amount = float((request.get_json(force=True) or {}).get("amount", 0.0))
    return jsonify({"client_secret": f"mock_secret_{uuid.uuid4().hex}", "amount": amount})

@api.get("/orders")
@jwt_required()
def api_orders_list():
    uid = get_jwt_identity()
    cur = mongo.db.orders.find({"user_id": uid}).sort("created_at", -1).limit(50)
    items = []
    for o in cur:
        items.append({
            "id": str(o["_id"]), "order_no": o.get("order_no"),
            "status": o.get("status"), "total": o.get("total"),
            "currency": o.get("currency", "LKR"),
            "created_at": o.get("created_at").isoformat() if o.get("created_at") else None
        })
    return jsonify({"items": items})

@api.get("/orders/<order_id>")
@jwt_required()
def api_orders_detail(order_id):
    uid = get_jwt_identity()
    try:
        o = mongo.db.orders.find_one({"_id": ObjectId(order_id), "user_id": uid})
    except Exception:
        o = None
    if not o:
        return jsonify({"error": "Not found."}), 404
    o["id"] = str(o["_id"])
    o["_id"] = None
    return jsonify(o)

@api.post("/orders/<order_id>/cancel")
@jwt_required()
def api_orders_cancel(order_id):
    uid = get_jwt_identity()
    o = mongo.db.orders.find_one({"_id": ObjectId(order_id), "user_id": uid})
    if not o:
        return jsonify({"error": "Not found."}), 404
    if o.get("status") not in ["pending", "processing"]:
        return jsonify({"error": "Order cannot be canceled now."}), 400
    mongo.db.orders.update_one({"_id": o["_id"]}, {"$set": {"status": "canceled", "updated_at": datetime.utcnow()}})
    return jsonify({"ok": True})

# -------------------- AI: Face analysis & personalized recommendations --------------------
def _analyze_face_from_path(img_abs_path):
    _ensure_models()
    img_bgr = cv2.imread(img_abs_path)
    if img_bgr is None:
        raise ValueError("Failed to read image.")
    combined = run_combined_AI_from_cv2(
        img_bgr,
        lesions_runner=_lesions_runner,
        conditions_runner=_conditions_runner,
        size=224, cond_threshold=0.15, lesion_high_thr=0.30, lesion_low_thr=0.15
    )
    merged = merge_concerns_sections(combined)
    return combined, merged

@api.get("/ai/profile")
@jwt_required()
def api_ai_profile_get():
    uid = get_jwt_identity()
    prof = mongo.db.ai_profiles.find_one({"user_id": uid})
    if not prof:
        return jsonify({"has_profile": False, "message": "No analysis yet. Please upload a face photo to continue."})
    prof_out = dict(prof)
    prof_out["id"] = str(prof["_id"])
    prof_out["_id"] = None
    prof_out["image_url"] = abs_url(prof.get("image_path"))
    return jsonify({"has_profile": True, "profile": prof_out})

@api.delete("/ai/profile")
@jwt_required()
def api_ai_profile_delete():
    uid = get_jwt_identity()
    prof = mongo.db.ai_profiles.find_one({"user_id": uid})
    if prof and prof.get("image_path"):
        delete_image_if_local(prof["image_path"])
    mongo.db.ai_profiles.delete_one({"user_id": uid})
    return jsonify({"ok": True})

@api.post("/ai/analyze")
@jwt_required(optional=True)
def api_ai_analyze():
    uid = get_jwt_identity()
    try:
        web_path, abs_path = _read_image_from_request()
    except Exception as e:
        return jsonify({"error": str(e)}), 400

    try:
        combined, merged = _analyze_face_from_path(abs_path)

    except FileNotFoundError as e:
        return jsonify({"error": f"Model weights not found: {e}"}), 503
    except Exception as e:
        return jsonify({"error": f"AI analysis failed: {e}"}), 500

    if uid:
        doc = {
            "user_id": uid,
            "image_path": web_path,
            "result": combined,
            "merged": merged,
            "skin_type": combined.get("skin_type", {}),
            "updated_at": datetime.utcnow()
        }
        mongo.db.ai_profiles.update_one({"user_id": uid}, {"$set": doc}, upsert=True)

    return jsonify({
        "saved": bool(uid),
        "image_path": web_path,
        "image_url": abs_url(web_path),
        "result": combined,
        "merged": merged
    })

def _score_product_for_profile(prod, merged_concerns, skin_label):
    """
    Score a product based on:
      +2 per matched concern label
      +1 if product supports user's skin type
    """
    score = 0.0
    matches = []
    prod_concerns = set(prod.get("concerns", []) or [])
    for lbl, payload in merged_concerns.items():
        if lbl in prod_concerns:
            score += 2.0 * float(payload.get("prob", 0.0))
            matches.append(lbl)

    skin_key = SKIN_LABEL_TO_KEY.get((skin_label or "").strip(), None)
    if skin_key and skin_key in (prod.get("skin_types") or []):
        score += 1.0
        matches.append(f"skin:{skin_key}")

    return score, matches

@api.get("/recommendations")
@jwt_required(optional=True)
def api_recommendations():
    """
    Personalized if available:
      - If user is logged in and has AI profile, use it.
      - Else, if client provides ?skin_type= and &concerns=comma,separated, use that.
      - Else, generic fallback (top rated / new arrivals).
    """
    uid = get_jwt_identity()
    prof = mongo.db.ai_profiles.find_one({"user_id": uid}) if uid else None

    skin_label = None
    merged = None

    if not prof:
        skin_label = request.args.get("skin_type")
        concerns_csv = (request.args.get("concerns") or "").strip()
        if skin_label or concerns_csv:
            merged = {}
            for c in [c.strip() for c in concerns_csv.split(",") if c.strip()]:
                merged[c] = {"prob": 0.3, "source": ["manual"]}
        else:
            new_arrivals = list(mongo.db.products.find({"visibility": "public"}).sort("created_at", -1).limit(24))
            top_rated = list(mongo.db.products.find({"rating_count": {"$gt": 2}}).sort("rating_avg", -1).limit(24))
            def p(p): return {"id": str(p["_id"]), "name": p.get("name"), "price": p.get("price", 0),
                              "currency": p.get("currency", "LKR"), "hero_image": abs_url(p.get("hero_image"))}
            return jsonify({
                "personalized": False,
                "reason": "No profile and no signals supplied. Showing generic picks.",
                "new_arrivals": [p(x) for x in new_arrivals],
                "top_rated": [p(x) for x in top_rated]
            })

    else:
        skin_label = (prof.get("skin_type") or {}).get("label")
        merged = prof.get("merged") or {}

    candidates = list(mongo.db.products.find({
        "visibility": "public",
        "status": {"$ne": "archived"}
    }).sort("created_at", -1).limit(300))

    scored = []
    for pr in candidates:
        score, matches = _score_product_for_profile(pr, merged, skin_label)
        if score <= 0:
            continue
        scored.append((score, matches, pr))

    scored.sort(key=lambda x: x[0], reverse=True)
    top = scored[:48]

    items = []
    for score, matches, p in top:
        items.append({
            "id": str(p["_id"]),
            "name": p.get("name"),
            "brand": p.get("brand"),
            "price": p.get("price", 0),
            "currency": p.get("currency", "LKR"),
            "hero_image": abs_url(p.get("hero_image")),
            "score": round(float(score), 3),
            "matches": matches
        })

    return jsonify({
        "personalized": True,
        "skin_type": skin_label,
        "signals": list(merged.keys()),
        "items": items
    })

app.register_blueprint(api)

# =============================================================================
# ADMIN PANEL
# =============================================================================

# ---------- Admin Auth ----------
@app.get("/admin")
def admin_auth():
    show_register = not admin_exists()
    return render_template("admin_auth.html", show_register=show_register, hide_nav=True)

@app.post("/admin/register")
def admin_register():
    if admin_exists():
        flash("Admin already exists. Please log in.", "warning")
        return redirect(url_for("admin_auth"))
    form = AdminRegisterForm(request.form)
    if not form.validate():
        flash("Please check your inputs.", "error")
        return redirect(url_for("admin_auth"))
    name, email, password, confirm = form.name.data.strip(), form.email.data.strip().lower(), form.password.data, form.confirm.data
    if password != confirm:
        flash("Passwords do not match.", "error")
        return redirect(url_for("admin_auth"))
    try:
        doc = {"name": name, "email": email, "password_hash": generate_password_hash(password),
               "role": "admin", "is_active": True, "created_at": datetime.utcnow()}
        res = mongo.db.users.insert_one(doc)
        session["admin_id"] = str(res.inserted_id)
        flash("Admin account created. Welcome!", "success")
    except Exception:
        flash("Email already in use.", "error")
        return redirect(url_for("admin_auth"))
    return redirect(url_for("admin_dashboard"))

@app.post("/admin/login")
def admin_login():
    if not admin_exists():
        flash("No admin found. Please create one.", "warning")
        return redirect(url_for("admin_auth"))
    form = AdminLoginForm(request.form)
    if not form.validate():
        flash("Invalid credentials.", "error")
        return redirect(url_for("admin_auth"))
    email, password = form.email.data.strip().lower(), form.password.data
    user = mongo.db.users.find_one({"email": email})
    if not user or user.get("role") != "admin" or not user.get("is_active", True):
        flash("Invalid credentials.", "error")
        return redirect(url_for("admin_auth"))
    if not check_password_hash(user.get("password_hash", ""), password):
        flash("Invalid credentials.", "error")
        return redirect(url_for("admin_auth"))
    session["admin_id"] = str(user["_id"])
    flash("Logged in successfully.", "success")
    return redirect(url_for("admin_dashboard"))

@app.get("/admin/logout")
def admin_logout():
    session.pop("admin_id", None)
    flash("You have been logged out.", "success")
    return redirect(url_for("admin_auth"))

# ---------- Dashboard ----------
@app.get("/admin/dashboard")
@admin_login_required
def admin_dashboard():
    total_users    = safe_count("users", {"role": {"$ne": "admin"}})
    total_admins   = safe_count("users", {"role": "admin"})
    total_products = safe_count("products")
    total_orders   = safe_count("orders")
    revenue_all    = safe_sum_orders({"status": {"$in": ["paid", "processing", "shipped", "completed"]}})
    today = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    start = today - timedelta(days=6)
    match_last7 = {
        "created_at": {"$gte": start, "$lte": today + timedelta(days=1)},
        "status": {"$in": ["paid", "processing", "shipped", "completed"]},
    }
    try:
        orders_daily = list(mongo.db.orders.aggregate([
            {"$match": match_last7},
            {"$group": {
                "_id": {"$dateToString": {"format": "%Y-%m-%d", "date": "$created_at"}},
                "orders": {"$sum": 1},
                "revenue": {"$sum": {"$ifNull": ["$total", 0]}}},
            },
        ]))
        daily_map = {row["_id"]: row for row in orders_daily}
    except Exception:
        daily_map = {}
    labels, orders_series, revenue_series = [], [], []
    for i in range(7):
        d = (start + timedelta(days=i)).strftime("%Y-%m-%d")
        labels.append(d)
        orders_series.append(int(daily_map.get(d, {}).get("orders", 0)))
        revenue_series.append(float(daily_map.get(d, {}).get("revenue", 0.0)))
    revenue_7d_total = sum(revenue_series)
    recent_orders = list(mongo.db.orders.find().sort("created_at", -1).limit(5))
    low_stock = list(mongo.db.products.find({"stock": {"$lte": 10}}).sort("stock", 1).limit(8))
    return render_template(
        "dashboard.html",
        kpis={
            "users": total_users, "admins": total_admins, "products": total_products,
            "orders": total_orders, "revenue_all": revenue_all, "revenue_7d": revenue_7d_total,
        },
        chart={"labels": labels, "orders": orders_series, "revenue": revenue_series},
        recent_orders=recent_orders, low_stock=low_stock
    )

# ---------- Users (admin) ----------
@app.get("/admin/users")
@admin_login_required
def users_list():
    q = (request.args.get("q") or "").strip()
    role = (request.args.get("role") or "").strip()
    status = (request.args.get("status") or "").strip()
    filt = {}
    if q:
        filt["$or"] = [{"name": {"$regex": q, "$options": "i"}}, {"email": {"$regex": q, "$options": "i"}}]
    if role in ["user", "admin"]:
        filt["role"] = role
    if status == "active":
        filt["is_active"] = True
    elif status == "inactive":
        filt["is_active"] = False
    page = max(1, int(request.args.get("page", 1)))
    per_page = 20
    cur = mongo.db.users.find(filt).sort("created_at", -1).skip((page-1)*per_page)
    users = list(cur.limit(per_page + 1))
    has_next = len(users) > per_page
    users = users[:per_page]
    return render_template("users_list.html", users=users, q=q, role=role, status=status, page=page, has_next=has_next)

@app.get("/admin/users/<user_id>")
@admin_login_required
def users_show(user_id):
    try:
        u = mongo.db.users.find_one({"_id": ObjectId(user_id)})
    except Exception:
        abort(404)
    if not u:
        abort(404)
    orders = list(mongo.db.orders.find({"user_id": str(u["_id"])}).sort("created_at", -1).limit(20))
    return render_template("users_show.html", u=u, orders=orders)

@app.get("/admin/users/<user_id>/edit")
@admin_login_required
def users_edit(user_id):
    try:
        u = mongo.db.users.find_one({"_id": ObjectId(user_id)})
    except Exception:
        abort(404)
    if not u:
        abort(404)
    return render_template("users_edit.html", u=u)

@app.post("/admin/users/<user_id>/edit")
@admin_login_required
def users_update(user_id):
    try:
        u = mongo.db.users.find_one({"_id": ObjectId(user_id)})
    except Exception:
        abort(404)
    if not u:
        abort(404)

    name = (request.form.get("name") or "").strip()
    email = (request.form.get("email") or "").strip().lower()
    role = (request.form.get("role") or u.get("role", "user")).strip()
    active = request.form.get("is_active") == "on"
    new_password = request.form.get("new_password") or ""

    if u.get("role") == "admin":
        admin_count = mongo.db.users.count_documents({"role": "admin", "is_active": True})
        if (role != "admin" or not active) and admin_count <= 1:
            flash("Cannot demote/deactivate the last active admin.", "error")
            return redirect(url_for("users_edit", user_id=user_id))

    update = {
        "name": name or u.get("name"),
        "email": email or u.get("email"),
        "role": role if role in ["user", "admin"] else u.get("role", "user"),
        "is_active": active,
    }
    if new_password:
        if len(new_password) < 8:
            flash("New password must be at least 8 characters.", "error")
            return redirect(url_for("users_edit", user_id=user_id))
        update["password_hash"] = generate_password_hash(new_password)

    try:
        mongo.db.users.update_one({"_id": u["_id"]}, {"$set": update})
        log_admin("update", "user", u["_id"], {"email": update["email"]})
        flash("User updated.", "success")
    except Exception as e:
        flash(f"Update failed: {e}", "error")
    return redirect(url_for("users_show", user_id=user_id))

@app.post("/admin/users/<user_id>/toggle-active")
@admin_login_required
def users_toggle_active(user_id):
    try:
        u = mongo.db.users.find_one({"_id": ObjectId(user_id)})
    except Exception:
        abort(404)
    if not u:
        abort(404)

    new_active = not bool(u.get("is_active", True))
    if u.get("role") == "admin" and not new_active:
        admin_count = mongo.db.users.count_documents({"role": "admin", "is_active": True})
        if admin_count <= 1:
            flash("Cannot deactivate the last active admin.", "error")
            return redirect(url_for("users_show", user_id=user_id))

    mongo.db.users.update_one({"_id": u["_id"]}, {"$set": {"is_active": new_active}})
    log_admin("update", "user", u["_id"], {"is_active": new_active})
    flash("User status updated.", "success")
    return redirect(url_for("users_show", user_id=user_id))

@app.get("/admin/users/new")
@admin_login_required
def users_new():
    return render_template("users_edit.html", u=None)

@app.post("/admin/users/new")
@admin_login_required
def users_create():
    name = (request.form.get("name") or "").strip()
    email = (request.form.get("email") or "").strip().lower()
    role = (request.form.get("role") or "user").strip()
    password = request.form.get("new_password") or ""

    if not name or not email or not password:
        flash("Name, email and password required.", "error")
        return redirect(url_for("users_new"))
    if len(password) < 8:
        flash("Password must be at least 8 characters.", "error")
        return redirect(url_for("users_new"))

    try:
        doc = {
            "name": name, "email": email,
            "password_hash": generate_password_hash(password),
            "role": "admin" if role == "admin" else "user",
            "is_active": True,
            "addresses": [],
            "created_at": datetime.utcnow(),
        }
        res = mongo.db.users.insert_one(doc)
        log_admin("create", "user", res.inserted_id, {"email": email})
        flash("User created.", "success")
        return redirect(url_for("users_show", user_id=str(res.inserted_id)))
    except Exception as e:
        flash(f"Failed to create user: {e}", "error")
        return redirect(url_for("users_new"))

# ---------- Products (admin) ----------
@app.get("/admin/products")
@admin_login_required
def products_list_admin():
    q = (request.args.get("q") or "").strip()
    status = (request.args.get("status") or "").strip()
    filt = {}
    if q:
        filt["$or"] = [
            {"name": {"$regex": q, "$options": "i"}},
            {"brand": {"$regex": q, "$options": "i"}},
            {"sku": {"$regex": q, "$options": "i"}},
        ]
    if status:
        filt["status"] = status
    page = max(1, int(request.args.get("page", 1)))
    per_page = 20
    cur = mongo.db.products.find(filt).sort("created_at", -1).skip((page-1)*per_page)
    products = list(cur.limit(per_page + 1))
    has_next = len(products) > per_page
    products = products[:per_page]
    return render_template("products_list.html", products=products, q=q, status=status, page=page, has_next=has_next)

@app.get("/admin/products/new")
@admin_login_required
def products_new_admin():
    categories = list(mongo.db.categories.find().sort("name", 1))
    attrs = mongo.db.attributes.find_one({"_id": "face"}) or {"skin_types": [], "concerns": []}
    return render_template("products_new.html", categories=categories, attributes=attrs)

@app.post("/admin/products")
@admin_login_required
def products_create_admin():
    form = request.form
    files = request.files

    name = (form.get("name") or "").strip()
    brand = (form.get("brand") or "").strip()
    category_id = form.get("category_id") or ""
    item_type = (form.get("item_type") or "").strip()
    sku = (form.get("sku") or "").strip()
    price = form.get("price") or "0"
    currency = (form.get("currency") or "LKR").strip()
    stock = form.get("stock") or "0"
    status = (form.get("status") or "draft").strip()

    short_description = (form.get("short_description") or "").strip()
    description_html = (form.get("description_html") or "").strip()
    alt_text = (form.get("alt_text") or "").strip()
    size_volume = (form.get("size_volume") or "").strip()
    country_of_origin = (form.get("country_of_origin") or "").strip()
    tags_str = (form.get("tags") or "").strip()

    skin_types = request.form.getlist("skin_types")
    concerns = request.form.getlist("concerns")

    if not all([name, brand, category_id, item_type, sku]):
        flash("Name, Brand, Category, Item Type, and SKU are required.", "error")
        return redirect(url_for("products_new_admin"))

    try: price = float(price)
    except ValueError: price = 0.0
    try: stock = int(stock)
    except ValueError: stock = 0

    hero_path = save_image(files.get("hero_image"))
    gallery_paths = []
    for f in request.files.getlist("gallery"):
        p_ = save_image(f)
        if p_: gallery_paths.append(p_)

    now = datetime.utcnow()
    admin_u = get_admin_user()
    cat = None
    try:
        cat = mongo.db.categories.find_one({"_id": ObjectId(category_id)})
    except Exception:
        pass
    category_name = cat.get("name") if cat else "Uncategorized"

    doc = {
        "name": name, "brand": brand,
        "category_id": str(cat["_id"]) if cat else None,
        "category": category_name,
        "item_type": item_type,
        "sku": sku, "price": price, "currency": currency, "stock": stock, "status": status,
        "skin_types": skin_types, "concerns": concerns,
        "hero_image": hero_path, "gallery": gallery_paths, "alt_text": alt_text,
        "short_description": short_description, "description_html": description_html,
        "size_volume": size_volume, "country_of_origin": country_of_origin,
        "slug": slugify(name), "visibility": "public",
        "tags": [t.strip() for t in tags_str.split(",") if t.strip()],
        "rating_avg": 0.0, "rating_count": 0,
        "created_at": now, "updated_at": now,
        "created_by_admin_id": str(admin_u["_id"]) if admin_u else None,
        "updated_by_admin_id": str(admin_u["_id"]) if admin_u else None,
    }
    try:
        mongo.db.products.insert_one(doc)
        flash("Product added successfully.", "success")
        return redirect(url_for("products_list_admin"))
    except Exception as e:
        flash(f"Failed to save product: {e}", "error")
        return redirect(url_for("products_new_admin"))

@app.get("/admin/products/<product_id>")
@admin_login_required
def products_show_admin(product_id):
    p = product_or_404(product_id)
    return render_template("products_show.html", p=p)

@app.get("/admin/products/<product_id>/edit")
@admin_login_required
def products_edit_admin(product_id):
    p = product_or_404(product_id)
    categories = list(mongo.db.categories.find().sort("name", 1))
    attrs = mongo.db.attributes.find_one({"_id": "face"}) or {"skin_types": [], "concerns": []}
    return render_template("products_edit.html", p=p, categories=categories, attributes=attrs)

@app.post("/admin/products/<product_id>")
@admin_login_required
def products_update_admin(product_id):
    p = product_or_404(product_id)
    form = request.form
    files = request.files

    name = (form.get("name") or "").strip()
    brand = (form.get("brand") or "").strip()
    category_id = form.get("category_id") or ""
    item_type = (form.get("item_type") or "").strip()
    sku = (form.get("sku") or "").strip()
    price = form.get("price") or "0"
    currency = (form.get("currency") or "LKR").strip()
    stock = form.get("stock") or "0"
    status = (form.get("status") or "draft").strip()

    short_description = (form.get("short_description") or "").strip()
    description_html = (form.get("description_html") or "").strip()
    alt_text = (form.get("alt_text") or "").strip()
    size_volume = (form.get("size_volume") or "").strip()
    country_of_origin = (form.get("country_of_origin") or "").strip()
    tags_str = (form.get("tags") or "").strip()

    skin_types = request.form.getlist("skin_types")
    concerns = request.form.getlist("concerns")
    clear_gallery = form.get("clear_gallery") == "on"

    if not all([name, brand, category_id, item_type, sku]):
        flash("Name, Brand, Category, Item Type, and SKU are required.", "error")
        return redirect(url_for("products_edit_admin", product_id=product_id))

    try: price = float(price)
    except ValueError: price = 0.0
    try: stock = int(stock)
    except ValueError: stock = 0

    hero_new = save_image(files.get("hero_image"))
    gallery_new = [p_ for f in request.files.getlist("gallery") if (p_ := save_image(f))]

    admin_u = get_admin_user()
    cat = None
    try:
        cat = mongo.db.categories.find_one({"_id": ObjectId(category_id)})
    except Exception:
        pass
    category_name = cat.get("name") if cat else "Uncategorized"

    update = {
        "name": name, "brand": brand,
        "category_id": str(cat["_id"]) if cat else None, "category": category_name,
        "item_type": item_type, "sku": sku, "price": price, "currency": currency,
        "stock": stock, "status": status, "skin_types": skin_types, "concerns": concerns,
        "short_description": short_description, "description_html": description_html,
        "size_volume": size_volume, "country_of_origin": country_of_origin,
        "alt_text": alt_text, "slug": slugify(name), "visibility": "public",
        "tags": [t.strip() for t in tags_str.split(",") if t.strip()],
        "updated_at": datetime.utcnow(),
        "updated_by_admin_id": str(admin_u["_id"]) if admin_u else None,
    }

    if hero_new:
        if p.get("hero_image"): delete_image_if_local(p["hero_image"])
        update["hero_image"] = hero_new
    else:
        update["hero_image"] = p.get("hero_image")

    if clear_gallery:
        for old in p.get("gallery", []): delete_image_if_local(old)
        update["gallery"] = gallery_new
    else:
        update["gallery"] = (p.get("gallery") or []) + gallery_new

    try:
        mongo.db.products.update_one({"_id": p["_id"]}, {"$set": update})
        flash("Product updated.", "success")
        return redirect(url_for("products_list_admin"))
    except Exception as e:
        flash(f"Update failed: {e}", "error")
        return redirect(url_for("products_edit_admin", product_id=product_id))

@app.post("/admin/products/<product_id>/delete")
@admin_login_required
def products_delete_admin(product_id):
    p = product_or_404(product_id)
    if p.get("hero_image"):
        delete_image_if_local(p["hero_image"])
    for g in p.get("gallery", []):
        delete_image_if_local(g)
    try:
        mongo.db.products.delete_one({"_id": p["_id"]})
        flash("Product deleted.", "success")
    except Exception as e:
        flash(f"Delete failed: {e}", "error")
    return redirect(url_for("products_list_admin"))

# ---------- Orders (admin) ----------
ORDER_STATUSES = ["pending", "paid", "processing", "shipped", "completed", "canceled", "refunded"]

@app.get("/admin/orders")
@admin_login_required
def orders_list_admin():
    status = (request.args.get("status") or "").strip()
    q = (request.args.get("q") or "").strip()
    filt = {}
    if status in ORDER_STATUSES:
        filt["status"] = status
    if q:
        try:
            _id = ObjectId(q)
            filt["_id"] = _id
        except Exception:
            filt["$or"] = [{"email": {"$regex": q, "$options": "i"}}, {"order_no": {"$regex": q, "$options": "i"}}]
    page = max(1, int(request.args.get("page", 1)))
    per_page = 20
    cur = mongo.db.orders.find(filt).sort("created_at", -1).skip((page-1)*per_page)
    orders = list(cur.limit(per_page + 1))
    has_next = len(orders) > per_page
    orders = orders[:per_page]
    user_ids = list({o.get("user_id") for o in orders if o.get("user_id")})
    users_map = {}
    if user_ids:
        udocs = mongo.db.users.find({"_id": {"$in": [ObjectId(uid) for uid in user_ids if uid]}})
        for u in udocs:
            users_map[str(u["_id"])] = u
    return render_template("orders_list.html",
                           orders=orders, users_map=users_map,
                           status=status, q=q, page=page, has_next=has_next,
                           ORDER_STATUSES=ORDER_STATUSES)

@app.get("/admin/orders/<order_id>")
@admin_login_required
def orders_show_admin(order_id):
    o = order_or_404(order_id)
    user = mongo.db.users.find_one({"_id": ObjectId(o.get("user_id"))}) if o.get("user_id") else None
    return render_template("orders_show.html", o=o, user=user, ORDER_STATUSES=ORDER_STATUSES)

@app.post("/admin/orders/<order_id>/status")
@admin_login_required
def orders_update_status_admin(order_id):
    o = order_or_404(order_id)
    status = (request.form.get("status") or "").strip().lower()
    if status not in ORDER_STATUSES:
        flash("Invalid status.", "error")
        return redirect(url_for("orders_show_admin", order_id=order_id))
    mongo.db.orders.update_one({"_id": o["_id"]}, {"$set": {"status": status, "updated_at": datetime.utcnow()}})
    flash("Order status updated.", "success")
    return redirect(url_for("orders_show_admin", order_id=order_id))

@app.post("/admin/orders/<order_id>/note")
@admin_login_required
def orders_add_note_admin(order_id):
    o = order_or_404(order_id)
    note = (request.form.get("note") or "").strip()
    if not note:
        flash("Note cannot be empty.", "error")
        return redirect(url_for("orders_show_admin", order_id=order_id))
    admin_u = get_admin_user()
    mongo.db.orders.update_one(
        {"_id": o["_id"]},
        {"$push": {"admin_notes": {
            "note": note, "at": datetime.utcnow(),
            "by": str(admin_u["_id"]) if admin_u else None,
            "by_name": admin_u.get("name") if admin_u else None
        }}}
    )
    flash("Note added.", "success")
    return redirect(url_for("orders_show_admin", order_id=order_id))

@app.post("/admin/orders/<order_id>/cancel")
@admin_login_required
def orders_cancel_admin(order_id):
    o = order_or_404(order_id)
    if o.get("status") in ["completed", "refunded", "canceled"]:
        flash("Order cannot be canceled in its current state.", "error")
        return redirect(url_for("orders_show_admin", order_id=order_id))
    mongo.db.orders.update_one({"_id": o["_id"]}, {"$set": {"status": "canceled", "updated_at": datetime.utcnow()}})
    flash("Order canceled.", "success")
    return redirect(url_for("orders_show_admin", order_id=order_id))

@app.post("/admin/orders/<order_id>/refund")
@admin_login_required
def orders_refund_admin(order_id):
    o = order_or_404(order_id)
    if o.get("status") not in ["paid", "processing", "shipped", "completed"]:
        flash("Only paid/processed/shipped/completed orders may be refunded.", "error")
        return redirect(url_for("orders_show_admin", order_id=order_id))
    mongo.db.orders.update_one({"_id": o["_id"]}, {"$set": {"status": "refunded", "updated_at": datetime.utcnow()}})
    flash("Order marked as refunded.", "success")
    return redirect(url_for("orders_show_admin", order_id=order_id))

# ---------- Settings / Categories / Attributes ----------
@app.get("/admin/settings")
@admin_login_required
def settings_view():
    settings = mongo.db.settings.find_one({"_id": "app"}) or {}
    return render_template("settings.html", settings=settings)

@app.post("/admin/settings")
@admin_login_required
def settings_update():
    form = SettingsForm(request.form)
    if not form.validate():
        flash("Please fill all required fields.", "error")
        return redirect(url_for("settings_view"))
    data = {
        "store_name": form.store_name.data.strip(),
        "currency_default": form.currency_default.data.strip().upper(),
        "tax_rate": float(form.tax_rate.data or 0.0),
        "shipping_flat_rate": float(form.shipping_flat_rate.data or 0.0),
        "updated_at": datetime.utcnow(),
    }
    mongo.db.settings.update_one({"_id": "app"}, {"$set": data}, upsert=True)
    flash("Settings updated.", "success")
    return redirect(url_for("settings_view"))

@app.get("/admin/categories")
@admin_login_required
def categories_list():
    cats = list(mongo.db.categories.find().sort("name", 1))
    return render_template("categories_list.html", categories=cats)

@app.get("/admin/categories/new")
@admin_login_required
def categories_new():
    return render_template("categories_edit.html", c=None)

@app.post("/admin/categories/new")
@admin_login_required
def categories_create():
    name = (request.form.get("name") or "").strip()
    item_types = [t.strip() for t in (request.form.get("item_types") or "").split(",") if t.strip()]
    if not name:
        flash("Name required.", "error")
        return redirect(url_for("categories_new"))
    doc = {"name": name, "slug": slugify(name), "item_types": item_types,
           "created_at": datetime.utcnow(), "updated_at": datetime.utcnow()}
    try:
        mongo.db.categories.insert_one(doc)
        flash("Category created.", "success")
    except Exception as e:
        flash(f"Failed to create: {e}", "error")
        return redirect(url_for("categories_new"))
    return redirect(url_for("categories_list"))

@app.get("/admin/categories/<cid>/edit")
@admin_login_required
def categories_edit(cid):
    try:
        c = mongo.db.categories.find_one({"_id": ObjectId(cid)})
    except Exception:
        abort(404)
    if not c: abort(404)
    return render_template("categories_edit.html", c=c)

@app.post("/admin/categories/<cid>/edit")
@admin_login_required
def categories_update(cid):
    try:
        c = mongo.db.categories.find_one({"_id": ObjectId(cid)})
    except Exception:
        abort(404)
    if not c: abort(404)
    name = (request.form.get("name") or "").strip()
    item_types = [t.strip() for t in (request.form.get("item_types") or "").split(",") if t.strip()]
    if not name:
        flash("Name required.", "error")
        return redirect(url_for("categories_edit", cid=cid))
    update = {"name": name, "slug": slugify(name), "item_types": item_types, "updated_at": datetime.utcnow()}
    mongo.db.categories.update_one({"_id": c["_id"]}, {"$set": update})
    flash("Category updated.", "success")
    return redirect(url_for("categories_list"))

@app.post("/admin/categories/<cid>/delete")
@admin_login_required
def categories_delete(cid):
    try:
        c = mongo.db.categories.find_one({"_id": ObjectId(cid)})
    except Exception:
        abort(404)
    if not c: abort(404)
    mongo.db.categories.delete_one({"_id": c["_id"]})
    flash("Category deleted.", "success")
    return redirect(url_for("categories_list"))

@app.get("/admin/attributes")
@admin_login_required
def attributes_view_admin():
    attrs = mongo.db.attributes.find_one({"_id": "face"}) or {"skin_types": [], "concerns": []}
    return render_template("attributes.html", attrs=attrs)

@app.post("/admin/attributes")
@admin_login_required
def attributes_update_admin():
    skin_types_raw = [s.strip() for s in (request.form.get("skin_types") or "").splitlines() if s.strip()]
    concerns_raw = [s.strip() for s in (request.form.get("concerns") or "").splitlines() if s.strip()]

    def to_pairs(items):
        pairs = []
        for label in items:
            key = slugify(label).replace("-", "_")
            pairs.append({"key": key, "label": label})
        return pairs

    update = {
        "skin_types": to_pairs(skin_types_raw),
        "concerns": to_pairs(concerns_raw),
        "updated_at": datetime.utcnow()
    }
    mongo.db.attributes.update_one({"_id": "face"}, {"$set": update}, upsert=True)
    flash("Attributes updated.", "success")
    return redirect(url_for("attributes_view_admin"))

# ---------- CSV Exports ----------
@app.get("/admin/export/orders.csv")
@admin_login_required
def export_orders_csv():
    status = (request.args.get("status") or "").strip()
    date_from = request.args.get("from")
    date_to = request.args.get("to")
    filt = {}
    if status in ORDER_STATUSES:
        filt["status"] = status
    if date_from or date_to:
        rng = {}
        if date_from:
            try: rng["$gte"] = datetime.fromisoformat(date_from)
            except Exception: pass
        if date_to:
            try: rng["$lte"] = datetime.fromisoformat(date_to)
            except Exception: pass
        if rng: filt["created_at"] = rng

    cur = mongo.db.orders.find(filt).sort("created_at", -1)
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["order_no", "date", "email", "total", "status"])
    for o in cur:
        writer.writerow([
            o.get("order_no", str(o["_id"])),
            (o.get("created_at") or datetime.utcnow()).strftime("%Y-%m-%d %H:%M"),
            o.get("email", ""), o.get("total", 0), o.get("status", ""),
        ])
    return Response(output.getvalue(), mimetype="text/csv",
                    headers={"Content-Disposition": "attachment; filename=orders.csv"})

@app.get("/admin/export/products.csv")
@admin_login_required
def export_products_csv():
    cur = mongo.db.products.find().sort("created_at", -1)
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["name", "sku", "brand", "category", "item_type", "price", "stock", "status"])
    for p in cur:
        writer.writerow([
            p.get("name", ""), p.get("sku", ""), p.get("brand", ""),
            p.get("category", ""), p.get("item_type", ""),
            p.get("price", 0), p.get("stock", 0), p.get("status", "draft")
        ])
    return Response(output.getvalue(), mimetype="text/csv",
                    headers={"Content-Disposition": "attachment; filename=products.csv"})

# ---------- Root shortcuts ----------
@app.get("/admin/auth")
def admin_auth_alias():
    return redirect(url_for("admin_auth"))

@app.get("/")
def index():
    return redirect(url_for("admin_auth"))

# =============================================================================
# Run
# =============================================================================
if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port)