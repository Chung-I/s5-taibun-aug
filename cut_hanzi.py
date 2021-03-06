from tsm.sentence import Sentence
import sys

for line in sys.stdin.readlines():
    words = Sentence.parse_mixed_text(line)
    sys.stdout.write(" ".join(words) + '\n')
