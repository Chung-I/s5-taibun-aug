from itertools import product
from symbols import 臺灣閩南語羅馬字拼音聲母表
from symbols import 臺灣閩南語羅馬字拼音韻母表
from symbols import 臺灣閩南語羅馬字拼音通行韻母表
import re

iNULL = "iNULL"  # dummy symbol if no initial
entering_tones = [4, 8]
TONES = list([1,2,3,4,5,6,7,8])
entering_tone_suffixes = "hptk"
is_phn = lambda final, tone: tone == "" or ((re.match("[a-z]+[hptk]", final) is not None) == (tone in entering_tones))
def read_vocab(vocab_path: str):
    with open(vocab_path) as fp:
        vocab = fp.read().splitlines()
    return vocab
def generate_tsm_lexicon(lexicon_path: str,
                         grapheme_with_tone: bool = False,
                         phoneme_with_tone: bool = False,
                         vocab_path: str = None):
    """
    Generate `lexicon.txt` through cartesian product of initials and finals.

    # Parameters

    lexicon_path: `str`
        The path to write lexicon to.
    grapheme_with_tone: `bool`, optional
        Set to True if grapheme needs tone.
    phoneme_with_tone: `bool`, optional
        Set to True if phoneme needs tone.

    # Returns:

        None
    """
    def generate_g2p_pair(initial, final, graph_tone, phn_tone):
        grapheme = f"{initial}{final}{graph_tone}"
        if initial:
            phoneme = f"{initial} {final}{phn_tone}"
        else:
            phoneme = f"{iNULL} {final}{phn_tone}"
        return grapheme, phoneme

    fp = open(lexicon_path, 'w')
    tones = TONES if grapheme_with_tone else [""]
    phonemes = product(臺灣閩南語羅馬字拼音聲母表,
                       臺灣閩南語羅馬字拼音韻母表,
                       tones)
    phonemes = filter(lambda triple: is_phn(triple[1], triple[2]),
                      phonemes)
    g2p_pairs = [generate_g2p_pair(initial, final, tone, tone if phoneme_with_tone else "")
                 for initial, final, tone in phonemes]
    vocab = None
    if vocab_path is not None:
        vocab = read_vocab(vocab_path)
    for grapheme, phoneme in g2p_pairs:
        if vocab is None or grapheme in vocab:
            fp.write(f"{grapheme} {phoneme}\n")
    fp.close()

def generate_initials(initial_path):
    initials = list(map(lambda ini: ini if ini else iNULL, 臺灣閩南語羅馬字拼音聲母表))
    with open(initial_path, 'w') as fp:
        for initial in initials:
            fp.write(f"{initial}\n")

def generate_finals(final_path, phoneme_with_tone):
    finals = []
    tones = TONES if phoneme_with_tone else [""]
    finals = [(final, tone) for final, tone in product(臺灣閩南語羅馬字拼音韻母表, tones)
              if is_phn(final, tone)]
    with open(final_path, 'w') as fp:
        for final, tone in finals:
            fp.write(f"{final}{tone}\n")

def apply_tone_sandhi(hanji, lomaji):

    from 臺灣言語工具.解析整理.拆文分析器 import 拆文分析器
    from 臺灣言語工具.語音合成 import 台灣話口語講法

    text = 台灣話口語講法(
        拆文分析器.建立句物件(hanji, lomaji)
    )

    return text

def parse_args_and_preprocess(get_paths, get_tuple_from_path, data_dir_help):
    from pathlib import Path
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('data_dir', help=data_dir_help)
    parser.add_argument('output_path', help='the path for the processed texts.')

    args = parser.parse_args()

    parallel_sents = [get_tuple_from_path(json_file)
                      for json_file in get_paths(Path(args.data_dir))]
    tone_sandhi_sents = [apply_tone_sandhi(hanji, lomaji) for hanji, lomaji
                         in parallel_sents]
