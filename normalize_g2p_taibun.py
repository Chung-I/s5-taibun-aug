from tsm.POJ_TL import poj_tl
from tsm.util import read_file_to_lines, flatten, write_lines_to_file
import cn2an

def normalize(line):
    line = poj_tl(line).tls_tlt().pojt_tlt()
    line = cn2an.transform(line, "an2cn")
    return line

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('src_path')
    parser.add_argument('dest_path')
    args = parser.parse_args()

    lines = read_file_to_lines(args.src_path)
    dest_sents = []
    #preprocess = lambda line: Sentence.parse_mixed_text(line, remove_punct=True)
    dest_sents = map(normalize, lines)
    write_lines_to_file(args.dest_path, dest_sents)
