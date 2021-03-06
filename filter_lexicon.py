from tsm.lexicon import Lexicon
from tsm.util import read_file_to_lines
import sys

lexicon = Lexicon.from_kaldi(sys.argv[1], with_prob=True)

words = [line.split()[0] for line in read_file_to_lines(sys.argv[2])]

keys = list(lexicon.keys())
for word in words:
    if word not in keys:
        print(word)

#lexicon.write(sys.argv[3])
