"""Text cleaning + hand-made features.

IMPORTANT: app/lib/core/text_features.dart is a line-by-line port of this file.
Both use only ASCII-based rules so Python and Dart give identical numbers.
Every feature is in the range [0, 1] and is NOT fitted on data (no leakage).
"""
import math
import re

TOKEN_RE = re.compile(r"[a-z0-9']+")
URL_RE = re.compile(r"(?:https?://|www\.)\S+|[a-z0-9-]+\.(?:com|net|org|in|io|shop|store)\b", re.I)
EMAIL_RE = re.compile(r"[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}", re.I)
PHONE_RE = re.compile(r"\+?\d[\d\s().-]{8,}\d")
CONTACT_WORDS = ["whatsapp", "telegram", "contact me", "call me", "dm me"]
PROMO_PHRASES = ["buy now", "order now", "discount", "free", "click", "limited offer",
                 "best price", "cheap", "guaranteed", "must buy", "100%", "coupon",
                 "promo", "use code", "visit"]
POSITIVE = set("good great excellent love loved perfect amazing awesome best nice happy "
               "fantastic wonderful recommend works smooth comfortable sturdy fast".split())
NEGATIVE = set("bad poor terrible awful hate hated worst broken broke useless waste "
               "disappointed disappointing slow cheap defective faulty refund return".split())

NUMERIC_FEATURES = ["length", "words", "ttr", "top_word_share", "exclaim", "caps",
                    "has_url", "has_contact", "promo", "rating_norm", "rating_known",
                    "sentiment01", "mismatch"]

_CTRL = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f\u200b-\u200d\ufeff]")
_SPACE = re.compile(r"[ \t\r\n\f\v\u00a0]+")


def clean_text(text):
    """Light cleaning: keep case, punctuation, emojis (they are useful signals)."""
    if text is None:
        return ""
    t = str(text)
    t = _CTRL.sub("", t)
    t = t.replace("\u2018", "'").replace("\u2019", "'").replace("\u201c", '"').replace("\u201d", '"')
    return _SPACE.sub(" ", t).strip()


def tokenize(text):
    return TOKEN_RE.findall(clean_text(text).lower())


def _utf16_len(s):
    return len(s.encode("utf-16-le", "surrogatepass")) // 2  # same as Dart String.length


def numeric_features(text, rating=None):
    """Return the NUMERIC_FEATURES values (list of floats) for one review."""
    t = clean_text(text)
    low = t.lower()
    toks = TOKEN_RE.findall(low)
    n = len(toks)
    uniq = len(set(toks))
    ttr = uniq / n if n else 0.0
    long_toks = [w for w in toks if len(w) >= 4]
    top = 0.0
    if long_toks and n:
        counts = {}
        for w in long_toks:
            counts[w] = counts.get(w, 0) + 1
        top = max(counts.values()) / n
    upper = sum(1 for c in t if "A" <= c <= "Z")
    letters = sum(1 for c in t if ("A" <= c <= "Z") or ("a" <= c <= "z"))
    caps = upper / letters if letters else 0.0
    has_url = 1.0 if URL_RE.search(t) else 0.0
    has_contact = 1.0 if (EMAIL_RE.search(t) or PHONE_RE.search(t)
                          or any(w in low for w in CONTACT_WORDS)) else 0.0
    promo = sum(low.count(p) for p in PROMO_PHRASES)
    known = rating is not None and not (isinstance(rating, float) and math.isnan(rating))
    rating_norm = (float(rating) - 1.0) / 4.0 if known else 0.0
    pos = sum(1 for w in toks if w in POSITIVE)
    neg = sum(1 for w in toks if w in NEGATIVE)
    sent = (pos - neg) / (pos + neg) if (pos + neg) else 0.0
    mismatch = abs(sent - (float(rating) - 3.0) / 2.0) / 2.0 if (known and pos + neg) else 0.0
    return [min(_utf16_len(t) / 1000.0, 1.0), min(n / 200.0, 1.0), ttr, top,
            min(t.count("!") / 10.0, 1.0), caps, has_url, has_contact,
            min(promo / 3.0, 1.0), rating_norm, 1.0 if known else 0.0,
            (sent + 1.0) / 2.0, mismatch]
