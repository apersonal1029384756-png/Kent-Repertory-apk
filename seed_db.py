import sqlite3
import os

DB_PATH = "assets/kent_repertory.db"
if os.path.exists(DB_PATH):
    os.remove(DB_PATH)

conn = sqlite3.connect(DB_PATH)
cur = conn.cursor()

# 1. Create Tables
cur.execute("CREATE TABLE chapters (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE);")
cur.execute("""
    CREATE TABLE rubrics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chapter_id INTEGER NOT NULL,
        parent_id INTEGER DEFAULT NULL,
        rubric_text TEXT NOT NULL,
        full_path TEXT NOT NULL,
        page_number INTEGER
    );
""")
cur.execute("CREATE TABLE remedies (id INTEGER PRIMARY KEY AUTOINCREMENT, abbreviation TEXT UNIQUE);")
cur.execute("""
    CREATE TABLE rubric_remedies (
        rubric_id INTEGER,
        remedy_id INTEGER,
        grade INTEGER CHECK(grade IN (1, 2, 3)),
        PRIMARY KEY (rubric_id, remedy_id)
    );
""")

# 2. Comprehensive Starter Clinical Rubric Tree
dataset = [
    # MIND
    ("MIND", "ANXIETY", "MIND - ANXIETY", 3, [("ars", 3), ("acon", 3), ("bell", 2), ("phos", 3), ("puls", 2), ("rhus-t", 2), ("calc", 2)]),
    ("MIND", "ANXIETY - night", "MIND - ANXIETY - night", 4, [("ars", 3), ("rhus-t", 3), ("acon", 2), ("calc", 1)]),
    ("MIND", "FEAR", "MIND - FEAR", 42, [("acon", 3), ("bell", 3), ("ars", 2), ("phos", 3), ("calc", 3), ("ign", 2)]),
    ("MIND", "FEAR - death, of", "MIND - FEAR - death, of", 43, [("acon", 3), ("ars", 3), ("calc", 2), ("phos", 2), ("nit-ac", 2)]),
    ("MIND", "IRRITABILITY", "MIND - IRRITABILITY", 57, [("nux-v", 3), ("cham", 3), ("bry", 3), ("sulph", 2), ("lyc", 2), ("hep", 2)]),
    ("MIND", "SADNESS, mental depression", "MIND - SADNESS, mental depression", 75, [("aur", 3), ("ign", 3), ("nat-m", 3), ("puls", 3), ("sep", 3), ("caust", 2)]),

    # VERTIGO
    ("VERTIGO", "VERTIGO", "VERTIGO", 96, [("con", 3), ("bry", 3), ("calc", 2), ("nux-v", 3), ("phos", 3), ("puls", 2)]),
    ("VERTIGO", "VERTIGO - motion, from", "VERTIGO - VERTIGO - motion, from", 99, [("bry", 3), ("cocc", 3), ("con", 2), ("tab", 2)]),

    # HEAD
    ("HEAD", "PAIN, headache", "HEAD - PAIN, headache", 132, [("bell", 3), ("bry", 3), ("glon", 3), ("nux-v", 3), ("nat-m", 3), ("sang", 3), ("spig", 3), ("sil", 2)]),
    ("HEAD", "PAIN - morning", "HEAD - PAIN - morning", 134, [("nux-v", 3), ("bry", 3), ("nat-m", 3), ("sulph", 2), ("sang", 2)]),
    ("HEAD", "PAIN - burning", "HEAD - PAIN - burning", 176, [("ars", 3), ("bell", 3), ("phos", 2), ("acon", 2), ("sulph", 2)]),
    ("HEAD", "PAIN - forehead", "HEAD - PAIN - forehead", 147, [("bell", 3), ("bry", 3), ("nux-v", 2), ("glon", 2), ("puls", 2)]),
    ("HEAD", "PAIN - throbbing", "HEAD - PAIN - throbbing", 188, [("bell", 3), ("glon", 3), ("mel", 2), ("sang", 2), ("nat-m", 2)]),

    # STOMACH & ABDOMEN
    ("STOMACH", "APPETITE - ravenous", "STOMACH - APPETITE - ravenous", 477, [("cina", 3), ("iod", 3), ("calc", 2), ("lyc", 2), ("sulph", 2)]),
    ("STOMACH", "ERUCTATIONS", "STOMACH - ERUCTATIONS", 489, [("carb-v", 3), ("nux-v", 3), ("puls", 2), ("lyc", 2), ("chin", 2)]),
    ("STOMACH", "NAUSEA", "STOMACH - NAUSEA", 504, [("ip", 3), ("nux-v", 3), ("ars", 2), ("ant-t", 3), ("tab", 3), ("puls", 2)]),
    ("RECTUM", "DIARRHOEA", "RECTUM - DIARRHOEA", 608, [("aloe", 3), ("ars", 3), ("crot-t", 3), ("podo", 3), ("sulph", 3), ("cham", 2)]),
    ("RECTUM", "HAEMORRHOIDS", "RECTUM - HAEMORRHOIDS", 619, [("aescul", 3), ("aloe", 3), ("ham", 3), ("nux-v", 3), ("coll", 2), ("sulph", 2)]),

    # RESPIRATION & COUGH
    ("RESPIRATION", "ASTHMATIC", "RESPIRATION - ASTHMATIC", 763, [("ars", 3), ("ip", 3), ("ant-t", 2), ("nat-s", 3), ("med", 2), ("blatta", 2)]),
    ("COUGH", "COUGH", "COUGH - COUGH", 777, [("acon", 3), ("bell", 3), ("bry", 3), ("dros", 3), ("phos", 3), ("rumx", 3), ("spong", 3)]),
    ("COUGH", "DRY", "COUGH - DRY", 785, [("acon", 3), ("bell", 3), ("bry", 3), ("hyos", 3), ("phos", 2), ("spong", 2)]),

    # GENERALITIES
    ("GENERALITIES", "MOTION, agg.", "GENERALITIES - MOTION, agg.", 1373, [("bry", 3), ("ran-b", 2), ("colch", 2), ("bell", 2)]),
    ("GENERALITIES", "MOTION, amel.", "GENERALITIES - MOTION, amel.", 1375, [("rhus-t", 3), ("puls", 3), ("ferr", 2), ("lyc", 2)]),
    ("GENERALITIES", "WARMTH, amel.", "GENERALITIES - WARMTH, amel.", 1412, [("ars", 3), ("hep", 3), ("mag-p", 3), ("sil", 3), ("rhus-t", 2)])
]

