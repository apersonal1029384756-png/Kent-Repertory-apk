import sqlite3
import re
import sys

DB_PATH = "assets/kent_repertory.db"
PAGE_START = 356
PAGE_END = 395

FACE_ANCHORS = [
    {"path": "Face", "page": 356, "mode": "exact"},
    {"path": "Face - chapped", "page": 356, "mode": "prefix"},
    {"path": "Face - eruptions - comedones", "page": 357, "mode": "prefix"},
    {"path": "Face - discoloration - black", "page": 358, "mode": "prefix"},
    {"path": "Face - discoloration - bluish - mouth", "page": 359, "mode": "prefix"},
    {"path": "Face - discoloration - pale - morning", "page": 360, "mode": "prefix"},
    {"path": "Face - discoloration - pale - lips", "page": 361, "mode": "prefix"},
    {"path": "Face - discoloration - red - circumscribed", "page": 362, "mode": "prefix"},
    {"path": "Face - discoloration - red - shivering", "page": 363, "mode": "prefix"},
    {"path": "Face - discoloration - yellow - morning", "page": 364, "mode": "prefix"},
    {"path": "Face - dryness - lips", "page": 365, "mode": "prefix"},
    {"path": "Face - eruptions - lips", "page": 366, "mode": "prefix"},
    {"path": "Face - eruptions - bleeding", "page": 367, "mode": "prefix"},
    {"path": "Face - eruptions - crusty", "page": 368, "mode": "prefix"},
    {"path": "Face - eruptions - herpes", "page": 369, "mode": "prefix"},
    {"path": "Face - eruptions - papular", "page": 370, "mode": "prefix"},
    {"path": "Face - eruptions - pimples", "page": 371, "mode": "prefix"},
    {"path": "Face - eruptions - red", "page": 372, "mode": "prefix"},
    {"path": "Face - eruptions - vesicles", "page": 373, "mode": "prefix"},
    {"path": "Face - excoriated", "page": 374, "mode": "prefix"},
    {"path": "Face - expression - suffering", "page": 375, "mode": "prefix"},
    {"path": "Face - heat - morning", "page": 376, "mode": "prefix"},
    {"path": "Face - heat - eating", "page": 377, "mode": "prefix"},
    {"path": "Face - heavy feeling", "page": 378, "mode": "prefix"},
    {"path": "Face - itching", "page": 379, "mode": "prefix"},
    {"path": "Face - pain - right", "page": 380, "mode": "prefix"},
    {"path": "Face - pain - air - open", "page": 381, "mode": "prefix"},
    {"path": "Face - pain - menses", "page": 382, "mode": "prefix"},
    {"path": "Face - pain - sun", "page": 383, "mode": "prefix"},
    {"path": "Face - pain - jaw - lower jaw", "page": 384, "mode": "prefix"},
    {"path": "Face - pain - burning", "page": 385, "mode": "prefix"},
    {"path": "Face - pain - cutting", "page": 386, "mode": "prefix"},
    {"path": "Face - pain - jerking", "page": 387, "mode": "prefix"},
    {"path": "Face - pain - sore", "page": 388, "mode": "prefix"},
    {"path": "Face - pain - stitching", "page": 389, "mode": "prefix"},
    {"path": "Face - pain - tearing", "page": 390, "mode": "prefix"},
    {"path": "Face - perspiration - noon", "page": 391, "mode": "prefix"},
    {"path": "Face - shaving", "page": 392, "mode": "prefix"},
    {"path": "Face - swelling - bee stings", "page": 393, "mode": "prefix"},
    {"path": "Face - swelling - lips", "page": 394, "mode": "prefix"},
    {"path": "Face - wrinkled", "page": 395, "mode": "prefix"},
]

def normalize_path(text):
    text = text.lower().strip()
    text = re.sub(r'\(.*?\)', '', text)
    text = re.sub(r"\s*[,>:]\s*", " - ", text)
    text = re.sub(r"\s+-\s*", " - ", text)
    text = re.sub(r"(?:\s*-\s*)+", " - ", text)
    return text.strip()

def anchor_matches(anchor, rubric):
    a = normalize_path(anchor["path"])
    r = normalize_path(rubric)
    if anchor["mode"] == "exact":
        return r == a
    if anchor["mode"] == "prefix":
        return r == a or r.startswith(a + " - ") or r.startswith(a)
    return False

def main():
    apply_changes = "--apply" in sys.argv

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute("SELECT id, full_path FROM rubrics WHERE full_path LIKE 'Face%' ORDER BY id ASC")
    rows = cur.fetchall()

    if not rows:
        print("ERROR: No rubrics found matching 'Face%'.")
        conn.close()
        return

    total_rows = len(rows)
    print(f"Loaded {total_rows} Face rubrics.")

    # 1. Match each anchor independently across all rows
    found_anchors = {}
    for anchor in FACE_ANCHORS:
        for idx, (r_id, full_path) in enumerate(rows):
            if anchor_matches(anchor, full_path):
                # Save the earliest row index for this anchor
                if idx not in found_anchors or anchor["page"] < found_anchors[idx][0]:
                    found_anchors[idx] = (anchor["page"], anchor["path"])
                break

    # 2. Sort by row position (idx)
    sorted_anchors = sorted([(idx, val[0], val[1]) for idx, val in found_anchors.items()], key=lambda x: x[0])

    # 3. Filter monotonicity (page numbers must strictly not regress backwards)
    clean_anchors = []
    curr_max_page = PAGE_START
    for idx, page, path in sorted_anchors:
        if page >= curr_max_page:
            clean_anchors.append((idx, page, path))
            curr_max_page = page

    # Ensure start and end bounds
    if not clean_anchors or clean_anchors[0][0] != 0:
        clean_anchors.insert(0, (0, PAGE_START, "Start Boundary"))
    if clean_anchors[-1][0] != total_rows - 1:
        clean_anchors.append((total_rows - 1, PAGE_END, "End Boundary"))

    print(f"Verified {len(clean_anchors)} monotonic anchor segments across {total_rows} rubrics.")

    # 4. Interpolate strictly between sorted, valid anchor segments
    updates = {}
    for i in range(len(clean_anchors) - 1):
        s_idx, s_page, _ = clean_anchors[i]
        e_idx, e_page, _ = clean_anchors[i + 1]
        span = e_idx - s_idx

        for j in range(s_idx, e_idx):
            r_id = rows[j][0]
            if span <= 0:
                p = s_page
            else:
                progress = (j - s_idx) / span
                p = int(round(s_page + progress * (e_page - s_page)))
            updates[r_id] = max(PAGE_START, min(PAGE_END, p))

    # Last row
    updates[rows[-1][0]] = PAGE_END
    update_payload = [(page, r_id) for r_id, page in updates.items()]

    if not apply_changes:
        print(f"[DRY RUN COMPLETE] Prepared {len(update_payload)} updates. Run with --apply.")
    else:
        print("Applying updates to database...")
        conn.execute("BEGIN TRANSACTION")
        cur.executemany("UPDATE rubrics SET page_number = ? WHERE id = ?", update_payload)
        conn.commit()
        print(f"Successfully calibrated and committed {len(update_payload)} Face rubrics!")

    conn.close()

if __name__ == "__main__":
    main()
