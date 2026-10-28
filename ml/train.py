"""Train, compare, evaluate once, and export the model for the Flutter app.

Usage (from the ml folder):  python train.py [--data path.csv] [--demo]
"""
import argparse, datetime as dt, json, math, os, sys
import numpy as np, pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (accuracy_score, brier_score_loss, confusion_matrix,
                             f1_score, precision_score, recall_score, roc_auc_score)
from sklearn.model_selection import GroupKFold, GroupShuffleSplit
from sklearn.naive_bayes import MultinomialNB
from sklearn.pipeline import Pipeline
from sklearn.svm import LinearSVC

from data import load_dataset
from features import NUMERIC_FEATURES, numeric_features

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "artifacts")
SEED = 42
THRESH_LOW, THRESH_HIGH = 0.35, 0.65  # fixed in advance, NOT tuned on the test set
TFIDF_KW = dict(ngram_range=(1, 2), sublinear_tf=True, min_df=2, max_features=8000,
                token_pattern=r"[a-z0-9']+", lowercase=True)


def build_frame(df):
    num = np.array([numeric_features(t, None if pd.isna(r) else r)
                    for t, r in zip(df["text"], df["rating"])])
    X = pd.DataFrame(num, columns=NUMERIC_FEATURES)
    X.insert(0, "text", df["text"].values)
    return X


def make_pipe(clf):
    ct = ColumnTransformer([("tfidf", TfidfVectorizer(**TFIDF_KW), "text"),
                            ("num", "passthrough", NUMERIC_FEATURES)])
    return Pipeline([("features", ct), ("clf", clf)])  # TF-IDF is fitted inside each fold only


def candidates():
    c = {}
    for C in (0.5, 2, 8):
        c[f"LogisticRegression(C={C})"] = lambda C=C: make_pipe(LogisticRegression(C=C, class_weight="balanced", max_iter=2000))
    for C in (0.1, 0.5, 2):
        c[f"LinearSVM(C={C})"] = lambda C=C: make_pipe(LinearSVC(C=C, class_weight="balanced", max_iter=5000))
    for a in (0.1, 0.5, 1.0):
        c[f"NaiveBayes(alpha={a})"] = lambda a=a: make_pipe(MultinomialNB(alpha=a))
    return c


def raw_score(pipe, X):
    """Log-odds style score; equals w.x + b for all three model families."""
    clf = pipe.named_steps["clf"]
    if hasattr(clf, "decision_function"):
        return pipe.decision_function(X)
    lp = pipe.predict_log_proba(X)
    return lp[:, 1] - lp[:, 0]


def linear_params(pipe):
    clf = pipe.named_steps["clf"]
    if isinstance(clf, MultinomialNB):
        return clf.feature_log_prob_[1] - clf.feature_log_prob_[0], float(clf.class_log_prior_[1] - clf.class_log_prior_[0])
    return clf.coef_[0], float(clf.intercept_[0])


