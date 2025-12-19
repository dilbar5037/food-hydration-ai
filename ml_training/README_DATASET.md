# ML Dataset Setup

Dataset target: 4 food classes for recognition — `Rice`, `Dosa`, `Idli`, `Chapati`.

## Folder structure
Place images under the repo root in `ml_dataset/`:
```
ml_dataset/
  Rice/
  Dosa/
  Idli/
  Chapati/
```

## Image counts
- Minimum: **50 images per class** (hard requirement for the checker)
- Recommended: **100–200 images per class** for better model quality

## Running the dataset checker
From the repo root in PowerShell:
```
python ml_training/dataset_check.py
```
or
```
py ml_training/dataset_check.py
```

## What the checker does
- Verifies `ml_dataset/` exists.
- Ensures the four class folders exist with exact names (case-sensitive).
- Counts images with extensions: `.jpg`, `.jpeg`, `.png`, `.webp`.
- Fails if any class has fewer than 50 images.
- Warns about non-image files or unexpected items.
- Prints a summary table of counts.

## Common mistakes to avoid
- Wrong folder names (e.g., `rice/` instead of `Rice/`, or extra spaces).
- Mixing classes in the same folder.
- Too few images per class (< 50).
- Leaving non-image files in class folders (they’re ignored but warned).
- Placing images outside `ml_dataset/<ClassName>/`.
