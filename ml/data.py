"""Dataset loading, validation and cleaning. Reports every removal count."""
import pandas as pd
from features import clean_text

ALIASES = {
    "review_text": ["review_text", "text", "review", "content", "text_", "reviewtext"],
    "label": ["label", "class", "is_fake"],
    "rating": ["rating", "stars", "score", "overall"],
    "reviewer_id": ["reviewer_id", "user_id", "reviewerid", "author", "customer_id"],
    "product_id": ["product_id", "asin", "item_id", "productid"],
    "timestamp": ["timestamp", "date", "time", "review_date", "unixreviewtime"],
}
FAKE = {"fake", "cg", "computer generated", "spam", "deceptive", "1", "true", "yes", "f"}
GENUINE = {"genuine", "real", "or", "original", "truthful", "0", "false", "no", "g"}
MIN_ROWS_PER_CLASS = 20


class DatasetError(ValueError):
    """Raised with a beginner-friendly message when a dataset cannot be used."""


def map_label(v):
    s = str(v).strip().lower()
    if s in FAKE:
        return 1
    if s in GENUINE:
        return 0
    return None


def standardize_columns(df):
    lower = {c.lower().strip(): c for c in df.columns}
    out = {}
    for std, names in ALIASES.items():
        for n in names:
            if n in lower:
                out[std] = df[lower[n]]
                break
    missing = [c for c in ("review_text", "label") if c not in out]
    if missing:
        raise DatasetError(f"Missing required column(s): {missing}. Found columns: {list(df.columns)}. "
                           f"Rename them or extend ALIASES in ml/data.py.")
    return pd.DataFrame(out)


def clean_dataset(df):
    """df has standard columns. Returns (clean_df, report dict)."""
    rep = {"rows_in": int(len(df))}
    df = df.copy()
    df["text"] = df["review_text"].map(clean_text)
    n = len(df)
    df = df[df["text"].str.len() > 0]
    rep["removed_missing_text"] = int(n - len(df))
    df["y"] = df["label"].map(map_label)
    n = len(df)
    df = df[df["y"].notna()]
    rep["removed_unknown_label"] = int(n - len(df))
    df["y"] = df["y"].astype(int)
    if "rating" in df:
        r = pd.to_numeric(df["rating"], errors="coerce")
        df["rating"] = r.where((r >= 1) & (r <= 5))
    else:
        df["rating"] = float("nan")
    rep["missing_rating"] = int(df["rating"].isna().sum())
    key = df["text"].str.lower()
    conflict = df.groupby(key)["y"].transform("nunique") > 1
    rep["removed_conflicting_labels"] = int(conflict.sum())
    df = df[~conflict]
    key = df["text"].str.lower()
    dup = key.duplicated(keep="first")
    rep["removed_duplicate_text"] = int(dup.sum())
    df = df[~dup].reset_index(drop=True)
    for c in ("reviewer_id", "product_id", "timestamp"):
        if c not in df:
            df[c] = None
    rep["has_reviewer_id"] = bool(df["reviewer_id"].notna().any())
    rep["has_product_id"] = bool(df["product_id"].notna().any())
    rep["rows_out"] = int(len(df))
    rep["fake_count"] = int(df["y"].sum())
    rep["genuine_count"] = int((df["y"] == 0).sum())
    if min(rep["fake_count"], rep["genuine_count"]) < MIN_ROWS_PER_CLASS:
        raise DatasetError(f"Need at least {MIN_ROWS_PER_CLASS} rows of EACH class after cleaning; got {rep}.")
    return df, rep


def load_dataset(path):
    try:
        raw = pd.read_csv(path, dtype=str, keep_default_na=False, encoding="utf-8")
    except FileNotFoundError:
        raise DatasetError(f"Dataset file not found: {path}")
    except (pd.errors.EmptyDataError, pd.errors.ParserError, UnicodeDecodeError) as e:
        raise DatasetError(f"Could not read CSV ({type(e).__name__}): {e}")
    if raw.empty:
        raise DatasetError("The CSV has no rows.")
    return clean_dataset(standardize_columns(raw))
