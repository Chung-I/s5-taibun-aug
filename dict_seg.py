from typing import NamedTuple, List, Union
import regex as re
import json
from collections.abc import Iterable
from itertools import product, chain, zip_longest
from functools import partial, reduce
from operator import add
import time
import logging
import tqdm
import numpy as np
import zhon.hanzi
import unicodedata

from tsm.util import read_file_to_lines, dict_seg, flatten, write_lines_to_file
from tsm.util import get_all_possible_translations
from tsm.sentence import Sentence
from tsm.lexicon import Lexicon, LexiconEntry

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
logger.info('message')

def get_oovs(lines, lexicon):
    hanzis = re.compile(f"[{zhon.hanzi.characters}]+")
    oovs = set()
    for line in lines:
        line = line.lower()
        line = unicodedata.normalize("NFKC", line)
        segments = Sentence.parse_mixed_text(line)
        _oovs = filter(lambda segment: not (hanzis.match(segment) or segment in lexicon), segments)
        oovs.update(_oovs)
    return oovs

#def cut_line_factory(lexicon):
#    hanzis = re.compile(f"[{zhon.hanzi.characters}]+")
#    hanzi_others = re.compile(f"[{zhon.hanzi.characters}]+|[^{zhon.hanzi.characters}]+")
#    non_hanzi_oovs = []
#    def cut(line):
#        dest_words = []
#        line = line.lower()
#        line = unicodedata.normalize("NFKC", line)
#        segments = Sentence.parse_mixed_text(line)
#        non_hanzi_oovs = 
#        for segment in segments:
#            #src_clause = "".join(Sentence.from_line(src_clause, remove_punct=True, form=args.form))
#            if not hanzis.match(segment) and segment not in lexicon: # don't split non-hanzi oov
#                maybe_words = [segment]
#            else:
#                maybe_words = dict_seg(segment, dict_lexicon)
#            dest_words += maybe_words[0]
#        dest_sent = " ".join(dest_words)
#        return dest_sent
#    return cut

CANNOTSEG = "unsegmentable"

def grouper(iterable, n, fillvalue=None):
    "Collect data into fixed-length chunks or blocks"
    # grouper('ABCDEFG', 3, 'x') --> ABC DEF Gxx"
    args = [iter(iterable)] * n
    return zip_longest(*args, fillvalue=fillvalue)

def batched_inferencer(func, samples, batch_size=64):
    
    with tqdm.tqdm(total=len(samples)) as pbar:
        for batch in grouper(samples, batch_size):
            filtered_batch = list(filter(lambda f: f is not None, batch))
            pbar.update(len(filtered_batch))
            for out_sample in func(filtered_batch):
                yield " ".join(out_sample)

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('dict_lexicon_path')
    parser.add_argument('src_path')
    parser.add_argument('dest_path')
    parser.add_argument('--oov-path')
    parser.add_argument('--with-prob', action='store_true')
    parser.add_argument('--ckip-path')# default='/home/nlpmaster/ssd-1t/weights/data')
    parser.add_argument('--batch-size', type=int, default=64)
    parser.add_argument('--recommend-dictionary', action='store_true')
    parser.add_argument('--form', choices=['char', 'word', 'sent'])
    parser.add_argument('--non-hanzi-in-lexicon', action='store_true')
    args = parser.parse_args()

    dict_lexicon = Lexicon.from_kaldi(args.dict_lexicon_path, args.with_prob)
    if not args.non_hanzi_in_lexicon:
        dict_lexicon = {word: prons for word, prons in dict_lexicon.items() if re.search(f"[{zhon.hanzi.characters}]", word)}
    lines = read_file_to_lines(args.src_path)
    oovs = get_oovs(lines, dict_lexicon)
    dict_lexicon.update({oov: None for oov in oovs})
    dest_sents = []
    if args.ckip_path:
        from tsm.ckip_wrapper import CKIPWordSegWrapper
        cutter = CKIPWordSegWrapper(args.ckip_path, dict_lexicon, not args.recommend_dictionary)
        preprocess = lambda line: Sentence.parse_mixed_text(line, remove_punct=True)
        dest_sents = batched_inferencer(cutter.cut_some, list(map(preprocess, lines)), args.batch_size)
    else:
        cut = cut_line_factory(dict_lexicon)
        dest_sents = map(cut, lines)
    write_lines_to_file(args.dest_path, dest_sents)
    if args.oov_path:
        write_lines_to_file(args.oov_path, oovs)
