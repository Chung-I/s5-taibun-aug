import json
import os
import argparse
from pathlib import Path
from tsm.sentence import Sentence
import regex as re
import zhon.hanzi

parser = argparse.ArgumentParser()
parser.add_argument('text_dir')
parser.add_argument('--field', default='漢羅台文')
parser.add_argument('--corpus-prefix')
parser.add_argument('--test-set', action='store_true')
args = parser.parse_args()

text=open('text','w')
corpus_prefix = "" if not args.corpus_prefix else f"{args.corpus_prefix}-"

for jsonfile in Path(args.text_dir).rglob("*.json"):
    if args.test_set:
        utt_id = jsonfile.stem
    else:
        spk = jsonfile.parent.name
        utt_suffix=jsonfile.name.replace('.json','-04')
        utt_id=f"{spk}_{utt_suffix}"
    utt_id=f"{corpus_prefix}{utt_id}"
    with open(jsonfile, 'r', encoding='utf-8') as f:
        output = json.load(f)
        sent = output[args.field]
        #sent = re.sub("\-", "", sent)
        #sent = re.split(f"([{zhon.hanzi.characters}\-])", sent)
        words = Sentence.parse_mixed_text(sent, remove_punct=True)
        sent = " ".join(words)
        text.write(utt_id)
        text.write(' ')
        text.write(sent)
        text.write('\n')

text.close()


