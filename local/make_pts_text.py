import argparse
from pathlib import Path

def parse_line(line):
    fields = line.split()
    start = float(fields[0])
    dur = float(fields[1])
    text = " ".join(fields[2:])
    end = round(start + dur, 2)
    return start, end, text

def make_reco_id(txtfile, add_parent_prefix=False):
    if add_parent_prefix:
        return f"{txtfile.parts[-2]}-{txtfile.stem}"
    else:
        return txtfile.stem

def make_utt_id(txtfile, start, end, add_parent_prefix=False):
    ts2str = lambda timestamp: f"{(int(timestamp*100)):06}"
    return f"{make_reco_id(txtfile, add_parent_prefix)}-{ts2str(start)}-{ts2str(end)}"

def main(args):
    segment_lines = []
    text_lines = []
    for txtfile in Path(args.src_dir).rglob("*.txt"):
        with open(txtfile) as fp:
            lines = fp.read().splitlines()
            for line in lines:
                start, end, text = parse_line(line)
                if not end > start:
                    continue
                reco_id = make_reco_id(txtfile, args.add_parent_prefix)
                utt_id = make_utt_id(txtfile, start, end, args.add_parent_prefix)
                segment_lines.append(f"{utt_id} {reco_id} {start:.2f} {end:.2f}")
                text_lines.append(f"{utt_id} {text}")

    with open(Path(args.dest_dir).joinpath("text"), 'w') as fp:
        for line in text_lines:
            fp.write(line + "\n")

    with open(Path(args.dest_dir).joinpath("segments"), 'w') as fp:
        for line in segment_lines:
            fp.write(line + "\n")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('src_dir')
    parser.add_argument('dest_dir')
    parser.add_argument('--add-parent-prefix', action='store_true')
    args = parser.parse_args()
    main(args)
