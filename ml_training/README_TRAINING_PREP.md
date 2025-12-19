# Training Prep (Label Freeze)

The label order is **frozen** to avoid mismatch bugs between training and inference:  
0: Rice  
1: Dosa  
2: Idli  
3: Chapati  

Do not rename folders and do not add/remove classes. Changing folder names or order will break alignment with `labels.txt` and any trained model.

## Commands to verify (run from repo root in PowerShell)
```
python ml_training/dataset_check.py
type labels.txt
type ml_training/training_config.json
```

## Dataset reminders
- Keep class folders exactly: `ml_dataset/Rice`, `ml_dataset/Dosa`, `ml_dataset/Idli`, `ml_dataset/Chapati`
- Minimum 50 images per class; recommended 100–200.
- Allowed image extensions: .jpg, .jpeg, .png, .webp (case-insensitive).
- Non-image files should not be placed in class folders (they are ignored in counts but reported).
