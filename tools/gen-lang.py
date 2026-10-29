"""Writes the cheat menu's language tables from translations\\strings.json.

strings.json maps every English text to its translations: { "English": { "de": "...", ... } }.
An empty translation leaves the English text. For each language this writes
Script\\CheatMenu\\Lang\\CMLang_<code>.as with a function CMLang::<Code>(TMap) that fills the
table CM::T looks texts up in (see CMLang.as). Run tools\\extract-strings.py first to find texts
that are new in the code.

    python tools\\gen-lang.py
"""
import io, json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLE = os.path.join(ROOT, "translations", "strings.json")
OUT = os.path.join(ROOT, "Kandro78-G1RCheatMenu", "Script", "CheatMenu", "Lang")
LANGS = {"de": "German", "fr": "French", "it": "Italian", "es": "Spanish", "pt": "Portuguese", "pl": "Polish", "ru": "Russian"}


def literal(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def main():
    table = json.load(io.open(TABLE, encoding="utf-8"))
    os.makedirs(OUT, exist_ok=True)
    for code, name in LANGS.items():
        lines = [
            "// G1R Cheat Menu: %s texts. Made by tools\\gen-lang.py from translations\\strings.json;" % name,
            "// change them there, not here. The translations are AI-written: corrections are welcome.",
            "",
            "namespace CMLang",
            "{",
            "    void %s(TMap<FString, FString>& M)" % code.capitalize(),
            "    {",
        ]
        count = 0
        for en, row in table.items():
            text = row.get(code, "")
            if text and text != en:
                lines.append("        M.Add(%s, %s);" % (literal(en), literal(text)))
                count += 1
        lines += ["    }", "}", ""]
        path = os.path.join(OUT, "CMLang_%s.as" % code)
        io.open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
        print("%s: %d texts" % (os.path.relpath(path, ROOT), count))


if __name__ == "__main__":
    main()
