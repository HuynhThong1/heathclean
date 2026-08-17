#!/usr/bin/env python3
"""Report anything that would still be Vietnamese on an English screen.

Two failures, both invisible in a diff and both silent at runtime:

1. **A literal that never became a catalog key.** A component whose text
   parameter is a `String` swallows every literal written into it — the mistake
   `GrayNote` made, recorded in CLAUDE.md. It compiles, it renders, and it stays
   Vietnamese whatever the language is set to.
2. **A key with no `en` value.** The catalog falls back to the key, which *is*
   the Vietnamese, so a missed translation looks like working software.

Run it after `xcstringstool sync`, from the repo root:

    python3 Scripts/find-untranslated.py

Deliberate Vietnamese — `AppDate`'s month wording, `AppLanguage`'s own name for
Vietnamese, `#Preview` fixtures, mock dish names — is listed in `EXEMPT` with the
reason. Everything else it prints is a bug.
"""
import json
import pathlib
import re
import sys

CATALOG = pathlib.Path("App/Resources/Localizable.xcstrings")
SOURCES = pathlib.Path("App")

VIETNAMESE = "àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ"
VIETNAMESE += VIETNAMESE.upper()
HOLE = "\x00"

# Files whose Vietnamese literals are not UI copy, with why.
EXEMPT = {
    "App/Presentation/DesignSystem/AppDate.swift":
        "the Vietnamese month wording HISTORY_SPEC §6 specifies, in its own branch",
    "App/Presentation/DesignSystem/AppLanguage.swift":
        "a language names itself in its own language",
    "App/Presentation/DesignSystem/LogoLockup.swift": "#Preview labels",
    "App/Presentation/MealHistory/HistoryPreviewData.swift": "#Preview fixtures",
    "App/Presentation/MealHistory/MealChip.swift": "#Preview fixtures",
    "App/Presentation/MealHistory/HistoryDeviationBar.swift": "#Preview fixtures",
    "App/Presentation/MealHistory/HistorySearch.swift": "a #Preview's search term",
    "App/Presentation/MealHistory/HistoryStateViews.swift": "a #Preview's search term",
    "App/Data/Recognition/MockFoodRecognitionRepository.swift": "mock dish names — data",
    "App/DependencyContainer.swift": "UI-test fixture dish names — data",
}


def literals(source):
    """Yield (line, text) for every string literal, interpolations as holes.

    Depth-aware rather than a regex: `\\(a.joined(separator: ", "))` nests a
    string inside an interpolation inside a string, which a regex reads as three
    separate literals.
    """
    line = 1
    index = 0
    length = len(source)
    while index < length:
        character = source[index]
        if character == "\n":
            line += 1
            index += 1
            continue
        if source[index:index + 2] == "//":
            index = source.find("\n", index)
            if index == -1:
                return
            continue
        if character != '"':
            index += 1
            continue
        start_line = line
        index += 1
        pieces = []
        while index < length and source[index] != '"':
            if source[index] == "\n":
                line += 1
                index += 1
                continue
            if source[index] == "\\" and source[index + 1:index + 2] == "(":
                depth = 0
                index += 1
                while index < length:
                    if source[index] == "(":
                        depth += 1
                    elif source[index] == ")":
                        depth -= 1
                        if depth == 0:
                            index += 1
                            break
                    elif source[index] == '"':
                        index += 1
                        while index < length and source[index] != '"':
                            index += 2 if source[index] == "\\" else 1
                    elif source[index] == "\n":
                        line += 1
                    index += 1
                pieces.append(HOLE)
                continue
            if source[index] == "\\":
                pieces.append({"n": "\n", "t": "\t"}.get(source[index + 1], source[index + 1]))
                index += 2
                continue
            pieces.append(source[index])
            index += 1
        index += 1
        yield start_line, "".join(pieces)


def preview_line(source):
    """The line the file's previews start on, or infinity.

    Everything from the first `#Preview` down is developer-facing scaffolding —
    a preview's own name, and the fixtures the galleries below it feed to the
    components they show. None of it is copy a user ever reads, and none of it
    belongs in the catalog: a literal written into a `LocalizedStringKey` is
    extracted whether or not the app draws it, so preview scaffolding would both
    add keys to translate and keep dead ones alive.

    Every file in this repo puts its previews last, under a
    `// MARK: - Previews`. This is deliberately narrower than the whole-file
    entries in `EXEMPT`, which switch the check off for real UI copy as well.
    """
    for number, line in enumerate(source.splitlines(), 1):
        if line.lstrip().startswith("#Preview"):
            return number
    return float("inf")


SPECIFIER = re.compile(r"%%|%(\d+\$)?[@a-zA-Z]+")


def collapse(text):
    """Format specifiers become holes, so a literal matches its key.

    `%%` collapses to a single `%`: a per-cent sign the user reads is written
    `%` in the Swift literal and `%%` in the key it produces, and comparing the
    two forms directly flags every percentage in the app.
    """
    return SPECIFIER.sub(lambda match: "%" if match.group(0) == "%%" else HOLE, text)


def main():
    catalog = json.loads(CATALOG.read_text())
    strings = catalog["strings"]
    keys = set(strings)
    shapes = {collapse(key) for key in keys}

    uncovered = []
    for path in sorted(SOURCES.rglob("*.swift")):
        if str(path) in EXEMPT:
            continue
        source = path.read_text()
        cutoff = preview_line(source)
        for line, text in literals(source):
            if line >= cutoff:
                continue
            if not any(character in VIETNAMESE for character in text):
                continue
            if text in keys or collapse(text) in shapes:
                continue
            uncovered.append((path, line, text))

    untranslated = sorted(
        key for key, entry in strings.items()
        if key and "en" not in entry.get("localizations", {})
    )

    for path, line, text in uncovered:
        print(f"{path}:{line}: not a catalog key: {text.replace(HOLE, '…')}")
    for key in untranslated:
        print(f"{CATALOG}: no en translation: {key}")
    surviving = surviving_string_localized()
    for path, line in surviving:
        print(f"{path}:{line}: String(localized:) — resolves in the phone's language, use L()")

    total = len(uncovered) + len(untranslated) + len(surviving)
    print(
        f"\n{len(uncovered)} literal(s) outside the catalog, "
        f"{len(untranslated)} key(s) with no English, "
        f"{len(surviving)} String(localized:) left",
        file=sys.stderr,
    )
    return 1 if total else 0


def surviving_string_localized():
    """Any `String(localized:)` left in App/ — it ignores the language switch.

    Cheap, and it earns its place: converting these to `L()` was done with a
    search for `String(localized: ` on one line, and **eight calls wrapped the
    argument onto the next line and were missed**. Nothing else catches that —
    they resolve to a real catalog key, so the checks above see nothing wrong,
    and the only symptom is a sentence in the phone's language on a screen drawn
    in the other. Matching `localized:` alone is what finds them.
    """
    found = []
    for path in sorted(SOURCES.rglob("*.swift")):
        if path.name == "AppLanguage.swift":  # where `L` is defined
            continue
        for number, line in enumerate(path.read_text().splitlines(), 1):
            stripped = line.lstrip()
            if stripped.startswith("//"):
                continue
            if "localized:" in line:
                found.append((path, number))
    return found


if __name__ == "__main__":
    sys.exit(main())
