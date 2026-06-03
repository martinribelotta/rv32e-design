#!/usr/bin/env python3
"""Convert ELF to $readmemh-compatible .hex (word-addressed, 32-bit)."""
import sys, struct

def elf2hex(elf_path, hex_path, base_addr, size_words):
    with open(elf_path, 'rb') as f:
        data = f.read()

    # Parse ELF header (little-endian 32-bit)
    assert data[0:4] == b'\x7fELF'
    e_phoff  = struct.unpack_from('<I', data, 28)[0]
    e_phnum  = struct.unpack_from('<H', data, 44)[0]
    e_phentsize = struct.unpack_from('<H', data, 42)[0]

    mem = bytearray(size_words * 4)

    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type   = struct.unpack_from('<I', data, off)[0]
        p_offset = struct.unpack_from('<I', data, off + 4)[0]
        p_vaddr  = struct.unpack_from('<I', data, off + 8)[0]
        p_filesz = struct.unpack_from('<I', data, off + 16)[0]
        if p_type != 1:  # PT_LOAD
            continue
        if p_vaddr < base_addr or p_vaddr >= base_addr + len(mem):
            continue
        dst = p_vaddr - base_addr
        seg = data[p_offset:p_offset + p_filesz]
        mem[dst:dst + len(seg)] = seg

    with open(hex_path, 'w') as f:
        for i in range(size_words):
            word = struct.unpack_from('<I', mem, i * 4)[0]
            f.write(f'{word:08x}\n')

if __name__ == '__main__':
    if len(sys.argv) != 5:
        print(f'Usage: {sys.argv[0]} <elf> <hex> <base_hex> <size_words>')
        sys.exit(1)
    elf2hex(sys.argv[1], sys.argv[2], int(sys.argv[3], 16), int(sys.argv[4]))
