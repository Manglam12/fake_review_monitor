# Training report (numbers measured by ml/train.py)

- Created: 2026-10-21T17:22:44+00:00
- Dataset: dataset.csv (40486 rows after cleaning)
- Split: grouped by `row (no group column available)`; train 32388 / test 8098; 5-fold grouped CV on train only
- Cleaning: {"rows_in": 40526, "removed_missing_text": 0, "removed_unknown_label": 0, "missing_rating": 0, "removed_conflicting_labels": 0, "removed_duplicate_text": 40, "has_reviewer_id": false, "has_product_id": false, "rows_out": 40486, "fake_count": 20255, "genuine_count": 20231}

## Cross-validation (model selection)

| Model | Accuracy | Precision | Recall | F1 |
|---|---|---|---|---|
| LinearSVM(C=0.5) **(selected)** | 0.947 | 0.951 | 0.944 | 0.947 |
| LogisticRegression(C=8) | 0.946 | 0.949 | 0.944 | 0.946 |
| LinearSVM(C=2) | 0.944 | 0.944 | 0.944 | 0.944 |
| LogisticRegression(C=2) | 0.942 | 0.949 | 0.936 | 0.942 |
| LinearSVM(C=0.1) | 0.940 | 0.949 | 0.930 | 0.940 |
| LogisticRegression(C=0.5) | 0.928 | 0.938 | 0.918 | 0.928 |
| NaiveBayes(alpha=0.1) | 0.896 | 0.897 | 0.895 | 0.896 |
| NaiveBayes(alpha=0.5) | 0.895 | 0.894 | 0.897 | 0.896 |
| NaiveBayes(alpha=1.0) | 0.894 | 0.891 | 0.900 | 0.895 |

## Held-out test (evaluated once)

Rows: 8098, fake share: 0.494, majority-class accuracy: 0.506

Accuracy 0.945, Precision 0.948, Recall 0.940, F1 0.944, ROC-AUC 0.987, Brier 0.041

Confusion matrix (rows = actual, cols = predicted):

| | Pred genuine | Pred fake |
|---|---|---|
| Actual genuine | 3893 | 208 |
| Actual fake | 240 | 3757 |

Share the app would label **Uncertain** (p between 0.35 and 0.65): 0.041

## What the numbers mean

- **Accuracy**: share of all predictions that were right. Misleading when one class is much bigger: always answering 'genuine' would already score the majority-class accuracy above.
- **Precision**: of reviews flagged fake, how many really were. Low precision = honest people wrongly flagged.
- **Recall**: of all real fakes, how many were caught. Low recall = fakes slip through.
- **F1**: one number balancing precision and recall.
- **Confusion matrix**: the four kinds of right/wrong answers behind the numbers.
