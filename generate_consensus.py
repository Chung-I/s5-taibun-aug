from pathlib import Path
import argparse
import editdistance
import numpy as np
import tqdm
from itertools import combinations, product
from collections import Counter
import matplotlib.pyplot as plt

def mutual_er(a, b):
    ed = editdistance.eval(a, b)
    if len(a) and len(b):
        mutual_er = np.sqrt( (ed / len(a)) * (ed / len(b)) )
    else:
        mutual_er = 1
    return mutual_er

def get_edit_distance(edit_distances, i, j):
    maybe_ed = edit_distances.get((i, j))
    if maybe_ed is not None:
        return maybe_ed
    else:
        return edit_distances.get((j, i)) 

def get_consensus(texts, diff_func):
    keys = list(texts.keys())
    edit_distances = {(i,j): diff_func(texts[i].split(), texts[j].split())
                      for i, j in combinations(keys, 2)}
    avg_edit_distances = [np.mean([get_edit_distance(edit_distances, i, j) for j in
                                   filter(lambda k: k != i, keys)])
                          for i in keys]
    min_idx = np.argmin(avg_edit_distances)
    return texts[keys[min_idx]], keys[min_idx]

def parse_text(path):
    with open(path) as fp:
        lines = fp.read().splitlines()
    utts = {}
    for line in lines:
        fields = line.split()
        utt_id = fields[0]
        text = " ".join(fields[1:])
        utts[utt_id] = text
    return utts

parser = argparse.ArgumentParser()
parser.add_argument('dir')
parser.add_argument('output_path')
parser.add_argument('--lmwts', type=int, nargs='+', default=[7,8,9,10,11,12,13,14,15,16,17])
parser.add_argument('--wips', type=float, nargs='+', default=[0.0, 0.5, 1.0])
parser.add_argument('--suffix', default=".")
parser.add_argument('--diff-type', choices=['mutual_er', 'edit_distance'], default='mutual_er')

args = parser.parse_args()

file_paths = {(lmwt, wip): Path(args.dir).joinpath(f"penalty_{wip}").joinpath(f"{lmwt}{args.suffix}txt")
              for lmwt, wip in product(args.lmwts, args.wips)}

hyps = {key: parse_text(path) for key, path in file_paths.items()}

assert len(set(map(len, hyps.values()))) == 1

consensus = {}

if args.diff_type == "mutual_er":
    diff_func = mutual_er
    print("use mutual_er")
elif args.diff_type == "edit_distance":
    diff_func = editdistance.eval
    print("use edit_distance")
else:
    raise NotImplementedError

lmwt_stats = []
wip_stats = []

for utt_id in tqdm.tqdm(list(list(hyps.values())[0].keys())):
    texts = {key: hyp[utt_id] for key, hyp in hyps.items()}
    text, min_key = get_consensus(texts, diff_func)
    lmwt_stats.append(min_key[0])
    wip_stats.append(min_key[1])
    consensus[utt_id] = text

lmwt_stats_counter = Counter(lmwt_stats)
wip_stats_counter = Counter(wip_stats)

fig, ax = plt.subplots()
ax.bar(lmwt_stats_counter.keys(), lmwt_stats_counter.values())
fig.savefig(args.output_path + ".pdf")

with open(args.output_path, 'w') as fp:
    for utt_id, text in consensus.items():
        fp.write(f"{utt_id} {text}\n")
