import argparse
from pathlib import Path
from typing import List, Tuple, Dict
from collections import defaultdict
import tqdm
import shutil

def parse_utt_id_to_reco_id_start_end(utt_id):
    reco_id, start, end = utt_id.split("-")
    return reco_id, float(start)/100, float(end)/100

def merge_consecutive_segments(utts):
    new_utts = defaultdict(list)
    for reco_id, reco_utts in utts.items():
        start, end, text = reco_utts[0]
        texts = [text]
        for idx, utt in tqdm.tqdm(enumerate(reco_utts[1:])):
            cur_start, cur_end, cur_text = utt
            assert cur_start < cur_end
            if cur_start <= end:
                end = cur_end
                texts.append(cur_text)
            if cur_start > end or idx == len(utts) - 2:
                new_utts[reco_id].append((start, end, " ".join(texts)))
                end = cur_end
                start = cur_start
                texts = [cur_text]
    return new_utts

ts2str = lambda timestamp: f"{(int(timestamp*100)):06}"

def write_text(utts, text_file):
    with open(text_file, 'w') as fp:
        for reco_id, reco_utts in utts.items():
            for start, end, text in reco_utts:
                utt_id = f"{reco_id}-{ts2str(start)}-{ts2str(end)}"
                fp.write(f"{utt_id} {text}\n")

def write_segment(utts, segment_file):
    with open(segment_file, 'w') as fp:
        for reco_id, reco_utts in utts.items():
            for start, end, text in reco_utts:
                utt_id = f"{reco_id}-{ts2str(start)}-{ts2str(end)}"
                fp.write(f"{utt_id} {reco_id} {start} {end}\n")

def write_utt2spk(utts, utt2spk_file):
    with open(utt2spk_file, 'w') as fp:
        for reco_id, reco_utts in utts.items():
            for start, end, text in reco_utts:
                utt_id = f"{reco_id}-{ts2str(start)}-{ts2str(end)}"
                fp.write(f"{utt_id} {utt_id}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("src_dir")
    parser.add_argument("dest_dir")
    args = parser.parse_args()

    utts = defaultdict(list) # reco_id -> (start, end, text)

    src_dir = Path(args.src_dir)
    dest_dir = Path(args.dest_dir)
    dest_dir.mkdir(exist_ok=True)

    with open(src_dir.joinpath("text")) as fp:
        text_lines = fp.read().splitlines()
        for line in text_lines:
            utt_id, text = line.split(" ", 1)
            reco_id, start, end = parse_utt_id_to_reco_id_start_end(utt_id)
            text = text.strip()
            utts[reco_id].append((start, end, text))
        new_utts = merge_consecutive_segments(utts)

    write_segment(new_utts, dest_dir.joinpath("segments"))
    write_text(new_utts, dest_dir.joinpath("text"))
    write_utt2spk(new_utts, dest_dir.joinpath("utt2spk"))
    shutil.copy(src_dir.joinpath("wav.scp"), dest_dir.joinpath("wav.scp"))
