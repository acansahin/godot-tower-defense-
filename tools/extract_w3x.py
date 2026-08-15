#!/usr/bin/env python3
"""Read a Warcraft III map (.w3x / .w3m) and print the game data inside it.

This exists so the numbers in ``godottowerdefense/docs/element-td-data.md`` can be
re-derived instead of trusted. The Element TD port takes its tower roster, element
recipes and stat curves straight from the original maps; without a tool the data
is a one-off copy-paste nobody can check.

A .w3x is a 512-byte HM3W header followed by an MPQ archive. Every file that
matters here is stored with zlib compression, so no external MPQ library is
needed -- the archive reader below is about 80 lines and depends only on the
standard library.

Usage::

    python tools/extract_w3x.py <map.w3x> files
    python tools/extract_w3x.py <map.w3x> cat war3map.j
    python tools/extract_w3x.py <map.w3x> towers
    python tools/extract_w3x.py <map.w3x> recipes
    python tools/extract_w3x.py <map.w3x> creeps
    python tools/extract_w3x.py <map.w3x> pathing

``towers`` groups every custom unit by gold cost, which is what separates the
tiers: in Element TD v2.0 the six base elements sit at 50 / 175 / 788 / 3544 /
24444, the fifteen duals at 275 / 1775 / 7975 and the twenty triples at 1017 /
5317.
"""

from __future__ import annotations

import argparse
import re
import struct
import sys
import zlib
from collections import defaultdict

# Files a WC3 map is built from. MPQ stores names only as hashes, so a name has
# to be guessed before it can be looked up -- there is no directory to walk
# unless the map ships a (listfile), and protected maps usually encrypt it.
KNOWN_FILES = [
    "(listfile)", "(attributes)",
    "war3map.w3e", "war3map.w3i", "war3map.wts", "war3map.j",
    "war3map.w3u", "war3map.w3t", "war3map.w3a", "war3map.w3b",
    "war3map.w3d", "war3map.w3q", "war3map.w3c", "war3map.w3r", "war3map.w3s",
    "war3map.doo", "war3mapUnits.doo", "war3map.shd", "war3map.wpm",
    "war3map.mmp", "war3map.imp", "war3mapMap.blp",
    "scripts\\war3map.j",
]

# Object-editor field ids worth decoding. The full set runs to hundreds; these
# are the ones the port actually reads.
UNIT_FIELDS = {
    b"unam": "name",
    b"ugol": "gold",
    b"ulum": "lumber",
    b"ua1b": "dmg_base",
    b"ua1d": "dmg_dice",
    b"ua1s": "dmg_sides",
    b"ua1c": "cooldown",
    b"ua1r": "range",
    b"ua1t": "attack_type",
    b"ua1w": "splash",
    b"uhpm": "hp",
    b"umvs": "speed",
    b"udty": "defense_type",
    b"ubba": "bounty_base",
    b"ubdi": "bounty_dice",
    b"ubsi": "bounty_sides",
    b"utip": "tip",
    b"utub": "tip_extended",
}


class ArchiveError(Exception):
    pass


def _crypt_table() -> dict[int, int]:
    """Build the fixed table MPQ uses for both hashing and encryption."""
    table: dict[int, int] = {}
    seed = 0x00100001
    for i in range(0x100):
        for j in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB
            high = (seed & 0xFFFF) << 0x10
            seed = (seed * 125 + 3) % 0x2AAAAB
            table[i + j * 0x100] = high | (seed & 0xFFFF)
    return table


_CT = _crypt_table()


