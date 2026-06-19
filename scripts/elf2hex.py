#!/usr/bin/env python3
"""Convert ELF to $readmemh-compatible .hex (word-addressed, 32-bit)."""
import sys, struct

def elf2hex(elf_path, hex_path, base_addr, size_words, fill_word=0x0000006F):
    with open(elf_path, 'rb') as f:
        data = f.read()

    # Parse ELF header (little-endian 32-bit)
    assert data[0:4] == b'\x7fELF'
    e_phoff  = struct.unpack_from('<I', data, 28)[0]
    e_phnum  = struct.unpack_from('<H', data, 44)[0]
    e_phentsize = struct.unpack_from('<H', data, 42)[0]

    # Fill with jal x0,0 (0x0000006F) so unused IMEM tiles are non-zero
    # and icebram can distinguish IMEM from the all-zero DMEM/regfile tiles.
    fill = struct.pack('<I', fill_word) * size_words
    mem = bytearray(fill)

    # Place each segment by its LOAD address (p_paddr / LMA), not its run
    # address (p_vaddr). They are equal unless a section uses 'AT>' (e.g. .data,
    # whose init image is loaded into DROM but runs from DRAM).
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type   = struct.unpack_from('<I', data, off)[0]
        p_offset = struct.unpack_from('<I', data, off + 4)[0]
        p_paddr  = struct.unpack_from('<I', data, off + 12)[0]
        p_filesz = struct.unpack_from('<I', data, off + 16)[0]
        if p_type != 1:  # PT_LOAD
            continue
        if p_paddr < base_addr or p_paddr >= base_addr + len(mem):
            continue
        dst = p_paddr - base_addr
        seg = data[p_offset:p_offset + p_filesz]
        mem[dst:dst + len(seg)] = seg

    with open(hex_path, 'w') as f:
        for i in range(size_words):
            word = struct.unpack_from('<I', mem, i * 4)[0]
            f.write(f'{word:08x}\n')

if __name__ == '__main__':
    if len(sys.argv) not in (5, 6):
        print(f'Usage: {sys.argv[0]} <elf> <hex> <base_hex> <size_words> [fill_hex]')
        sys.exit(1)
    fill = int(sys.argv[5], 16) if len(sys.argv) == 6 else 0x0000006F
    elf2hex(sys.argv[1], sys.argv[2], int(sys.argv[3], 16), int(sys.argv[4]), fill)
