# -*- coding: utf-8 -*-
from http.client import HTTPSConnection
import json


from 臺灣言語工具.基本物件.章 import 章
from 臺灣言語工具.基本物件.句 import 句
from 臺灣言語工具.基本物件.組 import 組
from 臺灣言語工具.基本物件.集 import 集
from 臺灣言語工具.解析整理.拆文分析器 import 拆文分析器


class DummySegmenter:

    @classmethod
    def 斷詞(cls, 物件):
        if isinstance(物件, 章):
            return cls._斷章物件詞(物件)
        return cls._斷句物件詞(物件)

    @classmethod
    def _斷章物件詞(cls, 章物件):
        結果章物件 = 章()
        for 句物件 in 章物件.內底句:
            結果章物件.內底句.append(cls._斷句物件詞(句物件))
        return 結果章物件

    @classmethod
    def _斷句物件詞(cls, 語句):
        結果詞陣列 = []
        for 詞條 in 語句.split():
            結果詞陣列.extend(
                拆文分析器.建立組物件(詞條.replace('-', ' - ')).內底詞
            )
        結果組物件 = 組()
        結果組物件.內底詞 = 結果詞陣列
        結果集物件 = 集()
        結果集物件.內底組 = [結果組物件]
        結果句物件 = 句()
        結果句物件.內底集 = [結果集物件]
        return 結果句物件
