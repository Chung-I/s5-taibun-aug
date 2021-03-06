import argparse
import subprocess
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument('--lms', nargs='+')
parser.add_argument('--out-lm')
parser.add_argument('--weights', nargs='+', type=float)
parser.add_argument('--order', type=int)
args = parser.parse_args()

assert len(args.weights) == len(args.lms)
assert np.allclose(sum(args.weights), 1.0)

command = f"ngram -lm {args.lms[0]} -order {args.order} -lambda {args.weights[0]} "
if len(args.lms) > 1:
    command += f"-mix-lm {args.lms[1]} "
if len(args.lms) > 2:
    for idx, (lm, wt) in enumerate(zip(args.lms[2:], args.weights[2:])):
        command += f"-mix-lm{idx+2} {lm} -mix-lambda{idx+2} {wt} "
command += f"-write-lm {args.out_lm}"
print(f"command: {command}")
process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
output, error = process.communicate()
