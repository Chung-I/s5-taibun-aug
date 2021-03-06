from tsm.plf import read_plf_line, LatticeLabel, Node, Edge, serialize_to_plf, topo_sort
from tsm.sentence import Sentence
import numpy as np

def edge_logprob_to_prob(edge):
    word, score = edge.label.label
    prev_node = edge.node_from
    next_node = edge.node_to
    del prev_node.edges_out[edge.label]
    del next_node.edges_in[edge.label]

    new_edge_label = LatticeLabel(label=(word, np.exp(score)))
    new_edge = Edge(prev_node, next_node, new_edge_label)
    prev_node.edges_out[new_edge.label] = new_edge
    next_node.edges_in[new_edge.label] = new_edge

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('input_file')
    parser.add_argument('output_file')
    args = parser.parse_args()
    outf = open(args.output_file, 'w')
    with open(args.input_file) as fp:
        for line in fp:
            utt = line.split('\t')[0]
            nodes, _, edges = read_plf_line(line)
            for edge in edges:
                edge_logprob_to_prob(edge)
            plf_str = serialize_to_plf(nodes)
            outf.write(utt + '\t' + plf_str + '\n')