def metrics(y, pred):
    return dict(accuracy=accuracy_score(y, pred), precision=precision_score(y, pred, zero_division=0),
                recall=recall_score(y, pred, zero_division=0), f1=f1_score(y, pred, zero_division=0))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(HERE, "data", "dataset.csv"))
    ap.add_argument("--demo", action="store_true", help="use the synthetic DEMO-ONLY dataset")
    a = ap.parse_args()
    demo = a.demo
    path = os.path.join(HERE, "data", "demo_reviews_DEMO_ONLY.csv") if demo else a.data
    try:
        df, rep = load_dataset(path)
    except Exception as e:
        print("DATASET PROBLEM:", e); sys.exit(1)
    print("Cleaning report:", json.dumps(rep, indent=1))
    X, y = build_frame(df), df["y"].values
    if rep["has_reviewer_id"]:
        groups, gname = df["reviewer_id"].fillna("NA").values, "reviewer_id"
    elif rep["has_product_id"]:
        groups, gname = df["product_id"].fillna("NA").values, "product_id"
    else:
        groups, gname = np.arange(len(df)), "row (no group column available)"
    tr, te = next(GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=SEED).split(X, y, groups))
    assert not set(groups[tr]) & set(groups[te]) or gname.startswith("row")
    Xtr, ytr, gtr, Xte, yte = X.iloc[tr], y[tr], groups[tr], X.iloc[te], y[te]
    cv = GroupKFold(n_splits=5)
    results = {}
    for name, mk in candidates().items():
        fm = []
        for a_, b_ in cv.split(Xtr, ytr, gtr):
            p = mk().fit(Xtr.iloc[a_], ytr[a_])
            fm.append(metrics(ytr[b_], (raw_score(p, Xtr.iloc[b_]) > 0).astype(int)))
        results[name] = {k: float(np.mean([m[k] for m in fm])) for k in fm[0]}
        print(f"CV {name:28s} F1={results[name]['f1']:.3f} acc={results[name]['accuracy']:.3f}")
    best = max(results, key=lambda k: results[k]["f1"])
    print("Selected by CV F1:", best)
    # out-of-fold scores on the TRAIN part only -> probability calibration (Platt scaling)
    oof = np.zeros(len(ytr))
    for a_, b_ in cv.split(Xtr, ytr, gtr):
        oof[b_] = raw_score(candidates()[best]().fit(Xtr.iloc[a_], ytr[a_]), Xtr.iloc[b_])
    cal = LogisticRegression(C=1e6).fit(oof.reshape(-1, 1), ytr)
    ca, cb = float(cal.coef_[0][0]), float(cal.intercept_[0])
    final = candidates()[best]().fit(Xtr, ytr)
    # ---- single evaluation on the held-out test set ----
    s = raw_score(final, Xte)
    p = 1 / (1 + np.exp(-(ca * s + cb)))
    binary = metrics(yte, (p >= 0.5).astype(int))
    cm = confusion_matrix(yte, (p >= 0.5).astype(int)).tolist()
    decided = (p <= THRESH_LOW) | (p >= THRESH_HIGH)
    dec = metrics(yte[decided], (p[decided] >= 0.5).astype(int)) if decided.any() else {}
    test = dict(n=int(len(yte)), fake_share=float(yte.mean()), binary_at_0_5=binary, confusion_matrix=cm,
                roc_auc=float(roc_auc_score(yte, p)), brier=float(brier_score_loss(yte, p)),
                majority_class_accuracy=float(max(yte.mean(), 1 - yte.mean())),
                uncertain_share=float(1 - decided.mean()), metrics_on_decided_only=dec)
    # ---- export ----
    tf = final.named_steps["features"].named_transformers_["tfidf"]
    w, b = linear_params(final)
    V = len(tf.vocabulary_)
    model = {"format_version": 1, "model_name": best, "created_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
             "dataset": {"name": "SYNTHETIC DEMO-ONLY dataset" if demo else os.path.basename(path), "demo_only": demo,
                         "rows_used": rep["rows_out"], "license": "synthetic, generated by ml/generate_demo_data.py" if demo else "USER MUST VERIFY"},
             "tfidf": {"vocabulary": {k: int(v) for k, v in tf.vocabulary_.items()}, "idf": [float(x) for x in tf.idf_],
                       "sublinear_tf": True, "max_ngram": 2},
             "numeric_feature_names": NUMERIC_FEATURES,
             "weights_tfidf": [float(x) for x in w[:V]], "weights_numeric": [float(x) for x in w[V:]], "intercept": b,
             "calibration": {"a": ca, "b": cb},
             "thresholds": {"genuine_at_or_below": THRESH_LOW, "fake_at_or_above": THRESH_HIGH}}
    os.makedirs(ART, exist_ok=True)
    json.dump(model, open(os.path.join(ART, "model.json"), "w"))
    report = {"created_utc": model["created_utc"], "dataset": model["dataset"], "cleaning": rep,
              "split": {"group_column": gname, "train_rows": int(len(tr)), "test_rows": int(len(te)), "cv_folds": 5, "seed": SEED},
              "cv_results": results, "selected_model": best, "calibration": model["calibration"],
              "thresholds": model["thresholds"], "test": test}
    json.dump(report, open(os.path.join(ART, "training_report.json"), "w"), indent=1)
    write_md(report, demo)
    print("Held-out test:", json.dumps(test, indent=1))
    print("Model JSON size KB:", os.path.getsize(os.path.join(ART, "model.json")) // 1024)


def write_md(r, demo):
    t = r["test"]; b = t["binary_at_0_5"]; cm = t["confusion_matrix"]
    L = ["# Training report (numbers measured by ml/train.py)\n"]
    if demo:
        L.append("> **DEMO-ONLY.** Trained on a synthetic dataset written by a script. These scores do NOT describe real-world performance.\n")
    L += [f"- Created: {r['created_utc']}", f"- Dataset: {r['dataset']['name']} ({r['cleaning']['rows_out']} rows after cleaning)",
          f"- Split: grouped by `{r['split']['group_column']}`; train {r['split']['train_rows']} / test {r['split']['test_rows']}; 5-fold grouped CV on train only",
          f"- Cleaning: {json.dumps(r['cleaning'])}\n", "## Cross-validation (model selection)\n",
          "| Model | Accuracy | Precision | Recall | F1 |", "|---|---|---|---|---|"]
    for k, v in sorted(r["cv_results"].items(), key=lambda kv: -kv[1]["f1"]):
        L.append(f"| {k}{' **(selected)**' if k == r['selected_model'] else ''} | {v['accuracy']:.3f} | {v['precision']:.3f} | {v['recall']:.3f} | {v['f1']:.3f} |")
    L += ["\n## Held-out test (evaluated once)\n", f"Rows: {t['n']}, fake share: {t['fake_share']:.3f}, majority-class accuracy: {t['majority_class_accuracy']:.3f}\n",
          f"Accuracy {b['accuracy']:.3f}, Precision {b['precision']:.3f}, Recall {b['recall']:.3f}, F1 {b['f1']:.3f}, ROC-AUC {t['roc_auc']:.3f}, Brier {t['brier']:.3f}\n",
          "Confusion matrix (rows = actual, cols = predicted):\n", "| | Pred genuine | Pred fake |", "|---|---|---|",
          f"| Actual genuine | {cm[0][0]} | {cm[0][1]} |", f"| Actual fake | {cm[1][0]} | {cm[1][1]} |\n",
          f"Share the app would label **Uncertain** (p between {r['thresholds']['genuine_at_or_below']} and {r['thresholds']['fake_at_or_above']}): {t['uncertain_share']:.3f}\n",
          "## What the numbers mean\n",
          "- **Accuracy**: share of all predictions that were right. Misleading when one class is much bigger: always answering 'genuine' would already score the majority-class accuracy above.",
          "- **Precision**: of reviews flagged fake, how many really were. Low precision = honest people wrongly flagged.",
          "- **Recall**: of all real fakes, how many were caught. Low recall = fakes slip through.",
          "- **F1**: one number balancing precision and recall.",
          "- **Confusion matrix**: the four kinds of right/wrong answers behind the numbers."]
    open(os.path.join(ART, "training_report.md"), "w").write("\n".join(L) + "\n")


if __name__ == "__main__":
    main()
