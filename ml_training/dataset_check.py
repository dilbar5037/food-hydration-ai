"""
Dataset validator for 4-class food recognition.

Checks that the expected directory structure exists and that each class
has at least the minimum required number of images.
"""

from __future__ import annotations

import sys
from collections import defaultdict
from pathlib import Path

EXPECTED_CLASSES = ["Rice", "Dosa", "Idli", "Chapati"]
MIN_IMAGES_PER_CLASS = 50
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def _count_files(class_dir: Path) -> tuple[int, int]:
  """Return (image_count, non_image_count) for the given class directory."""
  image_count = 0
  non_image_count = 0
  for entry in class_dir.iterdir():
    if entry.is_file():
      if entry.suffix.lower() in IMAGE_EXTENSIONS:
        image_count += 1
      else:
        non_image_count += 1
  return image_count, non_image_count


def _validate_dataset(root: Path) -> tuple[bool, list[str], list[str], list[dict[str, str]]]:
  errors: list[str] = []
  warnings: list[str] = []
  rows: list[dict[str, str]] = []

  if not root.exists() or not root.is_dir():
    errors.append(f"Dataset folder not found: {root}")
    return False, errors, warnings, rows

  # Check for exact expected class folders (case-sensitive)
  existing = {p.name for p in root.iterdir() if p.is_dir()}
  missing = [c for c in EXPECTED_CLASSES if c not in existing]
  if missing:
    errors.append(f"Missing class folders: {', '.join(missing)}")

  for class_name in EXPECTED_CLASSES:
    class_dir = root / class_name
    if not class_dir.exists():
      continue

    image_count, non_image_count = _count_files(class_dir)
    if image_count < MIN_IMAGES_PER_CLASS:
      errors.append(
        f"{class_name}: only {image_count} images (minimum {MIN_IMAGES_PER_CLASS})"
      )

    if non_image_count > 0:
      warnings.append(
        f"{class_name}: {non_image_count} non-image file(s) present (ignored)"
      )

    rows.append(
      {
        "Class": class_name,
        "Images": str(image_count),
        "Non-Images": str(non_image_count),
      }
    )

  # Warn about unexpected folders/files
  unexpected = []
  for entry in root.iterdir():
    if entry.name not in EXPECTED_CLASSES:
      unexpected.append(entry.name)
  if unexpected:
    warnings.append("Unexpected items present: " + ", ".join(sorted(unexpected)))

  return len(errors) == 0, errors, warnings, rows


def _print_table(rows: list[dict[str, str]]) -> None:
  if not rows:
    return
  headers = ["Class", "Images", "Non-Images"]
  widths = defaultdict(int)

  for header in headers:
    widths[header] = max(widths[header], len(header))

  for row in rows:
    for key, value in row.items():
      widths[key] = max(widths[key], len(value))

  def fmt_row(row: dict[str, str]) -> str:
    return " | ".join(f"{row[h]:<{widths[h]}}" for h in headers)

  header_line = fmt_row({h: h for h in headers})
  separator = "-+-".join("-" * widths[h] for h in headers)
  print(header_line)
  print(separator)
  for row in rows:
    print(fmt_row(row))


def main() -> int:
  repo_root = Path(__file__).resolve().parent.parent
  dataset_root = repo_root / "ml_dataset"

  ok, errors, warnings, rows = _validate_dataset(dataset_root)
  if rows:
    _print_table(rows)

  if warnings:
    print("\nWarnings:")
    for warn in warnings:
      print(f"- {warn}")

  if errors:
    print("\nIssues found:")
    for err in errors:
      print(f"- {err}")
    return 1

  print("\nDataset looks good.")
  return 0


if __name__ == "__main__":
  sys.exit(main())
