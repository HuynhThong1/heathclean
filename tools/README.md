# tools

One-off generators, kept so the artefacts they produce can be regenerated
rather than only edited as binaries.

## icongen.swift

Renders the app icon candidates at 1024×1024 from the FPT IS brand ramps and
the bundled typeface. Direction **D** (three-colour ring around an `H`
monogram) is the one that ships.

```bash
swiftc -O tools/icongen.swift -o /tmp/icongen
/tmp/icongen <output-dir> App/Resources/Fonts
```

## flatten.swift

Strips the alpha channel — iOS rejects app icons containing transparency.

```bash
swiftc -O tools/flatten.swift -o /tmp/flatten
/tmp/flatten <in.png> App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```
