from typing import Dict, List, Any
import json
import unicodedata
import regex as re
import zhon.hanzi
import cn2an
import opencc

converter = opencc.OpenCC('s2tw.json')


class Sentence:
    word_segmenter_cache: dict = {}
    @staticmethod
    def from_line(line: str, remove_punct: bool = True,
                  form: str = 'char', pos_tagged: bool = False,
                  normalize: bool = True):
        assert form in ['char', 'word', 'sent']
        if pos_tagged:
            if remove_punct:
                # remove words that are punctuation mark (PM)
                line = re.sub("\s\S+_PM\s", " ", line)
            line = re.sub("_\S+\s", " ", line)

        if normalize:
            line = Sentence.normalize(line)

        if form in ['char', 'word']:
            words = line.split()
        elif form == 'sent':
            words = list(line)
        else:
            raise NotImplementedError

        if remove_punct:
            words = list(filter(lambda w: w, [re.sub("[^\P{P}-]+", "", word.strip()).strip() for word in words]))

        return words

    @staticmethod
    def normalize(line: str):
        line = unicodedata.normalize("NFKC", line)
        line = cn2an.transform(line, "an2cn")
        line = converter.convert(line)
        return line

    @staticmethod
    def cut(sent):
        if "ckip" not in Sentenceword_segmenter_cache:
            from tsm.ckip_wrapper import CKIPWordSegWrapper
            Sentence.word_segmenter_cache["ckip"] = CKIPWordSegWrapper('/home/nlpmaster/ssd-1t/weights/data')
        sent = re.sub("\s+", "", sent)
        return Sentence.word_segmenter_cache["ckip"].cut(sent)

    @staticmethod
    def parse_mixed_text(mixed_text, remove_punct=False):
        if remove_punct:
            return [match.group() for match in re.finditer(f"[{zhon.hanzi.characters}]|[^{zhon.hanzi.characters}\W](\-|[^{zhon.hanzi.characters}\W])+|[^{zhon.hanzi.characters}\W]+", mixed_text)]
        else:
            return [match.group() for match in re.finditer(f"[{zhon.hanzi.characters}]|[^{zhon.hanzi.characters}\W](\-|[^{zhon.hanzi.characters}\W])+|\p{{P}}", mixed_text)]


#class TaibunSentence(Sentence):
#    @staticmethod
#    def from_line(line: str, remove_punct: bool = True,
#                  form: str = 'char'):
#        assert form in ['char', 'word', 'sent']
#        if form in ['char', 'word']:
#            words = line.split()
#        elif form == 'sent':
#            words = list(line)
#        else:
#            raise NotImplementedError

class ParallelSentence(list):
    """

    Parallel sentence.

    # Parameters

    sent_of_langs : `Dict[str, str]`
        A dictionary storing language as key and corresponding sentence string as value.
    metadata: `Dict[str, Any]`
        A dictionary storing other metadata describing the sentence, e.g. source, speaker, etc.
    """
    def __init__(self, sent_of_langs: Dict[str, str], metadata: Dict[str, Any]):
        self.metadata = metadata
        super(ParallelSentence, self).__init__(sent_of_langs)

    @classmethod
    def from_json(cls, json_file: str, langs: List[str],
                  metadata_fields: List[str]):
        with open(json_file) as fp:
            raw_sent = json.load(fp)

        sent_of_langs = {lang: raw_sent[lang] for lang in langs}
        metadata = {field: raw_sent[field] for field in metadata_fields}

        return cls(sent_of_langs, metadata)

    @staticmethod
    def from_json_to_tuple(json_file: str, mandarin_key: str, taigi_key: str):
                           #cut_mandarin: bool = False,
                           #normalize_mandarin: bool = False,
                           #preprocess_taigi: bool = True):

        with open(json_file) as fp:
            raw_sent = json.load(fp)
        mandarin = raw_sent[mandarin_key]
        taigi = raw_sent[taigi_key]
        #if cut_mandarin:
        #    mandarin_words = Sentence.cut(mandarin)
        #    mandarin = " ".join(mandarin_words)
        #if normalize_mandarin:
        #    mandarin_words = Sentence.from_line(mandarin, form='word')
        #    mandarin = " ".join(mandarin_words)
        #if preprocess_taigi:
        #    taigi_words = ParallelSentence.parse_taigi(taigi)
        #    taigi = " ".join(taigi_words)

        return (mandarin, taigi)

    @staticmethod
    def parse_taigi(taigi):
        #remove alternative pronunciations annotated in brackets, e.g. teh4(leh4) -> teh4
        taigi = re.sub("\([A-Za-z\d\s]+\)", "", taigi)
        #remove alternative pronunciations annotated with slashes, e.g. teh4/leh4 -> teh4
        taigi = re.sub("(\/[A-Za-z]+\d)+", "", taigi)
        words = []
        for word in re.finditer("[A-Za-z]+\d", taigi):
            words.append(word.group())
        return words


