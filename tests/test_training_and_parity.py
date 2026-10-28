import json, os, unittest, conftest_path  # noqa
import numpy as np, pandas as pd
from sklearn.model_selection import GroupKFold, GroupShuffleSplit
import train
from data import load_dataset
from reference_infer import ExportedModel
from features import numeric_features

HERE = os.path.dirname(os.path.abspath(__file__))
ML = os.path.join(HERE, "..", "ml")
MODEL = os.path.join(ML, "artifacts", "model.json")
DEMO = os.path.join(ML, "data", "demo_reviews_DEMO_ONLY.csv")


class NoLeakage(unittest.TestCase):
    def test_reviewer_groups_never_cross_train_test_or_cv_folds(self):
        df, _ = load_dataset(DEMO)
        g, y = df["reviewer_id"].values, df["y"].values
        tr, te = next(GroupShuffleSplit(n_splits=1, test_size=.2, random_state=train.SEED).split(df, y, g))
        self.assertFalse(set(g[tr]) & set(g[te]))
        self.assertFalse(set(df["text"].str.lower().iloc[tr]) & set(df["text"].str.lower().iloc[te]), "duplicate text across split")
        for a, b in GroupKFold(5).split(df.iloc[tr], y[tr], g[tr]):
            self.assertFalse(set(g[tr][a]) & set(g[tr][b]))

    def test_tfidf_is_inside_pipeline(self):
        names = [n for n, _ in train.make_pipe(train.LogisticRegression()).steps]
        self.assertEqual(names, ["features", "clf"])


class ExportParity(unittest.TestCase):
    """Proves model.json + independent code reproduces scikit-learn exactly."""
    @classmethod
    def setUpClass(cls):
        cls.rep = json.load(open(os.path.join(ML, "artifacts", "training_report.json")))
        # use the SAME dataset the shipped model was trained on (demo, or your own dataset.csv)
        DATA = DEMO if cls.rep["dataset"]["demo_only"] else os.path.join(ML, "data", "dataset.csv")
        df, _ = load_dataset(DATA)
        cls.df = df.sample(150, random_state=1).reset_index(drop=True)
        cls.m = ExportedModel(MODEL)
        best = cls.rep["selected_model"]
        full, frep = load_dataset(DATA)
        g = full["reviewer_id"].fillna("NA").values if frep["has_reviewer_id"] else (full["product_id"].fillna("NA").values if frep["has_product_id"] else np.arange(len(full)))
        tr, _ = next(GroupShuffleSplit(n_splits=1, test_size=.2, random_state=train.SEED).split(full, full["y"], g))
        X = train.build_frame(full)
        cls.pipe = train.candidates()[best]().fit(X.iloc[tr], full["y"].values[tr])  # same recipe as train.py

    def test_scores_match_sklearn(self):
        X = train.build_frame(self.df)
        sk = train.raw_score(self.pipe, X)
        mine = np.array([self.m.raw_score(t, None if pd.isna(r) else r) for t, r in zip(self.df["text"], self.df["rating"])])
        self.assertLess(np.max(np.abs(sk - mine)), 1e-6)

    def test_probability_and_labels_in_range(self):
        for t in ["", "ok", "BUY NOW!!! www.x.com", "x" * 10000, "\U0001F60D" * 50]:
            p = self.m.prob_fake(t, 5)
            self.assertTrue(0.0 <= p <= 1.0)
            self.assertIn(self.m.label(p), ["Likely Genuine", "Uncertain", "Suspicious / Likely Fake"])

    def test_golden_vectors_file_matches_python(self):
        g = json.load(open(os.path.join(ML, "..", "app", "test", "assets", "golden_vectors.json"), encoding="utf-8"))
        self.assertGreaterEqual(len(g), 10)
        for c in g:
            self.assertAlmostEqual(self.m.prob_fake(c["text"], c["rating"]), c["prob_fake"], places=9)
            self.assertEqual(numeric_features(c["text"], c["rating"]), c["features"])

    def test_app_asset_is_same_model(self):
        a = open(MODEL, "rb").read(); b = open(os.path.join(ML, "..", "app", "assets", "model", "model.json"), "rb").read()
        self.assertEqual(a, b)


class DemoLabelling(unittest.TestCase):
    def test_report_marks_demo(self):
        rep = json.load(open(os.path.join(ML, "artifacts", "training_report.json")))
        md = open(os.path.join(ML, "artifacts", "training_report.md")).read()
        self.assertEqual(rep["dataset"]["demo_only"], "DEMO-ONLY" in md)


if __name__ == "__main__":
    unittest.main()
