from typing import NamedTuple, List, Union
from itertools import groupby, product, chain
import re
from functools import reduce
import operator

import pandas as pd
import numpy as np
import scipy.special

from tsm.symbols import Stratum
from tsm.util import read_file_to_lines, write_lines_to_file, flatten, char2bpmf, group
from tsm.util import raw_graph_to_all_graphs, raw_pron_to_all_prons
import zhon.hanzi

class LexiconEntry:
    def __init__(self, grapheme: str, prob: float, phonemes: str, stratum: Stratum = Stratum.無):
        self.grapheme = grapheme
        self.prob = prob
        self.phonemes = phonemes
        self.stratum = stratum
    def __str__(self):
        grapheme = "".join(self.grapheme) if isinstance(self.grapheme, list) else self.grapheme
        phonemes = " ".join(self.phonemes) if isinstance(self.phonemes, list) else self.phonemes
        if self.prob is None:
            return f"{grapheme} {phonemes}"
        else:
            return f"{grapheme} {np.exp(self.prob)} {phonemes}"
    def __add__(self, other):
        grapheme = self.grapheme + other.grapheme
        prob = self.prob + other.prob
        phonemes = f"{self.phonemes} {other.phonemes}"
        stratum = self.stratum if self.stratum == other.stratum else Stratum.無
        return LexiconEntry(grapheme, prob, phonemes, stratum)

class MosesHelper:
    @staticmethod
    def parse_line_to_entry(line, strip_punct=True, row=1, delimiter="\s+"):
        try:
            columns = re.split(delimiter, line)
            raw_src, raw_tgt, prob = columns[0].strip(), columns[1].strip(), columns[2]
            if raw_tgt == "NULL":
                return None
            if len(raw_src.split()) > 1:
                return None
            tgt = raw_tgt
            #tgt_words = re.split("\s+", raw_tgt)
            #tgt = " ".join([word for word in tgt_words])
            if strip_punct:
                src = "".join([match.group(0) for match in 
                               re.finditer(f"[{zhon.hanzi.characters}]", raw_src)])
                tgt = " ".join([match.group(0) for match in 
                                re.finditer(f"[A-Za-z]+\d", tgt)])
            if not (src and tgt):
                return None
            prob = reduce(operator.mul, map(float, re.split("\s+", prob.strip())))
        except IndexError:
            return None
        return LexiconEntry(src, prob, tgt)

