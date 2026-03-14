#!/usr/bin/env python3
"""
Compile RISC-V source, enforce supported instruction whitelist, and emit imem.hex.

Pipeline:
  source (.c/.S/.s) -> ELF -> objdump check -> binary -> imem.hex
"""

from __future__ import annotations

import argparse
import pathlib
import re
import struct
import subprocess
import sys
from typing import Iterable


SUPPORTED_INSTR = {
    "add",
    "sub",
    "and",
    "or",
    "addi",
    "andi",
    "ori",
    "lw",
    "sw",
    "jal",
    "jalr",
    "beq",
    "lui",
}


def run_cmd(cmd: list[str], cwd: pathlib.Path | None = None) -> str:
    proc = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        msg = [
            f"Command failed ({proc.returncode}): {' '.join(cmd)}",
            proc.stdout.strip(),
            proc.stderr.strip(),
        ]
        raise RuntimeError("\n".join(x for x in msg if x))
    return proc.stdout


def parse_disasm_for_instr(disasm_text: str) -> list[tuple[str, str]]:
    """
    Returns list of (address_hex, mnemonic) from objdump output.
    """
    entries: list[tuple[str, str]] = []
    # Example line:
    #  00001000:  00a00093           addi    ra,zero,10
    line_re = re.compile(r"^\s*([0-9a-fA-F]+):\s+[0-9a-fA-F]+\s+([a-zA-Z0-9_.]+)\b")
    for line in disasm_text.splitlines():
        m = line_re.match(line)
        if not m:
            continue
        addr = m.group(1).lower()
        mnemonic = m.group(2).lower()
        entries.append((addr, mnemonic))
    return entries


def check_supported(entries: Iterable[tuple[str, str]]) -> list[tuple[str, str]]:
    bad: list[tuple[str, str]] = []
    for addr, mnemonic in entries:
        if mnemonic not in SUPPORTED_INSTR:
            bad.append((addr, mnemonic))
    return bad


def detect_binary_base_addr(objdump: str, elf_path: pathlib.Path) -> int:
    """
    Detect start address used by objcopy -O binary.
    We approximate it as the minimum VMA among sections that are:
    CONTENTS + ALLOC + LOAD and non-empty.
    """
    text = run_cmd([objdump, "-h", str(elf_path)])
    lines = text.splitlines()

    header_re = re.compile(
        r"^\s*\d+\s+([.\w]+)\s+([0-9a-fA-F]+)\s+([0-9a-fA-F]+)\s+([0-9a-fA-F]+)\s+([0-9a-fA-F]+)\s+2\*\*\d+"
    )
    candidates: list[int] = []

    i = 0
    while i < len(lines):
        m = header_re.match(lines[i])
        if not m:
            i += 1
            continue

        size = int(m.group(2), 16)
        vma = int(m.group(3), 16)
        flags_line = lines[i + 1] if i + 1 < len(lines) else ""
        if size > 0 and all(flag in flags_line for flag in ("CONTENTS", "ALLOC", "LOAD")):
            candidates.append(vma)
        i += 1

    if not candidates:
        raise RuntimeError("unable to auto-detect base address from ELF sections")
    return min(candidates)


def bin_to_hex(bin_path: pathlib.Path, hex_path: pathlib.Path, base_addr: int) -> None:
    if base_addr & 0x3:
        raise ValueError(f"base address must be word-aligned: 0x{base_addr:x}")

    data = bin_path.read_bytes()
    base_word = base_addr >> 2

    with hex_path.open("w", encoding="ascii") as out:
        if base_word != 0:
            out.write(f"@{base_word:x}\n")
        for i in range(0, len(data), 4):
            chunk = data[i : i + 4]
            if len(chunk) < 4:
                chunk = chunk + b"\x00" * (4 - len(chunk))
            word = struct.unpack("<I", chunk)[0]
            out.write(f"{word:08x}\n")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compile source, check supported instructions, generate imem.hex"
    )
    parser.add_argument("source", help="Input source (.c/.S/.s)")
    parser.add_argument(
        "--linker",
        default="utils/linker.ld",
        help="Linker script path (default: utils/linker.ld)",
    )
    parser.add_argument(
        "--prefix",
        default="riscv64-unknown-elf-",
        help="Toolchain prefix (default: riscv64-unknown-elf-)",
    )
    parser.add_argument("--march", default="rv32i", help="ISA string (default: rv32i)")
    parser.add_argument("--mabi", default="ilp32", help="ABI (default: ilp32)")
    parser.add_argument(
        "--base-addr",
        default="auto",
        help="Hex base address for imem.hex image (default: auto)",
    )
    parser.add_argument(
        "--out-hex",
        default="sim/tests/instructions_test/imem.hex",
        help="Output hex path (default: sim/tests/instructions_test/imem.hex)",
    )
    parser.add_argument(
        "--work-dir",
        default="sim/tests/instructions_test",
        help="Build artifact directory (default: sim/tests/instructions_test)",
    )
    parser.add_argument(
        "--keep-temp",
        action="store_true",
        help="Keep intermediate ELF/BIN/OBJDUMP files",
    )
    args = parser.parse_args()

    root = pathlib.Path.cwd()
    src = (root / args.source).resolve()
    linker = (root / args.linker).resolve()
    work_dir = (root / args.work_dir).resolve()
    out_hex = (root / args.out_hex).resolve()
    if not src.exists():
        raise FileNotFoundError(f"source not found: {src}")
    if not linker.exists():
        raise FileNotFoundError(f"linker script not found: {linker}")

    work_dir.mkdir(parents=True, exist_ok=True)
    out_hex.parent.mkdir(parents=True, exist_ok=True)

    stem = src.stem
    elf_path = work_dir / f"{stem}.elf"
    bin_path = work_dir / f"{stem}.bin"
    dump_path = work_dir / f"{stem}.dump"

    gcc = f"{args.prefix}gcc"
    objcopy = f"{args.prefix}objcopy"
    objdump = f"{args.prefix}objdump"

    common_flags = [
        "-O0",
        f"-march={args.march}",
        f"-mabi={args.mabi}",
        "-ffreestanding",
        "-fno-builtin",
        "-nostdlib",
        "-nostartfiles",
        "-T",
        str(linker),
        "-o",
        str(elf_path),
        str(src),
    ]
    run_cmd([gcc, *common_flags])

    disasm = run_cmd([objdump, "-d", "-M", "no-aliases", str(elf_path)])
    dump_path.write_text(disasm, encoding="utf-8")

    entries = parse_disasm_for_instr(disasm)
    bad = check_supported(entries)
    if bad:
        print("Unsupported instructions found:")
        for addr, instr in bad:
            print(f"  0x{addr}: {instr}")
        print("\nSupported instruction set:")
        print("  " + ", ".join(sorted(SUPPORTED_INSTR)))
        return 2

    if args.base_addr.lower() == "auto":
        base_addr = detect_binary_base_addr(objdump, elf_path)
    else:
        base_addr = int(args.base_addr, 0)

    run_cmd([objcopy, "-O", "binary", str(elf_path), str(bin_path)])
    bin_to_hex(bin_path, out_hex, base_addr)

    if not args.keep_temp:
        for p in (elf_path, bin_path, dump_path):
            p.unlink(missing_ok=True)

    print(f"OK: generated {out_hex} (base_addr=0x{base_addr:x})")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
