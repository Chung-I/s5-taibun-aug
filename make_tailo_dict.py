from pathlib import Path
from tsm.POJ_TL import poj_tl
from tsm.symbols import all_toneless_syls, all_syls
from tsm.util import flatten, process_pron, maybe_add_tone
import regex as re
import json
import unicodedata

def get_all_json_files(root_dir):
    yield from Path(root_dir).rglob("*.json")

def jsonfile2sentence(jsonfile):
    with open(jsonfile) as fp:
        utt = json.load(fp)
    return utt['台羅']

def is_alphabet(word):
    return re.sub("[^a-z]+", "", word)

def sent2syls(sent):
    return filter(lambda word: is_alphabet(word), re.split("[\p{P}-\s]+", sent.lower()))

def tlt_to_tls(tlt):
    tlt = unicodedata.normalize("NFKC", tlt)
    tlt = re.sub("ı", "i", tlt) # replace the dotless i to normal i
    tls = poj_tl(tlt).tlt_tls().pojs_tls()
    if tls in all_toneless_syls or tls in all_syls:
        tls = maybe_add_tone(tls)
        return tls
    else:
        print(tls)
        return None

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('src_dir')
    parser.add_argument('dest_path')
    args = parser.parse_args()
    tlt_tls_map = {}
    jsonfiles = get_all_json_files(args.src_dir)
    sent_of_syls = map(sent2syls, map(jsonfile2sentence, jsonfiles))
    all_tlt_syls = set(flatten(sent_of_syls))
    tlt_tls_map = {tlt: tlt_to_tls(tlt) for tlt in all_tlt_syls}
    
    with open(args.dest_path, 'w') as fp:
        for tlt, tls in tlt_tls_map.items():
            if tls is not None:
                fp.write(f"{tlt} 1.0 {tls}\n")
