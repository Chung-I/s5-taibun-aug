from typing import List, Dict
from itertools import product
from functools import lru_cache
from collections import defaultdict
import re
import logging
import unicodedata

from tsm.symbols import 臺灣閩南語羅馬字拼音聲母表
from tsm.symbols import 臺灣閩南語羅馬字拼音韻母表
from tsm.symbols import 音值對照臺灣閩南語羅馬字拼音表
from tsm.symbols import iNULL, TONES, is_phn, all_syls
from tsm.POJ_TL import poj_tl

flatten = lambda l: [item for sublist in l for item in sublist]

def read_file_to_lines(filename: str, unicode_escape=False) -> List[str]:
    if unicode_escape:
        with open(filename, 'rb') as fp:
            lines = fp.read().decode('unicode_escape').splitlines()
    else:
        with open(filename) as fp:
            lines = fp.read().splitlines()
    return lines

def write_lines_to_file(filename: str, lines: List[str]) -> None:
    with open(filename, 'w') as fp:
        for line in lines:
            fp.write(line + '\n')

def generate_tsm_lexicon(lexicon_path: str,
                         grapheme_with_tone: bool = False,
                         phoneme_with_tone: bool = False):
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

    for grapheme, phoneme in g2p_pairs:
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

def 判斷變調(句物件):
    from 臺灣言語工具.語音合成.閩南語音韻.變調判斷 import 變調判斷
    from 臺灣言語工具.音標系統.閩南語.臺灣閩南語羅馬字拼音 import 臺灣閩南語羅馬字拼音
    結果句物件 = 句物件.轉音(臺灣閩南語羅馬字拼音, 函式='音值')
    判斷陣列 = 變調判斷.判斷(結果句物件)
    return 結果句物件, 判斷陣列

def 執行變調(結果句物件, 句物件, 判斷陣列):
    from 臺灣言語工具.語音合成.閩南語音韻.變調判斷 import 變調判斷
    這馬所在 = 0
    for 詞物件, 原底詞 in zip(結果句物件.網出詞物件(), 句物件.網出詞物件()):
        新陣列 = []
        for 字物件, 原底字 in zip(詞物件.內底字, 原底詞.內底字):
            變調方式 = 判斷陣列[這馬所在]
            if 變調方式 == 變調判斷.愛提掉的:
                pass
            else:
                if 字物件.音 == (None,):
                    新陣列.append(原底字.khóopih字())
                else:
                    變調音 = 變調方式.變調(字物件.音)
                    音 = [音值對照臺灣閩南語羅馬字拼音表[_變調音] for _變調音 in 變調音]
                    字物件.音 = "".join(音)
                    新陣列.append(字物件)
            這馬所在 += 1
        詞物件.內底字 = 新陣列
    return 結果句物件

def apply_tone_sandhi(hanji, lomaji, is_boundary=True, get_prefix=False):

    from 臺灣言語工具.解析整理.拆文分析器 import 拆文分析器
    from 臺灣言語工具.解析整理.解析錯誤 import 解析錯誤 
    from 臺灣言語工具.語音合成.閩南語音韻.變調 import 規則變調
    try:
        句物件 = 拆文分析器.建立句物件(hanji, lomaji) 
        結果句物件, 判斷陣列 = 判斷變調(句物件)
        if not is_boundary:
            判斷陣列[-1] = 規則變調 
        text = 執行變調(結果句物件, 句物件, 判斷陣列)
    except 解析錯誤:
        text = lomaji

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

def g2p(lexicon: Dict[str, List[str]], sentence: List[str]) -> List[List[str]]:
    phonemes = []
    words = sentence.split()
    for word in sentence.split():
        if word in lexicon:
            phonemes += lexicon[word][0]
        else:
            logging.warning(f"{word} has no entry in lexicon")
    return phonemes

def dfs_factory(backtrack):

    @lru_cache(maxsize=None)
    def dfs(idx):
        if idx > 0:
            paths = []
            for pred_idx in backtrack[idx]:
                paths += [[idx] + path for path in dfs(pred_idx)]
            return paths
        else:
            return [[0]]

    return dfs

