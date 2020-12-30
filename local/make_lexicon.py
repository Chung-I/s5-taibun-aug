from tsm_util import generate_tsm_lexicon, generate_initials, generate_finals

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('lexicon_path', type=str, help="")
parser.add_argument('--vocab-path', type=str)
parser.add_argument('--grapheme-with-tone', action='store_true')
parser.add_argument('--phoneme-with-tone', action='store_true')
parser.add_argument('--initial-path', type=str)
parser.add_argument('--final-path', type=str)
args = parser.parse_args()
generate_tsm_lexicon(args.lexicon_path, args.grapheme_with_tone, args.phoneme_with_tone, args.vocab_path)
if args.initial_path:
    generate_initials(args.initial_path)
if args.final_path:
    generate_finals(args.final_path, args.phoneme_with_tone)
