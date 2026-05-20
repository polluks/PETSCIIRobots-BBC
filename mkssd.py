#!/usr/bin/env python3
"""Create 40-track Acorn DFS SSD or UEF tape image from a raw binary."""

import struct

NUM_TRACKS = 40
SECTORS_PER_TRACK = 10
SECTOR_SIZE = 256
NUM_SECTORS = NUM_TRACKS * SECTORS_PER_TRACK


def make_ssd(bin_path, ssd_path, name=b"PETSCII", load_addr=0x0E00,
             exec_addr=0x0E00, boot=2):
    with open(bin_path, "rb") as f:
        data = f.read()

    num_sec = (len(data) + SECTOR_SIZE - 1) // SECTOR_SIZE
    start_sec = 2

    disk = bytearray(NUM_SECTORS * SECTOR_SIZE)

    # Sector 0: first 8 chars of disc title
    title8 = name.ljust(8, b' ')[:8]
    disk[0:8] = title8

    # File entry in sector 0: filename (7 bytes) + directory byte
    fn = b"ROBOTS"
    disk[8:15] = fn.ljust(7, b' ')
    disk[15] = ord('$')

    # Sector 1
    s1 = 256

    # Bytes 0-3: last 4 chars of disc title
    title4 = name.ljust(12, b' ')[8:12]
    disk[s1:s1+4] = title4

    disk[s1+4] = 0x00                 # cycle number
    disk[s1+5] = 8                     # file offset (8 x 1 file)

    disc_hi = (NUM_SECTORS >> 8) & 3
    disc_lo = NUM_SECTORS & 0xFF
    disk[s1+6] = disc_hi | (boot << 4)
    disk[s1+7] = disc_lo

    # Pack 18-bit addresses
    def pack_18(val):
        return val & 0xFF, (val >> 8) & 0xFF, (val >> 16) & 3

    load_lo, load_mid, load_hi = pack_18(load_addr)
    exec_lo, exec_mid, exec_hi = pack_18(exec_addr)
    len_lo, len_mid, len_hi = pack_18(len(data))
    start_lo, start_hi = start_sec & 0xFF, (start_sec >> 8) & 3

    byte14 = (start_hi << 0) | (load_hi << 2) | (len_hi << 4) | (exec_hi << 6)

    disk[s1+8] = load_lo
    disk[s1+9] = load_mid
    disk[s1+10] = exec_lo
    disk[s1+11] = exec_mid
    disk[s1+12] = len_lo
    disk[s1+13] = len_mid
    disk[s1+14] = byte14
    disk[s1+15] = start_lo

    # File data starting at sector 2
    offset = start_sec * SECTOR_SIZE
    disk[offset:offset + len(data)] = data

    with open(ssd_path, "wb") as f:
        f.write(disk)

    print(f"Created {ssd_path}: {len(disk)} bytes")
    print(f"  File: {fn.decode()} ({len(data)} bytes, "
          f"{num_sec} sectors at sector {start_sec})")
    print(f"  Load: ${load_addr:04X}  Exec: ${exec_addr:04X}  Boot: {boot}")


def make_uef(bin_path, uef_path, load_addr=0x0E00, exec_addr=0x0E00,
             name=b"ROBOTS"):
    with open(bin_path, "rb") as f:
        data = f.read()

    chunks = bytearray()

    # Chunk $0000: Title
    title = b"PETSCII ROBOTS - ELECTRON"
    chunks += struct.pack("<II", 0x0000, len(title)) + title

    # Chunk $0100: Start of tape
    chunks += struct.pack("<II", 0x0100, 0)

    # Build header block
    fn = name.ljust(12, b' ')[:12]
    header = bytearray([0x00])
    header += fn
    header += struct.pack("<II", load_addr, exec_addr)
    header += struct.pack("<I", len(data))
    checksum = 0
    for b in header:
        checksum ^= b
    header.append(checksum)

    # Build data block
    dblock = bytearray([0xFF])
    dblock += data
    checksum = 0
    for b in dblock:
        checksum ^= b
    dblock.append(checksum)

    # Gap before header (50 cs)
    chunks += struct.pack("<II", 0x0110, 2)
    chunks += struct.pack("<H", 50)

    # Header data block
    chunks += struct.pack("<II", 0x0102, len(header)) + header

    # Gap before data (50 cs)
    chunks += struct.pack("<II", 0x0110, 2)
    chunks += struct.pack("<H", 50)

    # Data block
    chunks += struct.pack("<II", 0x0102, len(dblock)) + dblock

    with open(uef_path, "wb") as f:
        f.write(chunks)

    print(f"Created {uef_path}: {len(chunks)} bytes")
    print(f"  File: {name.decode().strip()} ({len(data)} bytes)")
    print(f"  Load: ${load_addr:04X}  Exec: ${exec_addr:04X}")


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print("Usage: mkssd.py <binary> <output> [load_addr] [exec_addr] [boot] [--uef]")
        sys.exit(1)

    kwargs = {"bin_path": sys.argv[1]}
    out_path = sys.argv[2]

    uef = "--uef" in sys.argv
    args = [a for a in sys.argv[3:] if a != "--uef"]

    if len(args) > 0:
        kwargs["load_addr"] = int(args[0], 16)
    if len(args) > 1:
        kwargs["exec_addr"] = int(args[1], 16)
    if len(args) > 2:
        kwargs["boot"] = int(args[2])

    if uef:
        make_uef(**kwargs, uef_path=out_path)
    else:
        make_ssd(**kwargs, ssd_path=out_path)
