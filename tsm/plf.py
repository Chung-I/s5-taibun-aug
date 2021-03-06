from pathlib import Path
import re
import tqdm
from copy import deepcopy

class LatticeLabel(object):
  def __init__(self, label=None):
    self.label = label
  def __repr__(self):
    return str(self.label)

class Node(object):
  def __init__(self, edges_in=dict(), edges_out=dict(), label=None):
    self.label = label
    self.edges_in = deepcopy(edges_in)
    self.edges_out = deepcopy(edges_out)
    self.node_id = None
  def __repr__(self):
    return str(self.label)

class Edge:
  def __init__(self, node_from, node_to, label=None):
    self.label = label
    self.node_from = node_from
    self.node_to = node_to
    self.visited = False
  def __repr__(self):
    return str(self.label)

def read_plf_line(line):
  parenth_depth = 0
  plf_nodes = []
  plf_edges = []

  for token in re.split("([()])", line):
    if len(token.strip()) > 0 and token.strip() != ",":
      if token == "(":
        parenth_depth += 1
        if parenth_depth == 2:
          new_node = Node(label=None)
          plf_nodes.append(new_node)
      elif token == ")":
        parenth_depth -= 1
        if parenth_depth == 0:
          new_node = Node(label=None)
          plf_nodes.append(new_node)
          break  # end of the lattice
      elif token[0] == "'":
        word, score, distance = [eval(tt) for tt in token.split(",")]
        cur_node_id = len(plf_nodes) - 1
        edge_from = cur_node_id
        edge_to = cur_node_id + distance
        edge_label = LatticeLabel(label=(word, score))
        plf_edges.append((edge_from, edge_to, edge_label))
  resolved_edges = []
  for raw_edge in plf_edges:
    edge_from, edge_to, edge_label = raw_edge
    edge = Edge(plf_nodes[edge_from], plf_nodes[edge_to], edge_label)
    plf_nodes[edge_from].edges_out[edge_label] = edge
    plf_nodes[edge_to].edges_in[edge_label] = edge
    resolved_edges.append(edge)
  return plf_nodes, plf_edges, resolved_edges

def draw_graph(filename, plf_nodes, plf_edges):
  from graphviz import Digraph
  dot = Digraph(comment='lattice')
  for node_id, node in enumerate(plf_nodes):
    dot.node(str(node_id))
  for edge in plf_edges:
    edge_from, edge_to, edge_label = edge
    word, score = edge_label.label
    dot.edge(str(edge_from), str(edge_to), f"{word} / {score}")
  dot.render(filename)

def serialize_to_plf(nodes):
    ordered_nodes = topo_sort(nodes)
    for idx, node in enumerate(ordered_nodes):
        node.node_id = idx
    plf = []
    for node in ordered_nodes:
        out_edges = []
        for edge_label, edge in node.edges_out.items():
            dist = edge.node_to.node_id - edge.node_from.node_id
            out_edges.append((edge_label.label[0], edge_label.label[1], dist))
        if out_edges:
            plf.append(tuple(out_edges))
    return str(tuple(plf))

def topo_sort(nodes):
    ordered_nodes = []
    start_nodes = []
    for node in nodes:
        if not node.edges_in:
            start_nodes.append(node)

    while start_nodes:
        node = start_nodes.pop()
        ordered_nodes.append(node)
        for edge_label, edge in node.edges_out.items():
            edge.visited = True
            no_incoming = all([e.visited for e in edge.node_to.edges_in.values()])
            if no_incoming:
                start_nodes.append(edge.node_to)

    for node in nodes:
        for edge in node.edges_in.values():
            edge.visited = False
        for edge in node.edges_out.values():
            edge.visited = False

    return ordered_nodes

if __name__ == '__main__':
  import argparse
  parser = argparse.ArgumentParser()
  parser.add_argument('input_file')
  parser.add_argument('output_dir')
  args = parser.parse_args()
  with open(args.input_file) as fp:
    for line in tqdm.tqdm(fp):
        nodes, edges, _ = read_plf_line(line)
        filename = Path(line.split()[0])
        outfile = Path(args.output_dir).joinpath(filename.stem)
        draw_graph(outfile, nodes, edges)
