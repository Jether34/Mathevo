# Handwritten symbol reader

Mathevo Draw mode now includes a small on-device classifier for a single isolated handwritten symbol. It complements the existing ML Kit full-expression transcription path. It does not replace expression OCR, infer two-dimensional math layout, or solve a complete handwritten equation by itself.

## What it recognizes

The model suggests digits `0` through `9`, plus, minus, slash, division, multiplication, dot multiplication, and pi. Draw one symbol on the canvas, select **Read one symbol**, then tap the closest suggestion. Accepted symbols are appended to the editable expression. The canvas clears after each accepted symbol so a longer expression can be composed one glyph at a time. The person can edit or solve the expression after composing it.

The classifier always presents alternatives for confirmation. It should not silently replace the existing ML Kit expression reader. The current drawing canvas is still available for whole-expression recognition through **Analyze**.

## Model and evaluation

- Dataset: HASYv2 from Kaggle, `guru001/hasyv2`.
- Input: centered 28 by 28 grayscale ink image.
- Model: multinomial logistic regression with 17 output classes.
- Runtime: pure Dart inference with bundled weights, no network request and no on-device ML runtime dependency.
- Evaluation split: official HASYv2 `fold-1` test split.
- Recorded result: 5,296 train symbols, 596 held-out symbols, 91.61% weighted accuracy and 82.5% macro F1.
- Important limitation: the dataset has few examples for some digits. On this fold, individual digit classes varied substantially, so the app keeps the result as a selectable suggestion.

This is a first compact symbol recognizer, not a complete handwriting or mathematical expression model. Fraction layout, superscripts, roots, multi-character variables, and expression segmentation remain with the existing OCR and manual correction flow.

## Training again

Install Python dependencies:

```powershell
python -m pip install -r tools/handwriting/requirements.txt
```

KaggleHub uses the current Kaggle API token or credential file. Do not commit Kaggle credentials. The downloader only downloads the public dataset and the training script writes the derived weights to `assets/models/stroke_symbols.json`.

```powershell
python tools/handwriting/train_symbol_model.py
```

To use a previously downloaded dataset:

```powershell
python tools/handwriting/train_symbol_model.py --data-dir path/to/hasyv2
```

The script uses the dataset's provided classification fold, reports held-out metrics, and exports the model metadata and weights. The raw dataset is not part of this repository.

## Attribution and data terms

The model was trained from HASYv2. The Kaggle data card lists the database license as Open Database License and credits the HASYv2 dataset authors. See the [Kaggle HASYv2 data card](https://www.kaggle.com/datasets/guru001/hasyv2) and the [HASYv2 paper](https://arxiv.org/abs/1701.08380) for provenance and citation details. No handwritten source images are bundled with Mathevo.
