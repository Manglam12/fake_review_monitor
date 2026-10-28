# Fake Product Review Monitoring System

Android app (Flutter/Dart) that runs a trained ML model **on the phone, offline**, to flag suspicious product reviews.
Model training: Python (pandas, NumPy, scikit-learn). Storage: SQLite. No server, login, API key or internet permission.

> **Honesty box.** The model shipped in this folder was trained on a **synthetic DEMO-ONLY dataset** because the build
> environment had no internet. Its scores are not real-world performance. The app shows a "DEMO MODEL" banner until you
> retrain on a real dataset (Section 3). The Flutter app was **written but never compiled or run** (no Flutter SDK in the
> build environment): see the status table.

## 1. How it works (plain language)
```
review text + optional rating
   |-- clean text -> TF-IDF (words + word pairs) + 13 hand-made numbers (length, caps, links, promo words...)
   |-- linear model (picked by cross-validation from LogReg / Linear SVM / Naive Bayes)
   |-- score -> calibrated probability -> Likely Genuine / Uncertain / Suspicious
rule-based checks (SEPARATE from ML): duplicates, near-duplicates, links, repetition, bursts, rating patterns
```
Design decisions: (1) the model is exported as a JSON file of weights, so the app only does simple arithmetic and needs
no ML library; (2) the ML model uses only text + rating, so single-review analysis always works; reviewer/product/time
behaviour is handled by rule-based warnings that only run when that data exists ("Insufficient metadata" otherwise);
(3) a review with fewer than 3 words is always "Uncertain" (too little evidence).

## 2. Folder map
| Folder | What |
|---|---|
| `ml/` | `features.py` (cleaning + features), `data.py` (load/validate/clean), `train.py`, `reference_infer.py`, `make_golden.py`, `generate_demo_data.py` |
| `ml/artifacts/` | `model.json` (used by app), `training_report.md/.json` (measured numbers) |
| `ml/data/` | demo CSV + `DATA_README.md` (dataset sources, labels, license advice) |
| `app/` | Flutter app (`lib/core` logic, `lib/data` SQLite/CSV/PDF, `lib/ui` screens, `test/`) |
| `tests/` | Python tests |
| `docs/` | project report outline + viva questions |

## 3. Setup and run (Windows PowerShell)
Install once: Python 3.10+ (tick "Add to PATH"), and Flutter + Android Studio: https://docs.flutter.dev/get-started/install/windows/mobile (run `flutter doctor` until it has no red items).

**A. ML part** (run in PowerShell, inside the project folder `fake_review_monitor`):
```powershell
cd C:\path\to\fake_review_monitor
python -m venv .venv
.\.venv\Scripts\Activate.ps1          # if blocked: Set-ExecutionPolicy -Scope Process Bypass
pip install -r ml\requirements.txt
cd ml
python generate_demo_data.py          # creates ml\data\demo_reviews_DEMO_ONLY.csv
python train.py --demo                # prints results; writes ml\artifacts\model.json + training_report.md
python make_golden.py                 # copies model.json into app\assets\model\ and writes test vectors
cd ..
python -m unittest discover -s tests -v
```
**Use a real dataset instead:** save it as `ml\data\dataset.csv` (see `ml\data\DATA_README.md`), then in `ml` run
`python train.py` and `python make_golden.py`. Check the license yourself.

**B. Flutter part** (inside `app`):
```powershell
cd app
flutter create --platforms=android --project-name fake_review_monitor .   # adds the android\ folder; keeps lib\ and pubspec.yaml
del test\widget_test.dart             # the auto-made sample test does not fit this app
flutter pub get
flutter test                          # runs the Dart tests
flutter run                           # phone with USB debugging, or an emulator
flutter build apk --release           # APK appears at app\build\app\outputs\flutter-apk\app-release.apk
```
If `flutter create` changed `pubspec.yaml`, re-check that the `assets:` and dependency lines still match this repo's version.
Copy the APK to your phone and open it (allow "install unknown apps").
Exports (CSV/PDF) open Android's share sheet, so you can save to Drive/Files or send them.

## 4. Troubleshooting
| Problem | Fix |
|---|---|
| `python` not found | reinstall Python with "Add to PATH"; or use `py` |
| Activate.ps1 blocked | `Set-ExecutionPolicy -Scope Process Bypass` then retry |
| `DATASET PROBLEM: Missing required column` | rename your columns or edit `ALIASES` in `ml\data.py` |
| Parity test fails after retraining | run `python make_golden.py` again so app assets match |
| `flutter doctor` red items | follow its suggestions (accept Android licenses: `flutter doctor --android-licenses`) |
| Gradle/build error | run `flutter clean` then `flutter pub get`; make sure the JDK from Android Studio is used |
| Compile error in the Dart code | I could not compile it here; send me the exact message and I will fix it |
| App shows startup error | `assets\model\model.json` missing: run `make_golden.py` |

## 5. Manual QA checklist (do on a phone)
- [ ] Splash -> Home loads, demo banner visible (demo model).
- [ ] Analyze: empty text rejected; 1-2 word review gives Uncertain + note; normal review gives result; emoji text works.
- [ ] Result shows ML card and warnings card separately; no wording claims proof.
- [ ] Review with link/phone number shows warnings; plain short 5-star review shows none.
- [ ] History: appears, search works, filter chips, swipe delete, delete-all asks for confirmation, survives app restart.
- [ ] Batch: import `ml\data\demo_reviews_DEMO_ONLY.csv`; progress shows; summary; export CSV opens share sheet.
- [ ] Batch with a wrong CSV (no review column) shows a clear message; empty file handled.
- [ ] Reports: numbers match History; CSV and PDF export work.
- [ ] Light/dark switch; rotate; keyboard open on small screen does not hide fields; airplane mode works.
- [ ] Settings shows model/dataset info, limitations, disclaimer.

## 6. Status table
| Item | Status |
|---|---|
| Python data loading, validation, cleaning counts | **Done and verified** (7 tests) |
| Feature engineering (Python) | **Done and verified** (6+4 tests) |
| Training: 9 candidates, grouped CV, single held-out test, calibration | **Done and verified** (ran; see `training_report.md`) |
| No train/test leakage | **Verified** (reviewer groups, duplicate text, CV folds) |
| Export JSON == scikit-learn output (<1e-6) | **Verified** in Python (independent re-implementation) |
| Dart feature/model port == Python output | **Written, NOT verified** (`app/test/golden_test.dart` will check it) |
| Rule-based warnings, batch rules | **Written, NOT verified** (`app/test/rules_test.dart`) |
| SQLite, CSV import/export, PDF | **Written, NOT verified** (`app/test/csv_db_test.dart`) |
| All 9 UI screens | **Written, NOT verified** (never compiled or seen on a screen) |
| Release APK | **Not built** (no Flutter/Android SDK here) |
| Real dataset, real-world accuracy | **Not done** (no internet). Demo numbers are inflated by design. |

Limitations: ASCII-word model (little signal from other languages/emoji); sentiment lexicon is tiny; behaviour checks only see data in the file/phone; a model trained on one site may fail on another.

**Responsible use:** predictions can be wrong and must not be the sole basis for accusing a person or business.
