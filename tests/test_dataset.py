import os, tempfile, unittest, conftest_path  # noqa
import pandas as pd
from data import load_dataset, DatasetError, clean_dataset, standardize_columns


def write(rows, cols=("review_text", "label")):
    f = tempfile.NamedTemporaryFile("w", suffix=".csv", delete=False, encoding="utf-8")
    pd.DataFrame(rows, columns=list(cols)).to_csv(f.name, index=False); return f.name


def many(n=30):
    return [(f"genuine text number {i}", "genuine") for i in range(n)] + [(f"fake spam text {i}!!!", "fake") for i in range(n)]


class Validation(unittest.TestCase):
    def test_missing_file(self):
        with self.assertRaises(DatasetError): load_dataset("/no/such/file.csv")

    def test_missing_required_column(self):
        with self.assertRaises(DatasetError) as c: load_dataset(write([("a", 1)], ("foo", "bar")))
        self.assertIn("Missing required", str(c.exception))

    def test_empty_csv(self):
        f = tempfile.NamedTemporaryFile("w", suffix=".csv", delete=False); f.write("review_text,label\n"); f.close()
        with self.assertRaises(DatasetError): load_dataset(f.name)

    def test_too_few_of_one_class(self):
        with self.assertRaises(DatasetError): load_dataset(write([(f"t{i}", "genuine") for i in range(40)]))

    def test_counts_duplicates_conflicts_missing_and_bad_labels(self):
        rows = many() + [("genuine text number 1", "genuine"), ("same text", "fake"), ("same text", "genuine"),
                         ("", "fake"), ("weird label row", "maybe")]
        _, rep = load_dataset(write(rows))
        self.assertEqual(rep["removed_duplicate_text"], 1)
        self.assertEqual(rep["removed_conflicting_labels"], 2)
        self.assertEqual(rep["removed_missing_text"], 1)
        self.assertEqual(rep["removed_unknown_label"], 1)
        self.assertEqual(rep["rows_out"], 60)

    def test_aliases_and_missing_metadata(self):
        df, rep = load_dataset(write([(t, l) for t, l in many()], ("text", "class")))
        self.assertFalse(rep["has_reviewer_id"]); self.assertFalse(rep["has_product_id"])

    def test_invalid_rating_becomes_missing(self):
        rows = [(t, l, 9) for t, l in many()]
        df, rep = load_dataset(write(rows, ("review_text", "label", "rating")))
        self.assertEqual(rep["missing_rating"], 60)


if __name__ == "__main__":
    unittest.main()
