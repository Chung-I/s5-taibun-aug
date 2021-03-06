import sys

for line in sys.stdin.readlines():
    fields = line.split()
    sys.stdout.write(" ".join([fields[0].lower()] + fields[1:]) + '\n')
