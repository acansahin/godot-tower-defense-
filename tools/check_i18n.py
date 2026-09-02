"""Checks that every translation key the game asks for exists, and that none is dead.

A missing key is SILENT in Godot: `tr("HUD_SEND_NEXT")` with no row returns the key itself,
so the button reads "HUD_SEND_NEXT" on screen and nothing is logged. That is exactly how the
Send Next button shipped English-only through a first pass -- the row had simply been dropped
from the table. Screenshots catch it only on the one screen you happen to photograph.

Two directions, because both fail quietly:
  * used but not defined -> the raw key appears on screen
  * defined but never used -> a translated string nobody can reach, and a column to maintain

Run from anywhere:
    python tools/check_i18n.py
Exits non-zero when anything is missing, so CI can gate on it.

No third-party dependency, like everything else in tools/.
"""
import csv, io, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(ROOT, 'godottowerdefense')
CSV_PATH = os.path.join(PROJECT, 'assets', 'i18n', 'strings.csv')

# A key looks like this and nothing else does: SCREAMING_SNAKE, at least two characters.
KEY_RE = re.compile(r'^[A-Z][A-Z0-9_]+$')
# Any SCREAMING_SNAKE string literal in a .gd file. Deliberately looser than a `tr("KEY")`
# shape: how_to_play.gd keeps its bullet keys in a `const BASIC_KEYS: Array` and reaches them
# with `tr(String(k))`, which no tr()-shaped pattern can see. GDScript never quotes an
# identifier, so a false positive would have to be a data string that is itself all-caps.
TR_RE = re.compile(r'"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)"')
# tr("PREFIX_" + ...) -- the derived form the workshop rows and the fusion tab use. The
# prefix alone is reported so a human can check the family by eye; it is not an error.
TR_PREFIX_RE = re.compile(r'\btr\(\s*"([A-Z][A-Z0-9_]*_)"\s*\+')
# text = "KEY" in a .tscn, which Godot auto-translates.
SCENE_RE = re.compile(r'^\s*text = "([A-Z][A-Z0-9_]*)"\s*$', re.M)


def defined_keys():
    with io.open(CSV_PATH, encoding='utf-8', newline='') as f:
        rows = list(csv.reader(f))
    header, body = rows[0], rows[1:]
    keys = [r[0] for r in body if r]
    blanks = [(r[0], header[i]) for r in body if r
              for i in range(1, len(header)) if i >= len(r) or not r[i].strip()]
    dupes = sorted({k for k in keys if keys.count(k) > 1})
    return header, set(keys), blanks, dupes


def used_keys():
    used, prefixes = {}, {}
    for sub, pattern in (('scripts', TR_RE), ('scenes', SCENE_RE)):
        base = os.path.join(PROJECT, sub)
        for name in sorted(os.listdir(base)):
            path = os.path.join(base, name)
            if not os.path.isfile(path):
                continue
            text = io.open(path, encoding='utf-8', newline='').read()
            for k in pattern.findall(text):
                used.setdefault(k, set()).add(sub + '/' + name)
            if sub == 'scripts':
                for p in TR_PREFIX_RE.findall(text):
                    prefixes.setdefault(p, set()).add(sub + '/' + name)
    return used, prefixes


def main():
    header, defined, blanks, dupes = defined_keys()
    used, prefixes = used_keys()

    # A key reached only through a derived prefix ("WS_NAME_" + id) is used, not dead.
    covered = set()
    for k in defined:
        for p in prefixes:
            if k.startswith(p):
                covered.add(k)

    # `tr("WS_NAME_" + id)` also matches the key pattern; it is a prefix, not a key.
    missing = sorted(k for k in used if k not in defined and k not in prefixes)
    dead = sorted(defined - set(used) - covered)

    print('locales: %s' % ', '.join(header[1:]))
    print('%d keys defined, %d referenced directly, %d reached by prefix'
          % (len(defined), len(used), len(covered)))
    for p in sorted(prefixes):
        n = len([k for k in defined if k.startswith(p)])
        print('  prefix %-16s %d keys' % (p + '*', n))

    bad = False
    if dupes:
        bad = True
        print('\nDUPLICATE keys (%d):' % len(dupes))
        for k in dupes:
            print('  ' + k)
    if missing:
        bad = True
        print('\nMISSING -- used in code but not in strings.csv (%d):' % len(missing))
        for k in missing:
            print('  %-24s  %s' % (k, ', '.join(sorted(used[k]))))
    if blanks:
        bad = True
        print('\nUNTRANSLATED -- empty cell (%d):' % len(blanks))
        for k, loc in blanks:
            print('  %-24s  %s' % (k, loc))
    if dead:
        print('\nunused -- defined but never referenced (%d):' % len(dead))
        for k in dead:
            print('  ' + k)

    if not bad:
        print('\nOK')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
