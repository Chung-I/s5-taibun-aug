import zhon.hanzi
import sys
import regex

for line in sys.stdin.readlines():
    if regex.match(f"[{zhon.hanzi.characters}]+\n", line):
        sys.stdout.write(line)

