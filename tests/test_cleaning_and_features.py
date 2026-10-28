import unittest, conftest_path  # noqa
from features import clean_text, tokenize, numeric_features, NUMERIC_FEATURES


class TextCleaning(unittest.TestCase):
    def test_whitespace_and_control(self):
        self.assertEqual(clean_text("  a \n\t b\x00c  "), "a bc")

    def test_keeps_case_punct_emoji(self):
        self.assertEqual(clean_text("WOW!!! \U0001F60D"), "WOW!!! \U0001F60D")

    def test_curly_quotes_and_zero_width(self):
        self.assertEqual(clean_text("it\u2019s\u200b ok"), "it's ok")

    def test_none_and_empty(self):
        self.assertEqual(clean_text(None), "")
        self.assertEqual(tokenize(""), [])


class Features(unittest.TestCase):
    def test_vector_shape_and_range(self):
        for t in ["", "x", "A" * 5000, "!!!" * 100, "caf\u00e9 \U0001F60D", "word " * 400]:
            f = numeric_features(t, 5)
            self.assertEqual(len(f), len(NUMERIC_FEATURES))
            self.assertTrue(all(0.0 <= v <= 1.0 for v in f), (t[:20], f))

    def test_url_contact_promo_detected(self):
        f = dict(zip(NUMERIC_FEATURES, numeric_features("Buy now at www.x.com or whatsapp me, free discount", 5)))
        self.assertEqual(f["has_url"], 1.0); self.assertEqual(f["has_contact"], 1.0); self.assertGreater(f["promo"], 0)

    def test_plain_short_positive_review_not_flagged_by_features(self):
        f = dict(zip(NUMERIC_FEATURES, numeric_features("Good product.", 5)))
        self.assertEqual((f["has_url"], f["has_contact"], f["promo"]), (0.0, 0.0, 0.0))

    def test_missing_rating_is_flagged_not_invented(self):
        f = dict(zip(NUMERIC_FEATURES, numeric_features("nice", None)))
        self.assertEqual(f["rating_known"], 0.0); self.assertEqual(f["mismatch"], 0.0)

    def test_rating_text_mismatch(self):
        hi = dict(zip(NUMERIC_FEATURES, numeric_features("Terrible awful broken", 5)))["mismatch"]
        lo = dict(zip(NUMERIC_FEATURES, numeric_features("Terrible awful broken", 1)))["mismatch"]
        self.assertGreater(hi, lo)

    def test_emoji_and_special_chars_do_not_crash(self):
        numeric_features("<script>'; DROP TABLE x;--\U0001F680\u4e2d\u6587", 3)


if __name__ == "__main__":
    unittest.main()
