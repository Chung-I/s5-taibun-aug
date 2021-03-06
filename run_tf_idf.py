from tsm.util import read_file_to_lines
from tsm.lexicon import Lexicon
from tsm.sentence import Sentence
from collections import Counter
import tqdm
import numpy as np
import argparse
from sklearn.feature_extraction.text import TfidfVectorizer

parser = argparse.ArgumentParser()
parser.add_argument('vocab_path')
parser.add_argument('bg_corpus_path')
parser.add_argument('fg_corpus_path')
parser.add_argument('--top-k', type=int, default=50)
args = parser.parse_args()

def get_dfs(vocab, raw_docs):
    bg_docs = []
    dfs = np.zeros((len(vocab), len(raw_docs)), dtype=np.int8)
    for doc_idx, raw_doc in tqdm.tqdm(enumerate(raw_docs)):
        words = raw_doc.split()
        for word in words:
            if word in vocab:
                dfs[vocab[word], doc_idx] += 1
    dfs = np.any(dfs > 0, axis=1)
    return dfs

def get_tfs(vocab, raw_doc):
    tfs = np.zeros(len(vocab))
    words = raw_doc.split()
    for word in words:
        if word in vocab:
            tfs[vocab[word]] += 1
    return tfs


def line2tuple(line):
    word, idx = line.split()
    return word, idx

word2id = {word: idx for idx, word in enumerate(read_file_to_lines(args.vocab_path))}
id2word = {idx: word for word, idx in word2id.items()}

bg_lines = read_file_to_lines(args.bg_corpus_path)
fg_lines = read_file_to_lines(args.fg_corpus_path)

#doc_freqs = get_dfs(list(word2id.keys()), bg_lines)
#term_freqs = get_tfs(" ".join(fg_lines))
vectorizer = TfidfVectorizer()
vectorizer.fit(bg_lines)
features = vectorizer.get_feature_names()

bg_top_features = [features[i] for i in np.argsort(-vectorizer.idf_)[:args.top_k]]
print(bg_top_features)
fg_tfidfs = vectorizer.transform(fg_lines).todense()
indeces = np.argsort(-fg_tfidfs, axis=1).tolist()
fg_top_features = [[features[i] for i in indices[:args.top_k]] for indices in indeces]
for fg_top_feature in fg_top_features:
    print(fg_top_feature)

#tf_idfs = {word: term_freqs[vocab[word]] / doc_freqs[vocab[word]] if doc_freqs[vocab[word]] > 0 else float('inf') for word in list(word2id.keys())}
#tf_idf_ranking = sorted(list(tf_idfs.items()), key=lambda pair: pair[1])
#print(tf_idf_ranking[:100])

