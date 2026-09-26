#!/usr/bin/env python3
"""Build Operation C: Level Select and its BPS patch."""

from __future__ import annotations

import hashlib
import re
import shutil
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path


EXPECTED_SHA256 = "0b6670e44cc2edc6fbf32fc78f499e774cf0802019480f2bf7bdb836ee15c433"
OUTPUT_NAME = "Operation C (USA) [Level Select v1.0].gb"
BPS_NAME = "operation-c-level-select-v1.0.bps"


def global_checksum(rom: bytes | bytearray) -> int:
    return (sum(rom[:0x014E]) + sum(rom[0x0150:])) & 0xFFFF


def section_ranges(map_text: str) -> list[tuple[int, int]]:
    bank = None
    ranges: list[tuple[int, int]] = []
    for line in map_text.splitlines():
        match = re.match(r"ROM(?:0|X) bank #(\d+):", line)
        if match:
            bank = int(match.group(1))
            continue
        match = re.match(r'\s+SECTION: \$([0-9a-f]+)-\$([0-9a-f]+)', line)
        if not match or bank is None:
            continue
        start, end = (int(value, 16) for value in match.groups())
        file_start = start if bank == 0 else bank * 0x4000 + start - 0x4000
        ranges.append((file_start, file_start + end - start + 1))
    return ranges


def encode_bps_number(value: int) -> bytes:
    """Encode an unsigned integer using the BPS variable-length format."""
    encoded = bytearray()
    while True:
        byte = value & 0x7F
        value >>= 7
        if value == 0:
            encoded.append(byte | 0x80)
            return bytes(encoded)
        encoded.append(byte)
        value -= 1


def make_bps(before: bytes, after: bytes) -> bytes:
    """Create a deterministic BPS patch using SourceRead and TargetRead runs."""
    patch = bytearray(b"BPS1")
    patch += encode_bps_number(len(before))
    patch += encode_bps_number(len(after))
    patch += encode_bps_number(0)  # metadata size

    cursor = 0
    while cursor < len(after):
        source_read = cursor < len(before) and before[cursor] == after[cursor]
        start = cursor
        while cursor < len(after):
            matches = cursor < len(before) and before[cursor] == after[cursor]
            if matches != source_read:
                break
            cursor += 1
        length = cursor - start
        mode = 0 if source_read else 1
        patch += encode_bps_number(((length - 1) << 2) | mode)
        if not source_read:
            patch += after[start:cursor]

    patch += zlib.crc32(before).to_bytes(4, "little")
    patch += zlib.crc32(after).to_bytes(4, "little")
    patch += zlib.crc32(patch).to_bytes(4, "little")
    return bytes(patch)


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {Path(sys.argv[0]).name} /path/to/'Operation C (USA).gb'", file=sys.stderr)
        return 2

    for command in ("rgbasm", "rgblink"):
        if shutil.which(command) is None:
            raise SystemExit(f"Missing required RGBDS command: {command}")

    source_rom = Path(sys.argv[1]).expanduser().resolve()
    original = source_rom.read_bytes()
    digest = hashlib.sha256(original).hexdigest()
    if digest != EXPECTED_SHA256:
        raise SystemExit(
            "Input ROM does not match the supported Operation C (USA) Rev. 0 dump.\n"
            f"Expected SHA-256: {EXPECTED_SHA256}\nActual SHA-256:   {digest}"
        )

    project = Path(__file__).resolve().parent
    with tempfile.TemporaryDirectory(prefix="operation-c-v1-") as temp_name:
        temp = Path(temp_name)
        obj = temp / "main.o"
        overlay = temp / "overlay.gb"
        map_file = temp / "main.map"
        subprocess.run(["rgbasm", "-o", obj, project / "src" / "main.asm"], check=True)
        subprocess.run(
            ["rgblink", "-p", "0xff", "-o", overlay, "-m", map_file, obj],
            check=True,
        )
        overlay_data = overlay.read_bytes()
        ranges = section_ranges(map_file.read_text())

    patched = bytearray(original)
    for start, end in ranges:
        patched[start:end] = overlay_data[start:end]

    checksum = global_checksum(patched)
    patched[0x014E] = checksum >> 8
    patched[0x014F] = checksum & 0xFF

    output_dir = project / "build"
    output_dir.mkdir(exist_ok=True)
    output_rom = output_dir / OUTPUT_NAME
    output_bps = output_dir / BPS_NAME
    output_rom.write_bytes(patched)
    output_bps.write_bytes(make_bps(original, patched))

    print(f"Built: {output_rom}")
    print(f"Built: {output_bps}")
    print(f"SHA-256: {hashlib.sha256(patched).hexdigest()}")
    print(f"Global checksum: 0x{checksum:04X}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