def build_sent(sent, backtrack):
    my_dfs = dfs_factory(backtrack)
    list_cuts = my_dfs(len(sent))
    sents = []
    for cuts in list_cuts:
        cuts = list(reversed(cuts))
        words = []
        for s, e in zip(cuts[:-1], cuts[1:]):
            words.append(sent[s:e])
        sents.append(words)
    return sents

def dict_seg(sent, wordDict):
    min_cuts = [0] + [len(sent) * (idx + 1) for idx, _ in enumerate(sent)]
    backtrack = [[]] + [[idx] for idx in range(len(sent))]
    for i in range(1,len(sent)+1):
        for j in range(0, i):
            if sent[j:i] in wordDict:
                if min_cuts[j] + 1 == min_cuts[i]:
                    backtrack[i].append(j)
                elif min_cuts[j] + 1 < min_cuts[i]:
                    min_cuts[i] = min_cuts[j] + 1
                    backtrack[i] = [j]
    return build_sent(sent, backtrack)

def char2bpmf(char):
    from pypinyin import pinyin, Style
    return pinyin(char, style=Style.BOPOMOFO)[0][0]

def run_g2p():
    import argparse
    from tsm.dictionary import Dictionary
    parser = argparse.ArgumentParser()
    parser.add_argument('--lexicon-path')
    parser.add_argument('input_path')
    parser.add_argument('output_path')
    args = parser.parse_args()
    lexicon = Dictionary.parse_lexicon(args.lexicon_path)
    sentences = read_file_to_lines(args.input_path)
    list_of_phonemes = [" ".join(g2p(lexicon, sent)) for sent in sentences]
    write_lines_to_file(args.output_path, list_of_phonemes)

def raw_graph_to_all_graphs(raw_graph):
    raw_graph = re.sub("\(.*\)", "", raw_graph).strip() # get rid of comments in grapheme
    raw_graph = raw_graph.strip()
    raw_graph = re.sub("\s+", "", raw_graph)
    graphs = [graph.strip() for graph in re.split("、", raw_graph)]
    return filter(lambda g: g, graphs)

def recursively_retrieve_string_in_parenthesis(string):
    substrings = []
    try:
        span = re.search(r'\((.*?)\)', string).span()
        substrings.append(string[span[0]+1:span[1]-1])
        substrings_left = recursively_retrieve_string_in_parenthesis(string[:span[0]] + string[span[1]:])
        substrings += substrings_left
    except AttributeError:
        substrings.append(string.strip())

    return substrings

def maybe_add_tone(syl_tone):
    try:
        match = re.match("([a-z]+)(\d)", syl_tone)
        syl = match.group(1)
        tone = match.group(2)
    except AttributeError:
        if re.match("[a-z]+", syl_tone):
            syl = syl_tone
            if syl_tone[-1] in "hptk":
                tone = 4
            else:
                tone = 1
        else:
            raise ValueError
    return f"{syl}{tone}"

def process_pron(pron):
    pron = pron.lower()
    pron = unicodedata.normalize("NFKC", pron)
    pron = re.sub("ı", "i", pron) # replace the dotless i to normal i
    pron = poj_tl(pron).tlt_tls().pojs_tls()
    raw_syls = filter(lambda syl: syl, re.split('[\W\-]+', pron.strip()))
    try:
        syls = list(map(maybe_add_tone, raw_syls))
        if not all([(syl in all_syls) for syl in syls]):
            raise ValueError
        return " ".join(syls)
    except ValueError:
        return None

def raw_pron_to_all_prons(raw_pron):
    raw_pron = raw_pron.strip()
    prons = re.split(r'\/', raw_pron) # some word has multiple pronunciations separated by '/'
    prons = flatten([recursively_retrieve_string_in_parenthesis(pron.strip()) for pron in prons])
    return filter(lambda pron: pron, map(process_pron, prons))

def group(objs, key):
    dictionary = defaultdict(list)
    for obj in objs:
        dictionary[key(obj)].append(obj)
    return dictionary

def get_all_possible_translations(possible_cuts, lexicon):
    return flatten([product(*[[entry.phonemes if entry is not None else [(lambda: word)] for entry in lexicon.get(word)] for word in cut]) for cut in possible_cuts])

def match_replace(sent, match, repl):
    start, end = match.span()
    return sent[:start] + repl + sent[end:]
