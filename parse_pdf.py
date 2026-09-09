import sqlite3
import re
from pypdf import PdfReader

PDF_PATH = "/sdcard/Download/Kent Repertory.pdf"
DB_PATH = "assets/kent_repertory.db"

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

cursor.execute("CREATE TABLE IF NOT EXISTS chapters (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE);")
cursor.execute("""
    CREATE TABLE IF NOT EXISTS rubrics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chapter_id INTEGER NOT NULL,
        parent_id INTEGER DEFAULT NULL,
        rubric_text TEXT NOT NULL,
        full_path TEXT NOT NULL,
        page_number INTEGER
    );
""")
cursor.execute("CREATE TABLE IF NOT EXISTS remedies (id INTEGER PRIMARY KEY AUTOINCREMENT, abbreviation TEXT UNIQUE);")
cursor.execute("""
    CREATE TABLE IF NOT EXISTS rubric_remedies (
        rubric_id INTEGER,
        remedy_id INTEGER,
        grade INTEGER CHECK(grade IN (1, 2, 3)),
        PRIMARY KEY (rubric_id, remedy_id)
    );
""")

reader = PdfReader(PDF_PATH)
total_pages = len(reader.pages)
current_chapter_id = None
current_chapter_name = ""
current_page_num = None
level_map = {}
remedy_cache = {}

def get_remedy_id(abbrev):
    clean = abbrev.strip().lower()
    if clean not in remedy_cache:
        cursor.execute("INSERT OR IGNORE INTO remedies (abbreviation) VALUES (?)", (clean,))
        cursor.execute("SELECT id FROM remedies WHERE abbreviation = ?", (clean,))
        remedy_cache[clean] = cursor.fetchone()[0]
    return remedy_cache[clean]

print(f"Total pages to process: {total_pages}")

for idx, page in enumerate(reader.pages):
    if idx % 50 == 0:
        print(f"Processing page {idx}/{total_pages}...")
        conn.commit()

    text = page.extract_text()
    if not text:
        continue

    page_num_match = re.search(r'^\s*(\d{1,4})\s*$', text, re.MULTILINE)
    if page_num_match:
        current_page_num = int(page_num_match.group(1))

    for line in text.split('\n'):
        line_str = line.strip()
        if not line_str:
            continue

        if line_str.isupper() and len(line_str) < 30 and ":" not in line_str:
            cursor.execute("INSERT OR IGNORE INTO chapters (name) VALUES (?)", (line_str,))
            cursor.execute("SELECT id, name FROM chapters WHERE name = ?", (line_str,))
            row = cursor.fetchone()
            current_chapter_id, current_chapter_name = row[0], row[1]
            level_map.clear()
            continue

        if current_chapter_id and ":" in line_str:
            parts = line_str.split(":", 1)
            rubric_text = parts[0].strip()
            remedies_blob = parts[1].strip()

            indent_level = len(line) - len(line.lstrip())
            parent_id = None
            path_parts = [current_chapter_name]
            for lvl in sorted(level_map.keys()):
                if lvl < indent_level:
                    parent_id = level_map[lvl]['id']
                    path_parts.append(level_map[lvl]['text'])
            path_parts.append(rubric_text)
            full_path = " - ".join(path_parts)

            cursor.execute(
                "INSERT INTO rubrics (chapter_id, parent_id, rubric_text, full_path, page_number) VALUES (?, ?, ?, ?, ?)",
                (current_chapter_id, parent_id, rubric_text, full_path, current_page_num)
            )
            rubric_id = cursor.lastrowid
            level_map[indent_level] = {'id': rubric_id, 'text': rubric_text}

            for token in re.split(r'[,;]\s*', remedies_blob):
                clean_token = token.strip().rstrip('.')
                if not clean_token:
                    continue
                grade = 3 if clean_token.isupper() else (2 if clean_token.istitle() else 1)
                rem_id = get_remedy_id(clean_token)
                cursor.execute(
                    "INSERT OR IGNORE INTO rubric_remedies (rubric_id, remedy_id, grade) VALUES (?, ?, ?)",
                    (rubric_id, rem_id, grade)
                )

conn.commit()
conn.close()
print("Database generated successfully at assets/kent_repertory.db")
