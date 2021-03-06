from typing import NamedTuple, List, Union
import re
import json
import math
from collections.abc import Iterable
from itertools import product
from functools import partial, reduce
from operator import add
import time
import logging
import tqdm
import numpy as np
import xmlrpc
import cn2an

from tsm.util import read_file_to_lines, dict_seg, flatten, write_lines_to_file
from tsm.util import get_all_possible_translations
from tsm.sentence import Sentence
from tsm.clients import MosesConfig, MosesClient, AllennlpClient, UnkTranslator
from tsm.lexicon import Lexicon, LexiconEntry

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
logger.info('message')

def dfs(tree):
    for el in tree:
        #if isinstance(el, Iterable) and not isinstance(el, (str, bytes)):
        if isinstance(el, list):
                yield from dfs(el)
        else:
            yield el

def maybe_process_unk_factory(translator):
    def maybe_process_unk(entry, is_unks, n_best=1):
        if not any(is_unks):
            return [entry]
        lattice = [translator.translate(char, n_best) if unk else [LexiconEntry(char, 0.0, syl)]
                   for unk, char, syl in zip(is_unks, entry.grapheme, entry.phonemes.split())]
        # dummy character for multiplying unk prob with original entry prob
        lattice.append([LexiconEntry("", entry.prob, "")])
        hyp_entries = sorted(map(lambda path: reduce(add, path), product(*lattice)), key=lambda e: -e.prob)[:n_best]
        return hyp_entries
    return maybe_process_unk
    

def hyp_to_line(src_text, hyp):
    text = " ".join(hyp['text'])
    return f"{src_text} {hyp['prob']} {text}"

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--word-seg-model-path', default="/home/nlpmaster/ssd-1t/weights/data")
    parser.add_argument('--with-prob', action='store_true')
    parser.add_argument('--n-best', type=int, default=3)
    parser.add_argument('--final-n-best', type=int, default=3)
    parser.add_argument('--min-prob', type=float, default=0.1)
    parser.add_argument('--ckip-path', default='/home/nlpmaster/ssd-1t/weights/data')
    parser.add_argument('prob_lexicon_path')
    parser.add_argument('dict_lexicon_path')
    parser.add_argument('moedict_path')
    parser.add_argument('src_path')
    parser.add_argument('dest_path')
    parser.add_argument('--oov-path')
    parser.add_argument('--mosesserver-port', default=8080)
    parser.add_argument('--recommend-dictionary', action='store_true')
    parser.add_argument('--model-types', nargs='+', default=['seq2seq', 'char'])
    parser.add_argument('--unk-consult-order', nargs='+', default=['prob', 'dict', 'bpmf', 'seq2seq'])
    parser.add_argument('--form', choices=['char', 'word', 'sent'])
    parser.add_argument('--pron-only', action='store_true')
    parser.add_argument('--has-utt-id', action='store_true')
    args = parser.parse_args()
    model_types = args.model_types

    prob_lexicon = Lexicon.from_kaldi(args.prob_lexicon_path, args.with_prob)
    dict_lexicon = Lexicon.from_kaldi(args.dict_lexicon_path, args.with_prob)
    taibun_lexicon = Lexicon.from_moedict(args.moedict_path)
    moses_config = MosesConfig(True, True, args.n_best)
    moses_client = MosesClient(port=args.mosesserver_port, config=moses_config)
    word_seg = None
    if "dict" in model_types:
        from tsm.ckip_wrapper import CKIPWordSegWrapper
        cutter = CKIPWordSegWrapper(args.ckip_path, dict_lexicon, not args.recommend_dictionary)

    seq2seq_translator = None
    if 'seq2seq' in model_types or 'seq2seq' in args.unk_consult_order:
        seq2seq_translator = AllennlpClient()
    unk_translator = UnkTranslator(prob_lexicon, dict_lexicon, taibun_lexicon, args.unk_consult_order, seq2seq_translator)
    maybe_process_unk = maybe_process_unk_factory(unk_translator)

    lines = read_file_to_lines(args.src_path)
    outf = open(args.dest_path, 'w')

    oovs = []
    for line in tqdm.tqdm(lines):
        utt_id = None
        if args.has_utt_id:
            fields = line.split()
            utt_id = fields[0]
            line = " ".join(fields[1:])
        src_sent = Sentence.parse_mixed_text(line, remove_punct=True)
        if not src_sent:
            logger.warning(f"src_sent {src_sent} empty; skipping")
            continue

        all_entries = []
        src_sent = [cn2an.transform(word, "an2cn") if word.isdigit() else word for word in src_sent ]
        if "dict" in model_types:
            maybe_sents = cutter.cut("".join(src_sent))
            n_best = math.ceil(min(args.n_best, math.exp(math.log(1000)/len(maybe_sents))))
            if n_best != args.n_best:
                logger.info(f"sequence length {len(maybe_sents)} too long; reduce n best to {n_best}")
            lattice = [unk_translator.translate(word, n_best) for word in maybe_sents]
            hyp_entries = sorted(map(lambda path: reduce(add, path), product(*lattice)), key=lambda e: -e.prob)[:args.n_best]
            all_entries += hyp_entries

        if "char" in model_types or "word" in model_types:
            if "word" in model_types:
                src_sent = word_seg.cut("".join(src_sent))
            try:
                tgt_hyps = moses_client.translate(src_sent)['nbest']
                entries, is_unks = zip(*[MosesClient.parse_hyp("".join(src_sent), hyp) for hyp in tgt_hyps])
                maybe_process_unk_nbest = partial(maybe_process_unk, n_best=max(args.n_best // len(entries), 1))
                no_unk_entries = flatten(map(maybe_process_unk_nbest, entries, is_unks))
                merged_entries = Lexicon.merge_duplicated_prons(no_unk_entries)
                all_entries += Lexicon.normalize_prob_of_prons(merged_entries)
            except xmlrpc.client.Fault:
                pass

        if "seq2seq" in model_types:
            all_entries += seq2seq_translator.translate(src_sent)

        merged_entries = Lexicon.merge_duplicated_prons(all_entries)
        nbest_entries = sorted(merged_entries, key=lambda e: -e.prob)[:args.n_best]
        filtered_entries = list(filter(lambda e: e.prob >= np.log(args.min_prob) and e.grapheme.strip() and e.phonemes.strip(), nbest_entries))
        src_text = "".join(src_sent)
        if args.pron_only:
            hyp_texts = list(map(lambda entry: entry.phonemes, filtered_entries))
        else:
            hyp_texts = list(map(str, filtered_entries))
        if not hyp_texts:
            oovs.append("".join(src_sent))
            logger.warning(f"{src_sent} doesn't have any valid tranlations; skipping")

        for hyp_text in hyp_texts[:args.final_n_best]:
            if utt_id is not None:
                hyp_text = f"{utt_id} {hyp_text}"
            outf.write(hyp_text + "\n")
        time.sleep(0.005)
    outf.close()

    if args.oov_path:
        write_lines_to_file(args.oov_path, oovs)

