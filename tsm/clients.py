from typing import List, NamedTuple, Any
import numpy as np
import requests
import re
from itertools import groupby
from operator import itemgetter
import logging

import xmlrpc.client

from tsm.util import char2bpmf
from tsm.lexicon import Lexicon, LexiconEntry
from tsm.symbols import Stratum

logger = logging.getLogger(__name__)


class MosesConfig(NamedTuple):
    align: bool
    report_all_factors: bool
    n_best: int

class MosesClient:
    def __init__(self,
                 address: str = "localhost",
                 port: int = 8080,
                 path: str = "RPC2",
                 config: MosesConfig = MosesConfig(True, True, 5)):
        self.server = xmlrpc.client.ServerProxy(f"http://{address}:{port}/{path}")
        self.config = config

    def format_input(self, sent):
        data = {
            "text": " ".join(sent),
            "align": str(self.config.align).lower(),
            "report-all-factors": str(self.config.report_all_factors).lower(),
            'nbest': self.config.n_best,
        }
        return data

    def translate(self, sent):
        formatted_input = self.format_input(sent)
        return self.server.translate(formatted_input)

    #def translate_cutted(self, sent: List[str]):
    #    cutted_sent = [b'-'.join([w.encode('unicode-escape') for w in word]) for word in sent]
    #    raw_sent = b' '.join(cutted_sent).decode('utf-8')
    #    results = self.translate(raw_sent)
    #    encoded_nbest = []
    #    for nbest in results['nbest']:
    #        nbest['hyp'] = bytearray(nbest['hyp'], encoding='utf-8').decode('unicode_escape')
    #        encoded_nbest.append(nbest)
    #    results['nbest'] = encoded_nbest
    #    return results

    @staticmethod
    def parse_hyp(src, hyp):
        raw_text = hyp['hyp'].strip()
        raw_text = re.sub('\|\d+\-\d+\|', '', raw_text)
        raw_text = raw_text.strip()
        words = re.split('\s+', raw_text)
        #is_unks = [re.match(".*\|UNK\|UNK\|UNK", word) is not None for word in words]
        is_unks = [re.match("[A-Za-z]+\d", word) is None for word in words]
        clean_words = [re.sub('\|UNK\|UNK\|UNK', '', word) for word in words]
        return LexiconEntry(src, hyp['totalScore'], " ".join(clean_words)), is_unks

    @staticmethod
    def merge_duplicate_hyps(nbest: List[Any]):
        new_hyps = []
        for key, group in groupby(sorted(nbest, key=itemgetter('text')), key=itemgetter('text')):
            group = list(group)
            prob = np.log(np.sum(np.exp(np.array([hyp['prob'] for hyp in group]))))
            new_hyps.append({'text': key, 'prob': prob, 'unk': group[0]['unk']})
        new_hyps = sorted(new_hyps, key=lambda hyp: -hyp['prob'])
        return new_hyps


class AllennlpClient:
    def __init__(self,
                 address: str = "localhost",
                 port: int = 8000,
                 path: str = "predict"):
        self.server = lambda data: requests.post(f"http://{address}:{port}/{path}", json=data)

    def format_input(self, sent):
        data = {
            "source": " ".join(sent),
        }
        return data

    def translate(self, sent):
        formatted_input = self.format_input(sent)
        prediction = self.server(formatted_input).json()
        log_probs, hypotheses = prediction['class_log_probabilities'], prediction['predicted_tokens']
        entries =  [LexiconEntry("".join(sent), log_prob, " ".join(hypothesis))
                    for log_prob, hypothesis in zip(log_probs, hypotheses)]
        entries = list(filter(lambda e: all([re.match("[a-z]+\d", syl) is not None for syl in e.phonemes.split()]), entries))
        return Lexicon.normalize_prob_of_prons(entries)

class UnkTranslator:
    def __init__(self, prob_lexicon, dict_lexicon, taibun_lexicon, consult_order, seq2seq):
        self.prob_lexicon = prob_lexicon
        self.taibun_lexicon = taibun_lexicon
        self.dict_lexicon = dict_lexicon
        self.unk_lexicon = Lexicon.build_bpmf_unk_interpolater(taibun_lexicon)
        self.seq2seq = seq2seq
        self.consultants = [(name, getattr(self, f"{name}_translate")) for name in consult_order]
        self.consult_order = consult_order
        self.cache = {}

    def prob_translate(self, word, n_best):
        return self.prob_lexicon.get_nbest(word, n_best)

    def dict_translate(self, word, n_best):
        return self.dict_lexicon.get_nbest(word, n_best)

    def bpmf_translate(self, word, n_best):
        bpmf = char2bpmf(word)
        hyps = self.unk_lexicon.get_nbest(bpmf, n_best, lambda e: e.stratum == Stratum.文)
        hyps += self.unk_lexicon.get_nbest(bpmf, n_best, lambda e: e.stratum == Stratum.白)
        hyps += self.unk_lexicon.get_nbest(bpmf, n_best, lambda e: e.stratum not in [Stratum.白, Stratum.文])
        for hyp in hyps:
            hyp.grapheme = word
        return hyps

    def seq2seq_translate(self, word, n_best):
        return self.seq2seq.translate(word)

    def translate(self, word, n_best=1):
        translator_name = None
        hyps = []
        for name, consultant in self.consultants:
            try:
                translator_name = name
                hyps = consultant(word, n_best)
                break
            except KeyError:
                continue
        return hyps