remedy_map = {}
def get_rem_id(code):
    if code not in remedy_map:
        cur.execute("INSERT OR IGNORE INTO remedies (abbreviation) VALUES (?)", (code,))
        cur.execute("SELECT id FROM remedies WHERE abbreviation = ?", (code,))
        remedy_map[code] = cur.fetchone()[0]
    return remedy_map[code]

chapter_map = {}
for ch_name, rubric_txt, path, pg, remedies in dataset:
    if ch_name not in chapter_map:
        cur.execute("INSERT OR IGNORE INTO chapters (name) VALUES (?)", (ch_name,))
        cur.execute("SELECT id FROM chapters WHERE name = ?", (ch_name,))
        chapter_map[ch_name] = cur.fetchone()[0]
    ch_id = chapter_map[ch_name]

    cur.execute(
        "INSERT INTO rubrics (chapter_id, rubric_text, full_path, page_number) VALUES (?, ?, ?, ?)",
        (ch_id, rubric_txt, path, pg)
    )
    rub_id = cur.lastrowid

    for r_code, grade in remedies:
        r_id = get_rem_id(r_code)
        cur.execute(
            "INSERT INTO rubric_remedies (rubric_id, remedy_id, grade) VALUES (?, ?, ?)",
            (rub_id, r_id, grade)
        )

conn.commit()
conn.close()
print("Clean Repertory database successfully written to assets/kent_repertory.db")
