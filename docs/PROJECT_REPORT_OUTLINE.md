# Project report outline (beginner friendly)

1. **Abstract** (150-200 words): problem, approach (TF-IDF + linear ML + rules, offline Android app), dataset used, headline results (from YOUR real-dataset training report), limitations.
2. **Introduction & problem statement**: why fake reviews harm customers and honest sellers; objectives; scope (on-device, no server).
3. **Literature survey topics** (search and cite real papers yourself): opinion spam detection (Jindal & Liu; Ott et al.), linguistic features for deception, reviewer-behaviour features (Mukherjee et al.), graph/burst detection (Akoglu et al.), supervised text classification (TF-IDF + SVM / Naive Bayes / Logistic Regression), model calibration, on-device ML.
4. **Methodology**: dataset and licence; cleaning; features (text, rating, behaviour-by-rules); models compared; grouped cross-validation; held-out test; calibration; 3-class decision with an Uncertain band.
5. **System architecture**: ML pipeline (Python) -> `model.json` -> Flutter app (analyzer, rules engine, SQLite, CSV/PDF). Draw: data flow diagram + block diagram.
6. **Modules**: data, NLP/features, ML, rule-based detection, admin (alerts/reports/history), UI, privacy.
7. **Implementation**: tools, key code listings (features.py, train.py, model.dart), screenshots.
8. **Testing**: Python tests, Dart tests, manual QA checklist, results (copy real outputs).
9. **Results**: tables from `training_report.md`; confusion matrix; explain precision/recall/F1; why accuracy can mislead; error analysis (look at wrong predictions).
10. **Limitations**: dataset domain shift, label quality, English/ASCII bias, adversarial authors, tiny sentiment lexicon, only on-device history.
11. **Future scope**: transformer models (distilled BERT via TFLite), multi-language, graph features, server sync, active learning from admin feedback.
12. **Conclusion, references, appendix** (setup commands, dataset licence note).

# Likely viva questions (short answers)
- **Why TF-IDF?** It weights words that are distinctive for a review rather than common everywhere; it is simple, fast and works offline.
- **Why linear models?** Fast, explainable, small to export (a weight per word), good baseline for text.
- **Why not just accuracy?** If 90% of reviews are genuine, "always genuine" scores 90%. Precision, recall and F1 show how fakes are handled.
- **Precision vs recall here?** Precision: of flagged reviews how many are truly fake (protects honest people). Recall: how many fakes we catch.
- **What is data leakage and how did you avoid it?** Test information leaking into training. I split by reviewer, removed duplicate texts, and fitted TF-IDF inside each CV fold only.
- **Why an "Uncertain" class?** Forcing a yes/no on borderline cases causes wrong accusations; abstaining is more honest.
- **What is calibration?** Mapping raw scores to probabilities that match real frequencies (Platt scaling).
- **Why are rule-based warnings separate?** They are transparent hints, not learned truth; mixing them would hide why a review was flagged.
- **How does the app run ML offline?** The model is exported as JSON weights; Dart recomputes TF-IDF and a dot product.
- **How do you know the app matches Python?** Golden test vectors checked in both languages.
- **Limitations?** Domain shift, label noise, English-only, adversarial authors, sentiment word list is tiny.
- **Privacy?** Everything on-device, no internet permission.
- **How would you improve it?** Better dataset, transformer model, multilingual support, admin feedback loop.
