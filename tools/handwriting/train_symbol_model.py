#!/usr/bin/env python3
"""Train a small, offline single-symbol handwriting classifier from HASYv2.

The model is deliberately symbol-level. Mathevo's existing ML Kit path remains
responsible for full handwritten expressions and their layout.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import numpy as np
from PIL import Image
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report


DATASET_HANDLE = "guru001/hasyv2"
MODEL_VERSION = 1
INPUT_SIDE = 28

# HASYv2 Latex label -> character emitted into Mathevo's expression editor.
SYMBOLS = {
    **{str(n): str(n) for n in range(10)},
    "+": "+",
    "-": "-",
    "/": "/",
    r"\div": "/",
    r"\times": "*",
    r"\cdot": "*",
    r"\pi": "pi",
}


def ensure_dataset(data_dir: Path) -> Path:
    labels_file = data_dir / "hasy-data-labels.csv"
    if labels_file.exists():
        return data_dir
    import kagglehub

    data_dir.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading public Kaggle dataset {DATASET_HANDLE}...")
    resolved = Path(
        kagglehub.dataset_download(DATASET_HANDLE, output_dir=str(data_dir))
    )
    if not (resolved / "hasy-data-labels.csv").exists():
        raise FileNotFoundError(
            f"HASYv2 labels were not found in the downloaded folder: {resolved}"
        )
    return resolved


def read_rows(root: Path, labels_path: Path, fold: int) -> tuple[list[dict], list[dict]]:
    with labels_path.open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    by_path = {row["path"]: row for row in rows}
    fold_dir = root / "classification-task" / f"fold-{fold}"
    if not fold_dir.exists():
        raise FileNotFoundError(f"HASYv2 fold not found: {fold_dir}")

    def read_split(name: str) -> list[dict]:
        with (fold_dir / name).open(newline="", encoding="utf-8") as stream:
            split_rows = csv.DictReader(stream)
            selected = []
            for split_row in split_rows:
                path = (fold_dir / split_row["path"]).resolve()
                relative = path.relative_to(root.resolve()).as_posix()
                row = by_path.get(relative)
                if row is None:
                    continue
                if row["latex"] not in SYMBOLS:
                    continue
                selected.append({**row, "absolute_path": path})
            return selected

    return read_split("train.csv"), read_split("test.csv")


def preprocess(image_path: Path) -> np.ndarray:
    # Match the app pipeline: crop the ink, add proportionate white margin,
    # center the glyph, and use nearest-neighbor sampling to 28x28.
    with Image.open(image_path) as image:
        image = image.convert("L")
        pixels = np.asarray(image, dtype=np.uint8)
        ys, xs = np.where(pixels < 238)
        if len(xs) == 0:
            return np.zeros(INPUT_SIDE * INPUT_SIDE, dtype=np.float32)
        x0, x1 = int(xs.min()), int(xs.max()) + 1
        y0, y1 = int(ys.min()), int(ys.max()) + 1
        glyph = image.crop((x0, y0, x1, y1))
        glyph_side = max(glyph.width, glyph.height)
        margin = max(3.0, glyph_side * 0.16)
        square_side = int(np.ceil(glyph_side + margin * 2))
        square = Image.new("L", (square_side, square_side), 255)
        square.paste(
            glyph,
            ((square_side - glyph.width) // 2, (square_side - glyph.height) // 2),
        )
        image = square.resize((INPUT_SIDE, INPUT_SIDE), Image.Resampling.NEAREST)
        pixels = np.asarray(image, dtype=np.float32) / 255.0
    return (1.0 - pixels).reshape(-1)


def load_samples(rows: list[dict]) -> tuple[np.ndarray, np.ndarray]:
    features: list[np.ndarray] = []
    labels: list[str] = []
    for row in rows:
        features.append(preprocess(row["absolute_path"]))
        labels.append(row["latex"])
    return np.stack(features), np.asarray(labels)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", type=Path, default=Path("data/kaggle-hasyv2"))
    parser.add_argument("--output", type=Path, default=Path("assets/models/stroke_symbols.json"))
    parser.add_argument("--fold", type=int, default=1)
    parser.add_argument("--max-iter", type=int, default=800)
    args = parser.parse_args()

    root = ensure_dataset(args.data_dir)
    train_rows, test_rows = read_rows(
        root, root / "hasy-data-labels.csv", args.fold
    )
    x_train, y_train = load_samples(train_rows)
    x_test, y_test = load_samples(test_rows)

    model = LogisticRegression(
        C=2.0,
        max_iter=args.max_iter,
        class_weight="balanced",
        random_state=2026,
        solver="lbfgs",
    )
    model.fit(x_train, y_train)
    predictions = model.predict(x_test)
    accuracy = float(accuracy_score(y_test, predictions))
    print(f"HASYv2 fold {args.fold}: {len(x_train)} train, {len(x_test)} test samples")
    print(f"Held-out symbol accuracy: {accuracy:.4f}")
    print(classification_report(y_test, predictions, zero_division=0))

    classes = [str(value) for value in model.classes_]
    payload = {
        "version": MODEL_VERSION,
        "dataset": DATASET_HANDLE,
        "dataset_fold": args.fold,
        "input_side": INPUT_SIDE,
        "input_layout": "row-major grayscale, ink=1, background=0",
        "classes": [
            {"label": label, "token": SYMBOLS[label]} for label in classes
        ],
        "weights": np.round(model.coef_, 6).tolist(),
        "bias": np.round(model.intercept_, 6).tolist(),
        "validation_accuracy": round(accuracy, 6),
        "train_samples": int(len(x_train)),
        "validation_samples": int(len(x_test)),
        "training_method": "scikit-learn multinomial logistic regression",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    print(f"Saved offline model: {args.output} ({args.output.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
