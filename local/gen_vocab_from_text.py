import argparse
from collections import Counter

parser = argparse.ArgumentParser()
parser.add_argument('text_file')
parser.add_argument('out_file')
args = parser.parse_args()

flatten = lambda l: [item for sublist in l for item in sublist]

with open(args.text_file) as fp:
    lines = fp.read().splitlines()

sents = [line.split()[1:] for line in lines]
words = flatten(sents)

counter = Counter(words)
vocab = [word for word, _ in counter.most_common()]

with open(args.out_file, 'w') as fp:
    for word in vocab:
        fp.write(f"{word}\n")