def _hash(text: str, kind: int) -> int:
    """MPQ string hash. `kind` picks which of the three hashes to compute."""
    seed1, seed2 = 0x7FED7FED, 0xEEEEEEEE
    for char in text.upper().replace("/", "\\"):
        value = ord(char)
        seed1 = _CT[(kind * 0x100) + value] ^ ((seed1 + seed2) & 0xFFFFFFFF)
        seed2 = (value + seed1 + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF
    return seed1


def _decrypt(data: bytes, key: int) -> bytes:
    seed = 0xEEEEEEEE
    out = bytearray()
    for offset in range(0, len(data) - 3, 4):
        seed = (seed + _CT[0x400 + (key & 0xFF)]) & 0xFFFFFFFF
        value = struct.unpack_from("<I", data, offset)[0] ^ ((key + seed) & 0xFFFFFFFF)
        key = ((((~key) << 0x15) + 0x11111111) | (key >> 0x0B)) & 0xFFFFFFFF
        seed = (value + seed + (seed << 5) + 3) & 0xFFFFFFFF
        out += struct.pack("<I", value)
    return bytes(out)


class W3XArchive:
    """Minimal read-only MPQ reader, enough for a Warcraft III map."""

    FLAG_ENCRYPTED = 0x00010000
    FLAG_COMPRESSED = 0x00000200

    def __init__(self, path: str) -> None:
        with open(path, "rb") as handle:
            self.raw = handle.read()
        self.path = path
        self.map_name = ""
        if self.raw[:4] == b"HM3W":
            end = self.raw.index(b"\0", 8)
            self.map_name = self.raw[8:end].decode("utf-8", "replace")
        self.base = self._find_header()
        (_, _, _, sector_shift, hash_off, block_off,
         hash_count, self.block_count) = struct.unpack_from("<IIHHIIII", self.raw, self.base + 4)
        self.sector_size = 512 << sector_shift
        self.hash_table = _decrypt(
            self.raw[self.base + hash_off: self.base + hash_off + hash_count * 16],
            _hash("(hash table)", 3))
        self.block_table = _decrypt(
            self.raw[self.base + block_off: self.base + block_off + self.block_count * 16],
            _hash("(block table)", 3))
        self.index: dict[tuple[int, int], int] = {}
        for i in range(hash_count):
            name_a, name_b, _locale, block = struct.unpack_from("<IIII", self.hash_table, i * 16)
            if block < 0xFFFFFFFE:
                self.index[(name_a, name_b)] = block

    def _find_header(self) -> int:
        for offset in range(0, len(self.raw), 512):
            if self.raw[offset:offset + 4] == b"MPQ\x1a":
                return offset
        raise ArchiveError(f"{self.path}: no MPQ header found")

    def has(self, name: str) -> bool:
        return (_hash(name, 1), _hash(name, 2)) in self.index

    def read(self, name: str) -> bytes:
        key = (_hash(name, 1), _hash(name, 2))
        if key not in self.index:
            raise ArchiveError(f"{self.path}: {name} not in archive")
        block = self.index[key]
        pos, _csize, fsize, flags = struct.unpack_from("<IIII", self.block_table, block * 16)
        if flags & self.FLAG_ENCRYPTED:
            raise ArchiveError(f"{name} is encrypted; key recovery is not implemented")
        start = self.base + pos
        if not flags & self.FLAG_COMPRESSED:
            return self.raw[start:start + fsize]
        sectors = (fsize + self.sector_size - 1) // self.sector_size
        table = struct.unpack_from(f"<{sectors + 1}I", self.raw, start)
        out = bytearray()
        for i in range(sectors):
            chunk = self.raw[start + table[i]: start + table[i + 1]]
            expected = min(self.sector_size, fsize - i * self.sector_size)
            # A sector that did not shrink is stored raw, with no method byte.
            if len(chunk) >= expected:
                out += chunk[:expected]
                continue
            method, payload = chunk[0], chunk[1:]
            if method == 0x02:
                out += zlib.decompress(payload)
            else:
                raise ArchiveError(f"{name}: unsupported compression 0x{method:02x}")
        return bytes(out)

    def files(self) -> list[tuple[str, int, int]]:
        """Return (name, compressed, uncompressed) for every name we can guess."""
        found = []
        for name in KNOWN_FILES:
            key = (_hash(name, 1), _hash(name, 2))
            if key not in self.index:
                continue
            block = self.index[key]
            _pos, csize, fsize, _flags = struct.unpack_from("<IIII", self.block_table, block * 16)
            found.append((name, csize, fsize))
        return found


def parse_wts(text: str) -> dict[int, str]:
    """Parse war3map.wts, the table every TRIGSTR_nnn reference points into."""
    strings: dict[int, str] = {}
    for match in re.finditer(r"STRING\s+(\d+)[^{]*\{", text):
        start = match.end()
        end = text.find("\n}", start)
        if end >= 0:
            strings[int(match.group(1))] = text[start:end].strip()
    return strings


def parse_object_data(buf: bytes, fields: dict[bytes, str]) -> list[dict]:
    """Parse a WC3 object-data file (.w3u/.w3a/...).

    Layout is a version int, then two tables (base-game overrides, then custom
    units). Each entry is origId + newId + a modification count, and each
    modification is a 4-char field id, a type tag, the value, and a trailing
    int that repeats the object id.
    """
    pos = 4
    records: list[dict] = []
    for _table in range(2):
        if pos >= len(buf):
            break
        count = struct.unpack_from("<I", buf, pos)[0]
        pos += 4
        for _ in range(count):
            record = {
                "orig": buf[pos:pos + 4].decode("latin1"),
                "new": buf[pos + 4:pos + 8].decode("latin1"),
            }
            pos += 8
            mods = struct.unpack_from("<I", buf, pos)[0]
            pos += 4
            for _ in range(mods):
                field = buf[pos:pos + 4]
                vtype = struct.unpack_from("<I", buf, pos + 4)[0]
                pos += 8
                if vtype == 0:
                    value = struct.unpack_from("<i", buf, pos)[0]
                    pos += 4
                elif vtype in (1, 2):
                    value = struct.unpack_from("<f", buf, pos)[0]
                    pos += 4
                else:
                    end = buf.index(b"\0", pos)
                    value = buf[pos:end].decode("latin1")
                    pos = end + 1
                pos += 4  # trailing object id
                if field in fields:
                    record[fields[field]] = value
            records.append(record)
    return records


def _strip_color(text: str) -> str:
    """Drop WC3 colour codes (|cAARRGGBB ... |r) and line breaks (|n)."""
    text = re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", text)
    text = text.replace("|n", " ")
    return re.sub(r"\s+", " ", text).strip()


class MapData:
    """A map plus its resolved strings and unit table."""

    def __init__(self, path: str) -> None:
        self.archive = W3XArchive(path)
        self.strings = parse_wts(self.archive.read("war3map.wts").decode("utf-8-sig", "replace"))
        self.units = parse_object_data(self.archive.read("war3map.w3u"), UNIT_FIELDS)

    def text(self, value) -> str:
        match = re.match(r"TRIGSTR_(\d+)", str(value))
        if not match:
            return str(value)
        return self.strings.get(int(match.group(1)), str(value))

    def name(self, record: dict) -> str:
        raw = self.text(record.get("name", ""))
        return raw.splitlines()[0].strip() if raw else ""

    def damage(self, record: dict) -> int:
        """Average hit: base plus the dice roll the object editor rolls per shot."""
        base = record.get("dmg_base", 0) or 0
        dice = record.get("dmg_dice", 0) or 0
        sides = record.get("dmg_sides", 0) or 0
        return int(base + dice * (1 + sides) / 2)


def cmd_files(data: MapData, _args) -> None:
    print(f"{data.archive.path}")
    print(f"  map name  : {data.archive.map_name}")
    print(f"  blocks    : {data.archive.block_count}")
    print(f"  sector    : {data.archive.sector_size}")
    for name, csize, fsize in data.archive.files():
        print(f"    {name:<22} {csize:>8} -> {fsize:>8}")


def cmd_cat(data: MapData, args) -> None:
    sys.stdout.write(data.archive.read(args.name).decode("utf-8-sig", "replace"))


def cmd_towers(data: MapData, _args) -> None:
    by_cost: dict[int, list[dict]] = defaultdict(list)
    for record in data.units:
        cost = record.get("gold")
        if isinstance(cost, int) and cost > 0 and "name" in record:
            by_cost[cost].append(record)
    for cost in sorted(by_cost):
        group = by_cost[cost]
        if len(group) < 6:  # skip one-off units; tiers come in 6 / 15 / 20
            continue
        print(f"\n--- cost {cost}  ({len(group)} towers) ---")
        print(f"  {'name':<26}{'dmg':>8}{'range':>7}{'cd':>7}{'dps':>9}")
        for record in group:
            cooldown = record.get("cooldown") or 0.0
            dmg = data.damage(record)
            dps = dmg / cooldown if cooldown else 0.0
            print(f"  {data.name(record):<26}{dmg:>8}{record.get('range', '-'):>7}"
                  f"{cooldown:>7.2f}{dps:>9.0f}")


def cmd_recipes(data: MapData, _args) -> None:
    """Print the ``( X + Y )`` recipe every combined tower states in its tooltip."""
    seen = set()
    for record in data.units:
        if "name" not in record:
            continue
        blob = _strip_color(data.text(record.get("tip_extended", "")) + " "
                            + data.text(record.get("tip", "")))
        match = re.search(r"\(\s*([A-Za-z]+)\s*\+\s*([A-Za-z]+)\s*(?:\+\s*([A-Za-z]+)\s*)?\)", blob)
        if not match:
            continue
        parts = [p for p in match.groups() if p]
        name = data.name(record)
        key = (name, tuple(parts))
        if key in seen:
            continue
        seen.add(key)
        role = blob[match.end():].strip()
        print(f"  {' + '.join(parts):<28} {name:<24} {role[:70]}")


def cmd_waves(data: MapData, _args) -> None:
    """Print the wave table: level -> creep unit, its hit points and speed.

    The map does not scale hit points at spawn time -- ``udg_HP_exponent_base``
    is set to 1.23 and then never read. Instead every level has its own unit
    type, and ``udg_Spawns[level]`` names it, so the real difficulty curve is
    the hit points baked into those units. ``udg_Level_Class_Data`` lists which
    levels carry each of the ten creep classes; those are the archetypes.
    """
    script = data.archive.read("war3map.j").decode("utf-8", "replace")
    spawns: dict[int, str] = {}
    for match in re.finditer(r"set udg_Spawns\[(\d+)\]\s*=\s*'(\w{4})'", script):
        spawns[int(match.group(1))] = match.group(2)
    classes: dict[int, list[str]] = defaultdict(list)
    names = re.findall(r'set udg_Level_Class\[(\d+)\]\s*=\s*"([^"]*)"', script)
    class_names = {int(i): n for i, n in names}
    for index, raw in re.findall(r'set udg_Level_Class_Data\[(\d+)\]\s*=\s*"([^"]*)"', script):
        label = class_names.get(int(index), index)
        for level in re.findall(r"\d+", raw):
            classes[int(level)].append(label)

    by_id = {record["new"]: record for record in data.units if "new" in record}
    bounty_base = 1.10
    match = re.search(r"set udg_Bounty_Base\s*=\s*([\d.]+)", script)
    if match:
        bounty_base = float(match.group(1))

    print(f"  bounty per kill = max(level/3, {bounty_base}^(level-1) * (1 + 0.33*money_tower_level))")
    print(f"  {'lvl':>4}  {'creep':<24}{'hp':>9}{'speed':>7}  classes")
    for level in sorted(spawns):
        record = by_id.get(spawns[level], {})
        label = data.name(record) if record else f"<{spawns[level]}>"
        # udg_Spawns is 0-based; the levels in Level_Class_Data are 1-based.
        tags = ",".join(classes.get(level + 1, []))
        print(f"  {level + 1:>4}  {label:<24}{record.get('hp', '-'):>9}"
              f"{record.get('speed', '-'):>7}  {tags}")


def cmd_creeps(data: MapData, _args) -> None:
    """Units with hit points and a bounty but no attack are the wave creeps."""
    print(f"  {'name':<26}{'hp':>8}{'speed':>7}{'bounty':>8}")
    for record in data.units:
        if "hp" not in record or "name" not in record:
            continue
        bounty = record.get("bounty_base")
        if bounty is None:
            continue
        dice = record.get("bounty_dice", 0) or 0
        sides = record.get("bounty_sides", 0) or 0
        total = int(bounty + dice * (1 + sides) / 2)
        print(f"  {data.name(record):<26}{record.get('hp', '-'):>8}"
              f"{record.get('speed', '-'):>7}{total:>8}")


def cmd_pathing(data: MapData, _args) -> None:
    """Print the shape of ONE arena, read out of ``war3map.wpm``.

    The port's board is a scaled-down copy of this shape, so it has to be
    measured rather than remembered. ``war3map.wpm`` is the pathing map: a
    ``MP3W`` header (version, width, height) followed by one flag byte per
    32x32-unit cell. Only two bits matter here -- ``0x02`` unwalkable and
    ``0x08`` unbuildable. Walkable-and-unbuildable is the creep lane;
    walkable-and-buildable is the ground the player fills with towers.

    Element TD stores eight identical player arenas side by side in one map, so
    the walkable cells fall into eight equal connected components and any one of
    them is the board. The coverage table repeats what the game's own
    ``--dump-board`` harness prints for our board (see ``scripts/main.gd``): the
    share of the lane one tower watches from the best spot on the ground, at the
    ranges the ported towers actually carry.
    """
    CELL = 32  # world units per pathing cell
    UNWALKABLE, UNBUILDABLE = 0x02, 0x08
    buf = data.archive.read("war3map.wpm")
    magic, version, width, height = struct.unpack_from("<4siii", buf, 0)
    if magic != b"MP3W":
        print(f"error: war3map.wpm has magic {magic!r}, not MP3W", file=sys.stderr)
        return
    flags = buf[16:16 + width * height]
    print(f"  pathing map      : {magic.decode()} v{version}, {width}x{height} cells "
          f"of {CELL} units = {width * CELL}x{height * CELL} units")

    walkable = [[not flags[y * width + x] & UNWALKABLE for x in range(width)]
                for y in range(height)]
    buildable = [[not flags[y * width + x] & UNBUILDABLE for x in range(width)]
                 for y in range(height)]

    # Flood fill: one component per arena.
    seen = [[False] * width for _ in range(height)]
    components: list[list[tuple[int, int]]] = []
    for sy in range(height):
        for sx in range(width):
            if not walkable[sy][sx] or seen[sy][sx]:
                continue
            queue = [(sx, sy)]
            seen[sy][sx] = True
            cells = []
            while queue:
                x, y = queue.pop()
                cells.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if (0 <= nx < width and 0 <= ny < height
                            and walkable[ny][nx] and not seen[ny][nx]):
                        seen[ny][nx] = True
                        queue.append((nx, ny))
            components.append(cells)
    components.sort(key=len, reverse=True)
    biggest = len(components[0])
    arenas = sum(1 for c in components if len(c) == biggest)
    print(f"  walkable regions : {len(components)}, "
          f"{arenas} of them the full {biggest} cells (the player arenas)")

    arena = components[0]
    x0 = min(x for x, _ in arena)
    x1 = max(x for x, _ in arena)
    y0 = min(y for _, y in arena)
    y1 = max(y for _, y in arena)
    lane = [(x, y) for x, y in arena if not buildable[y][x]]
    ground = [(x, y) for x, y in arena if buildable[y][x]]
    print(f"  one arena        : {x1 - x0 + 1}x{y1 - y0 + 1} cells = "
          f"{(x1 - x0 + 1) * CELL}x{(y1 - y0 + 1) * CELL} units")
    print(f"  of it            : {len(lane)} cells of lane, {len(ground)} buildable "
          f"({100.0 * len(lane) / len(arena):.0f}% lane)")

    # '#' lane, '+' buildable ground, ' ' wall. Two cells per character across, four
    # down, which keeps a 3776-unit-tall arena inside a terminal without losing the shape.
    print("  shape (# lane, + buildable ground):")
    for y in range(y0, y1 + 1, 4):
        row = []
        for x in range(x0, x1 + 1, 2):
            block = [(xx, yy) for yy in range(y, min(y + 4, y1 + 1))
                     for xx in range(x, min(x + 2, x1 + 1))]
            hashes = sum(1 for xx, yy in block if walkable[yy][xx] and not buildable[yy][xx])
            plus = sum(1 for xx, yy in block if walkable[yy][xx] and buildable[yy][xx])
            row.append("#" if hashes >= plus and hashes else ("+" if plus else " "))
        print("    " + "".join(row))

    # Sample both sets every other cell: 64 units of grain against ranges of 500 up.
    samples = [(x, y) for x, y in lane if x % 2 == 0 and y % 2 == 0]
    spots = [(x, y) for x, y in ground if x % 2 == 0 and y % 2 == 0]
    print(f"  coverage from one tower ({len(spots)} spots against {len(samples)} lane samples):")
    print(f"    {'range':>7}  {'best 1':>7}{'median':>8}   towers with it")
    for reach, who in ((500, "Fire"), (750, "Water / Nature / Earth"), (2000, "Light / Darkness")):
        radius_sq = (reach / CELL) ** 2
        counts = sorted(
            sum(1 for sx, sy in samples if (sx - bx) ** 2 + (sy - by) ** 2 <= radius_sq)
            for bx, by in spots)
        print(f"    {reach:>7}  {100.0 * counts[-1] / len(samples):>6.0f}%"
              f"{100.0 * counts[len(counts) // 2] / len(samples):>7.0f}%   {who}")


COMMANDS = {
    "files": cmd_files,
    "cat": cmd_cat,
    "pathing": cmd_pathing,
    "towers": cmd_towers,
    "recipes": cmd_recipes,
    "creeps": cmd_creeps,
    "waves": cmd_waves,
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("map", help="path to a .w3x / .w3m file")
    parser.add_argument("command", choices=sorted(COMMANDS))
    parser.add_argument("name", nargs="?", help="file name, for `cat`")
    args = parser.parse_args()

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    try:
        data = MapData(args.map)
    except (OSError, ArchiveError) as err:
        print(f"error: {err}", file=sys.stderr)
        return 1
    if args.command == "cat" and not args.name:
        print("error: `cat` needs a file name", file=sys.stderr)
        return 1
    COMMANDS[args.command](data, args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
