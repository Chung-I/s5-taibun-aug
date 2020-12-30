from typing import List
from tsm.sentence import ParallelSentence
from tsm.ckip_wrapper import CKIPWordSegWrapper

class ParallelCorpus(list):
    def __init__(self, parallel_sents: List[ParallelSentence], ws_root_dir=None):
        self.word_cutter = None
        if ws_root_dir is not None:
            self.word_cutter = CKIPWordSegWrapper(ws_root_dir)
        super(ParallelCorpus, self).__init__(parallel_sents)
