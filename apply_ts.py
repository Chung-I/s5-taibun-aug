import argparse

from tsm.util import apply_tone_sandhi
from tsm.lexicon import Lexicon, LexiconEntry
from 臺灣言語工具.基本物件.句 import 句

parser = argparse.ArgumentParser()
parser.add_argument('input_path')
parser.add_argument('output_path')
parser.add_argument('--include-non-boundary', action='store_true')
parser.add_argument('--include-prefix', action='store_true')
parser.add_argument('--no-new-entry', action='store_true',
                    help="when including prefixes, only include prefixes that"
                         "itself is already an entry in the original lexicon.")
args = parser.parse_args()

lexicon = Lexicon.from_kaldi(args.input_path, with_prob=True)
new_lexicon_entries = []
def get_pron(maybe_pron):
    if isinstance(maybe_pron, 句):
        pron = maybe_pron.看音()
    else:
        pron = maybe_pron
    return pron

for grapheme in lexicon:
    entries = lexicon[grapheme]
    for entry in entries:
        bnd_sandhi_pron = apply_tone_sandhi(grapheme, entry.phonemes)
        new_bnd_entry = LexiconEntry(grapheme, entry.prob, get_pron(bnd_sandhi_pron))
        new_lexicon_entries.append(new_bnd_entry)

        is_monosyllable_word = False
        if isinstance(bnd_sandhi_pron, 句):
            word = bnd_sandhi_pron.篩出字物件()
            is_monosyllable_word = len(word) == 1
        if args.include_non_boundary or is_monosyllable_word:
            not_bnd_sandhi_pron = apply_tone_sandhi(grapheme, entry.phonemes, is_boundary=False)
            new_not_bnd_entry = LexiconEntry(grapheme, entry.prob, get_pron(not_bnd_sandhi_pron))
            new_lexicon_entries.append(new_not_bnd_entry)

        if args.include_prefix:
            if isinstance(bnd_sandhi_pron, 句):
                prefix_words = bnd_sandhi_pron.篩出字物件()[:-1]
                if len(prefix_words) > 0:
                    prefix_grapheme = "".join([字.看型("", "", "") for 字 in prefix_words])
                    if not args.no_new_entry or prefix_grapheme in lexicon:
                        prefix_pron = " ".join([字.看音() for 字 in prefix_words])
                        prefix_entry = LexiconEntry(prefix_grapheme, entry.prob, prefix_pron)
                        new_lexicon_entries.append(prefix_entry)

new_lexicon = Lexicon(new_lexicon_entries, sum_dup_pron_probs=False)
new_lexicon.write(args.output_path)