class Lexicon(dict):
    def __init__(self, entries: List[NamedTuple], sum_dup_pron_probs: bool = True):
        self.len_diff_heur = lambda e: abs(len(e.grapheme) - len(re.split("\s+", e.phonemes)))
        super(Lexicon, self).__init__(group(entries, lambda e: e.grapheme).items())
        self.merge_all_duplicated_prons(sum_dup_pron_probs)

    @classmethod
    def build_bpmf_unk_interpolater(cls, lexicon):
        entries = []
        def grapheme_to_bpmf(entry):
            entry.grapheme = char2bpmf(entry.grapheme)
            return entry
        for graph in lexicon:
            if len(graph) > 1:
                continue
            entries += list(map(grapheme_to_bpmf, lexicon[graph]))
        return cls(entries)

    @staticmethod
    def merge_duplicated_prons(entries, sum_dup_pron_probs: bool = True):
        if len(entries) == 1:
            return entries
        dict_merged_prons = group(entries, key=lambda e: (e.grapheme, e.phonemes.strip()))
        def merge_prons(prons):
            strata = set([pron.stratum for pron in prons if pron.stratum is not Stratum.無])
            stratum = Stratum.無
            if len(strata) == 1:
                stratum = next(iter(strata))
            probs = [pron.prob for pron in prons]
            if sum_dup_pron_probs:
                prob = scipy.special.logsumexp(probs)
            else:
                prob = max(probs)
            return LexiconEntry(prons[0].grapheme, prob, prons[0].phonemes, stratum)

        merged_prons = [merge_prons(prons) for prons in dict_merged_prons.values()]
        return Lexicon.normalize_prob_of_prons(merged_prons)

    def merge_all_duplicated_prons(self, sum_dup_pron_probs: bool = True):
        for grapheme in self:
            self[grapheme] = Lexicon.merge_duplicated_prons(self[grapheme], sum_dup_pron_probs)

    @classmethod
    def from_moses(cls, moses_path, unicode_escape):
        lines = read_file_to_lines(moses_path, unicode_escape)
        entries = filter(lambda x: x, [MosesHelper.parse_line_to_entry(line, delimiter='\|\|\|')
                                       for line in lines])
        return cls(list(entries))

    @classmethod
    def from_kaldi(cls, lexicon_path: str, with_prob: bool = False, sum_dup_pron_probs: bool = True):
        lines = read_file_to_lines(lexicon_path)
        def parse_line(line):
            cols = line.split()
            if with_prob:
                return LexiconEntry(cols[0], np.log(float(cols[1])), " ".join(cols[2:]))
            else:
                return LexiconEntry(cols[0], 0.0, " ".join(cols[1:]))
        return cls(map(parse_line, lines), sum_dup_pron_probs)

    def prune_lexicon(self, top_k: int, min_val: float):
        def prune_entries(entries):
            entries = sorted(entries, key=lambda e: -e.prob)[:top_k]
            max_prob = entries[0].prob
            entries = [LexiconEntry(e.grapheme, round(e.prob * (1 / max_prob), 5), e.phonemes) for e in entries]
            return list(filter(lambda e: e.prob > min_val, entries))
        for grapheme in self:
            self[grapheme] = prune_entries(self[grapheme])

    def write(self, dest_path):
        out_lines = map(str, flatten(self.values()))
        write_lines_to_file(dest_path, out_lines)

    def get_most_probable(self, word):
        if word in self:
            return max(self[word], key=lambda e: e.prob)
        else:
            raise KeyError

    def get_nbest(self, word, n_best, filter_func=(lambda e: True)):
        if word in self:
            return sorted(filter(filter_func, self[word]),
                          key=lambda e: (-e.prob, self.len_diff_heur(e)))[:n_best]
        else:
            raise KeyError

    @staticmethod
    def normalize_prob_of_prons(prons: List[LexiconEntry]):
        if len(prons) == 0:
            return []
        new_hyps = []
        probs = np.array([pron.prob for pron in prons])
        max_prob = np.max(probs)
        for pron in prons:
            pron.prob = pron.prob - max_prob
        return prons

    def get_oovs(self, maybe_oov_words: List[str]):
        return list(filter(lambda word: word not in self, maybe_oov_words))

    def add_entries(self, entries: List[LexiconEntry]):
        for entry in entries:
            if entry.grapheme in self:
                self[grapheme].append(entry)
            else:
                self[grapheme] = [entry]
        self.merge_all_duplicated_prons()

    @staticmethod
    def from_dictionary_to_entries(dictionary_path, grapheme_key, phoneme_key, raw_entries=False):
        df = pd.read_csv(dictionary_path, dtype={grapheme_key: str, phoneme_key: str})
        df = df.replace(np.nan, "", regex=True)
        all_raw_entries = list(zip(df[grapheme_key], df[phoneme_key]))
        if raw_entries:
            return all_raw_entries
        all_entries = []
        for raw_graph, raw_pron in all_raw_entries: # prons = pronunciations
            entries = list(product(raw_graph_to_all_graphs(raw_graph), raw_pron_to_all_prons(raw_pron)))
            all_entries.append(entries)
        return [LexiconEntry(graph, 0.0, pron) for graph, pron in chain(*all_entries)]

    @classmethod
    def from_dictionary(cls, *args):
        return cls(cls.from_dictionary_to_entries(*args))

    @classmethod
    def from_moedict(cls,
                     dictionary_path,
                     grapheme_key: str = "詞目",
                     phoneme_key: str = "音讀",
                     stratum_key: str = "文白屬性"):
        df = pd.read_csv(dictionary_path, dtype={grapheme_key: str, phoneme_key: str, stratum_key: str})
        df = df.replace(np.nan, "", regex=True)
        all_raw_entries = list(zip(df[grapheme_key], df[phoneme_key], df[stratum_key]))
        all_entries = []
        for raw_graph, raw_pron, raw_stratum in all_raw_entries: # prons = pronunciations
            entries = list(product(raw_graph_to_all_graphs(raw_graph), raw_pron_to_all_prons(raw_pron),
                                   [Stratum(int(raw_stratum))]))
            all_entries.append(entries)

        return cls([LexiconEntry(graph, 0.0, pron, stratum) for graph, pron, stratum in chain(*all_entries)])
