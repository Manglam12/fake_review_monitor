"""Writes test vectors that BOTH the Python tests and the Dart tests check."""
import json, os, shutil
from reference_infer import ExportedModel
from features import numeric_features, tokenize, clean_text
HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(HERE, "..", "app")
CASES = [
    ("Bought this blender two weeks ago. The motor is louder than I expected, but it crushes ice fine.", 4),
    ("BEST PRODUCT EVER!!! Buy now, 100% guaranteed!!! Visit www.deals-9.com for free coupon", 5),
    ("Great product, highly recommend to everyone.", 5), ("Good.", None), ("", None), ("   \n\t  ", 3),
    ("Love it \U0001F60D\U0001F60D\U0001F60D very nice \u2764\ufe0f", 5), ("Terrible, broke in a day. Waste of money.", 5),
    ("Call me on +91 98765 43210 or email seller@mail.com", 5), ("it\u2019s \u201cokay\u201d but cheap", 2),
    ("word " * 400, 3), ("Caf\u00e9 cr\u00e8me \u00fc\u00f1\u00ee c\u00f6d\u00e9 \u4e2d\u6587 test", 4),
    ("Works as described. Would buy again. Works as described. Would buy again.", 3),
    ("<script>alert('x')</script> ; DROP TABLE reviews;--", 1), ("A" * 5000, 5),
]
if __name__ == "__main__":
    m = ExportedModel(os.path.join(HERE, "artifacts", "model.json"))
    out = []
    for t, r in CASES:
        p = m.prob_fake(t, r)
        out.append({"text": t, "rating": r, "tokens": tokenize(t), "clean": clean_text(t),
                    "features": numeric_features(t, r), "raw_score": m.raw_score(t, r),
                    "prob_fake": p, "label": m.label(p)})
    for d in ("app/assets/model", "app/test/assets"):
        os.makedirs(os.path.join(HERE, "..", d), exist_ok=True)
    json.dump(out, open(os.path.join(APP, "test", "assets", "golden_vectors.json"), "w"), indent=1)
    shutil.copy(os.path.join(HERE, "artifacts", "model.json"), os.path.join(APP, "assets", "model", "model.json"))
    print("wrote", len(out), "golden vectors and copied model.json into app/assets/model/")
