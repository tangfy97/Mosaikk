import glob, html, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from translations import T, GB

root = sys.argv[1]
missing = set()
for language, pick in [("zh-Hans", 0), ("zh-Hant", 1), ("en-GB", None)]:
    for path in glob.glob(f"{root}/{language}.xcloc/Localized Contents/*.xliff"):
        text = open(path, encoding="utf-8").read()
        def fill(match):
            unit = match.group(0)
            found = re.search(r"<source[^>]*>(.*?)</source>", unit, re.S)
            if not found:
                return unit
            source = html.unescape(found.group(1))
            if pick is None:
                target = GB.get(source, source)
            elif source in T:
                target = T[source][pick]
            else:
                missing.add(source)
                return unit
            unit = re.sub(r"\s*<target[^>]*>.*?</target>", "", unit, flags=re.S)
            return unit.replace("</source>", "</source>\n        <target state=\"translated\">" + html.escape(target, quote=False) + "</target>", 1)
        text = re.sub(r"<trans-unit .*?</trans-unit>", fill, text, flags=re.S)
        open(path, "w", encoding="utf-8").write(text)
if missing:
    print("Missing translations:")
    for source in sorted(missing):
        print("  " + source)
