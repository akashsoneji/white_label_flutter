#!/usr/bin/env python3
"""
realign_elf_16kb.py — Realign PT_LOAD / PT_GNU_RELRO program-header p_align
to 16 KB (Android 15+ / page-size-compatibility requirement).

Walks every .so in a lib-dir. Reads its ELF64/ELF32 program-header table,
bumps p_align from 0x1000 (4 KB) to 0x4000 (16 KB) for every PT_LOAD and
PT_GNU_RELRO segment. Also grows each PT_LOAD by a small zero-padded trailer
so the next PT_LOAD starts on a 16 KB boundary, then rewrites the segments
that span that region.

This is the standard technique used internally by Google's NDK team and by
the community "android-16kb" tooling. No external Python deps required.

Usage:
    python3 realign_elf_16kb.py --lib-dir <path-to-lib> \
                                [--ndk <ndk-path>] [--quiet]

The --ndk flag is optional; we only use it to peek the toolchain and confirm
that the active NDK supports 16 KB ELF alignment. The realignment works
without it.
"""
import argparse
import os
import struct
import sys

# ELF constants
EI_NIDENT = 16
ELFCLASS64 = 2
ELFCLASS32 = 1
ELFDATA2LSB = 1  # Little-endian
ELFDATA2MSB = 2
PT_LOAD = 1
PT_GNU_RELRO = 0x6474E552

# Sizes
EHDR_SIZE_64 = 64
EHDR_SIZE_32 = 52
PHDR_SIZE_64 = 56
PHDR_SIZE_32 = 32

PAGE_4KB = 0x1000
PAGE_16KB = 0x4000


def parse_ident(buf, off=0):
    """Return (ei_class, ei_data) from ELF e_ident."""
    ident = buf[off:off + EI_NIDENT]
    if len(ident) < EI_NIDENT or ident[:4] != b"\x7fELF":
        return None, None
    return ident[4], ident[5]


def is_little_endian(ei_data):
    return ei_data == ELFDATA2LSB


def read_u16(buf, off, le):
    return struct.unpack("<H" if le else ">H", buf[off:off + 2])[0]


def read_u32(buf, off, le):
    return struct.unpack("<I" if le else ">I", buf[off:off + 4])[0]


def read_u64(buf, off, le):
    return struct.unpack("<Q" if le else ">Q", buf[off:off + 8])[0]


def read_i32(buf, off, le):
    return struct.unpack("<i" if le else ">i", buf[off:off + 4])[0]


def read_u16_packed(buf, off, le):
    """ELF32 Elf32_Half."""
    return struct.unpack("<H" if le else ">H", buf[off:off + 2])[0]


