import argparse
import tqdm

def cut(lexicon, max_len, sent):
    l = len(sent)
    oov_penalty = 10
    min_cuts = [float('inf') for i in range(l+1)]
    backtraces = [None for i in range(l+1)]
    min_cuts[0] = 0
    if sent in lexicon:
        return sent
    for i in range(1, l+1):
        for j in range(max(i-max_len, 0), i):
            if sent[j:i] in lexicon:
                if min_cuts[j] + 1 < min_cuts[i]:
                    min_cuts[i] = min_cuts[j] + 1
                    backtraces[i] = j
            elif min_cuts[j] + (i-j)*oov_penalty < min_cuts[i]:
                min_cuts[i] = min_cuts[j] + (i-j)*oov_penalty
                backtraces[i] = j

    if backtraces[-1] is None:
        return []
    words = []
    end = l
    while end > 0:
        start = backtraces[end]
        words.append(sent[start:end])
        end = start

    return list(reversed(words))

def read_lexicon(lexicon_file):
    lexicon = {}
    with open(lexicon_file) as fp:
        for line in fp:
            fields = line.strip().split()
            word = fields[0]
            pron = " ".join(fields[2:])
            lexicon[word] = pron
    return lexicon

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("lexicon_file")
    parser.add_argument("input_file")
    parser.add_argument("output_file")
    args = parser.parse_args()

    lexicon = read_lexicon(args.lexicon_file)
    max_len = max(map(len, lexicon.keys()))
    fo = open(args.output_file, 'w')
    with open(args.input_file) as fi:
        for line in tqdm.tqdm(fi):
            line = line.strip()
            words = cut(lexicon, max_len, line)
            fo.write(" ".join(words) + "\n")
    fo.close()
