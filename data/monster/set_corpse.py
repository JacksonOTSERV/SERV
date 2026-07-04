import os
import re

MONSTER_DIR = os.path.dirname(os.path.abspath(__file__))
CORPSE_ID = "16330"

changed = 0
skipped = 0

for filename in os.listdir(MONSTER_DIR):
    if not filename.endswith(".xml"):
        continue

    filepath = os.path.join(MONSTER_DIR, filename)

    with open(filepath, "r", encoding="utf-8-sig") as f:
        content = f.read()

    new_content = re.sub(r'(<look\b[^>]*?\bcorpse=")[^"]*(")', r'\g<1>' + CORPSE_ID + r'\2', content)

    if new_content != content:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(new_content)
        changed += 1
    else:
        skipped += 1

print(f"Done! Changed: {changed} | Skipped (no corpse attr): {skipped}")
