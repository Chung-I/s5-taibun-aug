import sys
from collections import OrderedDict
src_lines = sys.stdin.readlines()

vocab = OrderedDict()

for src_line in src_lines:
    vocab[src_line] = 1

for key in vocab:
    sys.stdout.write(key)
