from 臺灣言語工具.解析整理.拆文分析器 import 拆文分析器
from 臺灣言語工具.翻譯.摩西工具.摩西用戶端 import 摩西用戶端
from 臺灣言語工具.翻譯.摩西工具.語句編碼器 import 語句編碼器
from 臺灣言語工具.語音合成 import 台灣話口語講法
import docker
import time
from tsm.dummy_segmenter import DummySegmenter

def init():
    '''
    cmd = "docker run --name huatai -p 8080:8080 -d --rm i3thuan5/hokbu-le:huatai"
    '''
    client = docker.from_env()
    if not client.containers.list(filters={"name":"huatai"}):
        client.containers.run("i3thuan5/hokbu-le:huatai", 
                                name="huatai",
                                ports={'8080/tcp': 8080},
                                detach=True,
                                auto_remove=True)    

def translate(text, seg=False):
    #華語句物件 = 拆文分析器.建立句物件(text)
    if seg:
        from tsm.ckip_segmenter import CKIPSegmenter
        華語斷詞句物件 = CKIPSegmenter.斷詞(text)
    else:
        華語斷詞句物件 = DummySegmenter.斷詞(text)
    台語句物件, 華語新結構句物件, 分數 = (摩西用戶端(位址='localhost', 編碼器=語句編碼器).翻譯分析(華語斷詞句物件))
    口語講法 = 台灣話口語講法(台語句物件)
    return 華語斷詞句物件, 台語句物件, 口語講法

    
if __name__ == "__main__":
    from util import read_file_to_lines, write_lines_to_file
    init()
    # You need to wait until the docker is ready.
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('input_path')
    parser.add_argument('output_path')
    parser.add_argument('--seg', action='store_true')
    args = parser.parse_args()
    
    sents = read_file_to_lines(args.input_path)
    sent_of_phonemes = []
    fp = open(args.output_path, 'w')
    for sent in sents:
        try:
            phonemes = translate(sent, args.seg)[1].看音()
        except:
            phonemes = " - "
        print(sent, phonemes)
        fp.write(sent + "\t" + phonemes + '\n')
    fp.close()
    #write_lines_to_file(args.output_path, sent_of_phonemes)
    
