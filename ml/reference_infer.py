"""Pure-Python inference that uses ONLY model.json (no scikit-learn).
app/lib/core/model.dart is a port of this file. If this matches scikit-learn
(see tests/test_parity.py) then the exported format is correct."""
import json, math
from features import tokenize, numeric_features


class ExportedModel:
    def __init__(self, path):
        m = json.load(open(path, encoding="utf-8"))
        self.m = m
        self.vocab = m["tfidf"]["vocabulary"]
        self.idf = m["tfidf"]["idf"]
        self.wt = m["weights_tfidf"]
        self.wn = m["weights_numeric"]
        self.b = m["intercept"]
        self.ca, self.cb = m["calibration"]["a"], m["calibration"]["b"]
        self.th = m["thresholds"]

    def raw_score(self, text, rating=None):
        toks = tokenize(text)
        grams = toks + [toks[i] + " " + toks[i + 1] for i in range(len(toks) - 1)]
        tf = {}
        for g in grams:
            if g in self.vocab:
                tf[self.vocab[g]] = tf.get(self.vocab[g], 0) + 1
        vals = {i: (1.0 + math.log(c)) * self.idf[i] for i, c in tf.items()}
        norm = math.sqrt(sum(v * v for v in vals.values()))
        s = self.b
        if norm > 0:
            s += sum(self.wt[i] * v / norm for i, v in vals.items())
        s += sum(w * x for w, x in zip(self.wn, numeric_features(text, rating)))
        return s

    def prob_fake(self, text, rating=None):
        z = self.ca * self.raw_score(text, rating) + self.cb
        return 1.0 / (1.0 + math.exp(-z)) if z > -700 else 0.0

    def label(self, p):
        if p >= self.th["fake_at_or_above"]:
            return "Suspicious / Likely Fake"
        if p <= self.th["genuine_at_or_below"]:
            return "Likely Genuine"
        return "Uncertain"
