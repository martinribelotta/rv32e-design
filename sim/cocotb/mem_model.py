"""
Simple word-addressed memory model with byte-enable writes.
Loads Intel HEX / plain hex (one word per line) files.
"""

class MemModel:
    def __init__(self, depth=1024):
        self.depth = depth
        self.mem = [0] * depth

    def load_hex(self, path):
        """Load plain hex file (one 32-bit word per line, as produced by elf2hex.py)."""
        with open(path) as f:
            for i, line in enumerate(f):
                line = line.strip()
                if not line or line.startswith("@"):
                    continue
                if i >= self.depth:
                    break
                self.mem[i] = int(line, 16) & 0xFFFFFFFF

    def read(self, word_addr):
        if 0 <= word_addr < self.depth:
            return self.mem[word_addr]
        return 0

    def write(self, word_addr, data, be):
        """Write with 4-bit byte enable (be bit 0 = byte 0 = bits [7:0])."""
        if not (0 <= word_addr < self.depth):
            return
        old = self.mem[word_addr]
        for b in range(4):
            if be & (1 << b):
                shift = b * 8
                old = (old & ~(0xFF << shift)) | ((data >> shift & 0xFF) << shift)
        self.mem[word_addr] = old
