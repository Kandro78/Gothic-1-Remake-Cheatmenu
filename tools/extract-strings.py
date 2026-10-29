"""Lists the English texts of the cheat menu's scripts that need a translation.

Reads every Script\\CheatMenu\\**\\*.as file except the generated language tables, collects the
string literals that look like player-visible text, and compares them with
translations\\strings.json: prints the texts that have no entry yet and the entries no longer
used. With --add it adds the missing texts to strings.json with empty translations.

    python tools\\extract-strings.py [--add]
"""
import io, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "Kandro78-G1RCheatMenu", "Script", "CheatMenu")
TABLE = os.path.join(ROOT, "translations", "strings.json")
LANGS = ["de", "fr", "it", "es", "pt", "pl", "ru"]

LITERAL = re.compile(r'(\bn)?"((?:[^"\\]|\\.)*)"')

# literals that are code, not text: ids, class and asset names, key lists
SKIP_CALLS = re.compile(r'(FName\(|FindClassFromName|StartsWith\(|Contains\(|ParseIntoArray|Replace\(|Split\(|'
                        r'achievement\.Unlock|SpawnAIAgentDefinition_|TSoftObjectPtr|SaveGameToSlot|LoadGameFromSlot|'
                        r'\bSlot\s*=|ExecuteConsoleCommand)')


# short lowercase words that are text, not ids
KEEP = {"current", "ON"}


def looks_like_text(s):
    if s in KEEP:
        return True
    if not s or s in ("Character", "Kandro78-G1RCheatMenu", "?", "-", ">", "...", "x", " / ", ", ", ": ", " -> ", "  /  ", " (", " m)", "0", "\\t"):
        return False
    if re.fullmatch(r"[A-Za-z0-9_]+", s) and ("_" in s or not s[0].isupper()):
        return False  # ids such as Vlk_Armor_L, camp codes, name keys
    if re.fullmatch(r"(ACH|It[A-Za-z]{2}|ACH)_\w+", s):
        return False
    if re.fullmatch(r"[A-Z][a-z]+[A-Z]\w*", s) or re.fullmatch(r"[A-Z]{2}( [A-Z]{2})*", s):
        return False  # CamelCase class name parts, camp codes
    if re.fullmatch(r"[\W\d]*", s) or s.startswith(", "):
        return False
    words = s.split()
    if len(words) > 6 and all(w[0].isupper() for w in words):
        return False  # lists of item ids
    if len(words) > 1 and ("_" in s or all(re.fullmatch(r"[A-Z][a-z]*([A-Z][a-z]*)*", w) for w in words) and any(re.search(r"[a-z][A-Z]", w) for w in words)):
        return False  # space separated id lists
    return True


def code_part(line):
    """The line without a // comment after the code (a // inside a string is kept)."""
    in_string = False
    i = 0
    while i < len(line):
        c = line[i]
        if in_string and c == "\\":
            i += 2
            continue
        if c == '"':
            in_string = not in_string
        elif not in_string and line.startswith("//", i):
            return line[:i]
        i += 1
    return line


def collect():
    found = {}
    for folder, _, files in os.walk(SCRIPTS):
        if os.path.basename(folder) == "Lang":
            continue
        for name in sorted(files):
            if not name.endswith(".as"):
                continue
            path = os.path.join(folder, name)
            for no, line in enumerate(io.open(path, encoding="utf-8"), 1):
                if line.strip().startswith("//") or SKIP_CALLS.search(line):
                    continue
                if re.search(r"\bg\.Add\(", line):
                    continue  # people: names stay as they are
                for m in LITERAL.finditer(code_part(line)):
                    if m.group(1):
                        continue  # n"Name" literals are ids
                    s = m.group(2)
                    if looks_like_text(s):
                        found.setdefault(s, "%s:%d" % (os.path.relpath(path, SCRIPTS), no))
    return found


def main():
    found = collect()
    table = json.load(io.open(TABLE, encoding="utf-8")) if os.path.exists(TABLE) else {}
    missing = [s for s in found if s not in table]
    unused = [s for s in table if s not in found and not table[s].get("_keep")]
    for s in missing:
        print("missing  %-40s %s" % (found[s], s))
    for s in unused:
        print("unused   %s" % s)
    if "--add" in sys.argv:
        for s in missing:
            table[s] = {lang: "" for lang in LANGS}
        os.makedirs(os.path.dirname(TABLE), exist_ok=True)
        json.dump(table, io.open(TABLE, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=1, sort_keys=False)
        print("added %d texts" % len(missing))
    print("%d texts in code, %d missing, %d unused" % (len(found), len(missing), len(unused)))


if __name__ == "__main__":
    main()
