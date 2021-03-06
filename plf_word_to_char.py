from tsm.plf import read_plf_line, LatticeLabel, Node, Edge, serialize_to_plf, topo_sort
from tsm.sentence import Sentence


def word_to_char(nodes, edges):
    new_nodes = []
    new_edges = []
    for edge in edges:
        word, score = edge.label.label
        chars = Sentence.parse_mixed_text(word)
        if len(chars) > 1:
            first_node = edge.node_from
            last_node = edge.node_to
            del edge.node_from.edges_out[edge.label]
            del edge.node_to.edges_in[edge.label]

            next_node = Node(label=None)
            new_nodes.append(next_node)
            new_edge_label = LatticeLabel(label=(chars[0], score))
            new_edge = Edge(first_node, next_node, new_edge_label)
            new_edge.node_from.edges_out[new_edge.label] = new_edge
            new_edge.node_to.edges_in[new_edge.label] = new_edge
            new_edges.append(new_edge)
            prev_node = next_node
            for char in chars[1:-1]:
                next_node = Node(label=None)
                new_nodes.append(next_node)
                new_edge_label = LatticeLabel(label=(char, 0))
                new_edge = Edge(prev_node, next_node, new_edge_label)
                new_edge.node_from.edges_out[new_edge.label] = new_edge
                new_edge.node_to.edges_in[new_edge.label] = new_edge
                new_edges.append(new_edge)
                prev_node = next_node
            new_edge_label = LatticeLabel(label=(chars[-1], 0))
            new_edge = Edge(prev_node, last_node, new_edge_label)
            new_edge.node_from.edges_out[new_edge.label] = new_edge
            new_edge.node_to.edges_in[new_edge.label] = new_edge
            new_edges.append(new_edge)
        else:
            new_edges.append(edge)
    return nodes + new_nodes


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('input_file')
    parser.add_argument('output_file')
    parser.add_argument('--dump-sos-eos', action='store_true')
    args = parser.parse_args()
    outf = open(args.output_file, 'w')
    with open(args.input_file) as fp:
        for line in fp:
            utt = line.split('\t')[0]
            nodes, _, edges = read_plf_line(line)
            new_nodes = word_to_char(nodes, edges)
            plf_str = serialize_to_plf(new_nodes)
            outf.write(utt + '\t' + plf_str + '\n')
