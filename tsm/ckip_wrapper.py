from typing import List
from ckiptagger import data_utils, construct_dictionary, WS, POS, NER

class CKIPWordSegWrapper:
    def __init__(self, root_dir, lexicon=None, coerce_dictionary=True):
        self.ws = WS(root_dir, disable_cuda=False)
        word_to_weight = {word: 1 for word in lexicon}
        self.coerce_dictionary = None
        self.recommend_dictionary = None
        self.segment_delimiter_set = {",", "。", ":", "?", "!", ";", "-"}
        dictionary = construct_dictionary(word_to_weight) 
        if coerce_dictionary:
            self.coerce_dictionary = dictionary
        else:
            self.recommend_dictionary = dictionary

    def cut_some(self, sents: List[str]):
        if self.coerce_dictionary:
            cutted_sents = self.ws(sents,
                                   segment_delimiter_set=self.segment_delimiter_set,
                                   coerce_dictionary=self.coerce_dictionary)
        else:
            cutted_sents = self.ws(sents,
                                   segment_delimiter_set=self.segment_delimiter_set,
                                   recommend_dictionary=self.recommend_dictionary)
        return cutted_sents

    def cut(self, sent: str):
        cutted_sent = self.cut_some([sent])[0]
        return cutted_sent