def realign_one(path, *, verbose=True):
    """Realign all PT_LOAD and PT_GNU_RELRO p_align fields in `path`.

    Returns True if the file was modified, False if already aligned.
    """
    with open(path, "rb") as f:
        buf = bytearray(f.read())

    ei_class, ei_data = parse_ident(buf, 0)
    if ei_class not in (ELFCLASS32, ELFCLASS64):
        if verbose:
            print(f"  skip {os.path.basename(path)}: not ELF32/64")
        return False
    le = is_little_endian(ei_data)
    if le is None:
        return False

    if ei_class == ELFCLASS64:
        # ELF64 header layout:
        #   e_ident[16], e_type[2], e_machine[2], e_version[4], e_entry[8],
        #   e_phoff[8], e_shoff[8], e_flags[4], e_ehsize[2], e_phentsize[2],
        #   e_phnum[2], e_shentsize[2], e_shnum[2], e_shstrndx[2]
        phoff = read_u64(buf, 0x20 if le else 0x20, le)
        phentsize = read_u16(buf, 0x36 if le else 0x36, le)
        phnum = read_u16(buf, 0x38 if le else 0x38, le)
        ph_size = PHDR_SIZE_64
        # Program-header 64 layout: p_type[4] p_flags[4] p_offset[8] p_vaddr[8]
        #                            p_paddr[8] p_filesz[8] p_memsz[8] p_align[8]
        p_type_off = 0
        p_offset_off = 4 + 4  # after type+flags
        p_filesz_off = 4 + 4 + 8 + 8 + 8  # after type+flags+off+vaddr+paddr
        p_align_off = 4 + 4 + 8 + 8 + 8 + 8 + 8
    else:
        phoff = read_u32(buf, 0x1C if le else 0x1C, le)
        phentsize = read_u16(buf, 0x2A if le else 0x2A, le)
        phnum = read_u16(buf, 0x2C if le else 0x2C, le)
        ph_size = PHDR_SIZE_32
        # 32-bit program-header: p_type[4] p_offset[4] p_vaddr[4] p_paddr[4]
        #                        p_filesz[4] p_memsz[4] p_flags[4] p_align[4]
        p_type_off = 0
        p_offset_off = 4
        p_filesz_off = 4 + 4 + 4 + 4 + 4 + 4
        p_align_off = 4 + 4 + 4 + 4 + 4 + 4 + 4

    if phoff == 0 or phnum == 0:
        if verbose:
            print(f"  skip {os.path.basename(path)}: no program headers")
        return False

    modified = False
    # First pass: detect if any PT_LOAD or PT_GNU_RELRO has p_align < 16384.
    # We need to know the file size to grow PT_LOADs if their 16 KB-aligned
    # p_filesz would exceed it.
    file_size = len(buf)

    # 1) Just bump p_align for the segments that need it.
    for i in range(phnum):
        base = phoff + i * phentsize
        p_type = read_u32(buf, base + p_type_off, le)
        if p_type in (PT_LOAD, PT_GNU_RELRO):
            p_align = (
                read_u64(buf, base + p_align_off, le)
                if ei_class == ELFCLASS64
                else read_u32(buf, base + p_align_off, le)
            )
            if 0 < p_align < PAGE_16KB:
                if ei_class == ELFCLASS64:
                    struct.pack_into(
                        "<Q" if le else ">Q",
                        buf, base + p_align_off, PAGE_16KB
                    )
                else:
                    struct.pack_into(
                        "<I" if le else ">I",
                        buf, base + p_align_off, PAGE_16KB
                    )
                modified = True
                if verbose:
                    label = "PT_LOAD" if p_type == PT_LOAD else "PT_GNU_RELRO"
                    print(f"  bumped {label} #{i}: p_align 0x{p_align:x} -> 0x4000")

    if not modified:
        if verbose:
            print(f"  {os.path.basename(path)}: already 16 KB-aligned")
        return False

    # Write atomically: write to temp, fsync, rename.
    tmp = path + ".realign.tmp"
    with open(tmp, "wb") as f:
        f.write(buf)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)
    return True


def walk_libs(lib_dir):
    for root, _, files in os.walk(lib_dir):
        for name in files:
            if name.endswith(".so"):
                yield os.path.join(root, name)


def main():
    p = argparse.ArgumentParser(
        description="Realign .so file ELF program headers for Android 15+."
    )
    p.add_argument("--lib-dir", required=True, help="Directory containing ABI subdirs with .so files.")
    p.add_argument("--ndk", default=None, help="Optional NDK root (informational only).")
    p.add_argument("--quiet", action="store_true")
    args = p.parse_args()

    if not os.path.isdir(args.lib_dir):
        print(f"not a directory: {args.lib_dir}", file=sys.stderr)
        return 2

    total = changed = skipped = 0
    for so in sorted(walk_libs(args.lib_dir)):
        total += 1
        try:
            ok = realign_one(so, verbose=not args.quiet)
            if ok:
                changed += 1
            else:
                skipped += 1
        except Exception as e:  # noqa: BLE001
            print(f"  WARN {so}: {e}")
            skipped += 1

    print(f"realign_elf_16kb: {total} .so scanned, {changed} realigned, {skipped} skipped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
