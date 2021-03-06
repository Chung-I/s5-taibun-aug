from enum import Enum
from itertools import product

臺灣閩南語羅馬字拼音聲母表 = {
    'p', 'ph', 'm', 'b',
    't', 'th', 'n', 'l',
    'k', 'kh', 'ng', 'g',
    'ts', 'tsh', 's', 'j',
    'h', '',
}
# 臺灣閩南語羅馬字拼音方案使用手冊 + 臺灣語語音入門 + 教育部辭典的字
# 歌仔戲：枝頭 ki1 thiou5， 土 thou。目前教羅共ou轉oo（因為台華辭典按呢處理）
臺灣閩南語羅馬字拼音通行韻母表 = {
    'a', 'ah', 'ap', 'at', 'ak', 'ann', 'annh',
    'am', 'an', 'ang',
    'e', 'eh', 'enn', 'ennh',
    'i', 'ih', 'ip', 'it', 'ik', 'inn', 'innh',
    'im', 'in', 'ing',
    'o', 'oh',
    'oo', 'ooh', 'op', 'ok', 'om', 'ong', 'onn', 'onnh',
    'u', 'uh', 'ut', 'un',
    'ai', 'aih', 'ainn', 'ainnh',
    'au', 'auh', 'aunn', 'aunnh',
    'ia', 'iah', 'iap', 'iat', 'iak', 'iam', 'ian', 'iang', 'iann', 'iannh',
    'io', 'ioh',
    'iok', 'iong', 'ionn',
    'iu', 'iuh', 'iut', 'iunn', 'iunnh',
    'ua', 'uah', 'uat', 'uak', 'uan', 'uann', 'uannh',
    'ue', 'ueh', 'uenn', 'uennh',
    'ui', 'uih', 'uinn', 'uinnh',
    'iau', 'iauh', 'iaunn', 'iaunnh',
    'uai', 'uaih', 'uainn', 'uainnh',
    'm', 'mh', 'ng', 'ngh',
    'ioo', 'iooh',  # 諾 0hioo 0hiooh, 詞目總檔.csv:khan35 jioo51
}
臺灣閩南語羅馬字拼音次方言韻母表 = {
    'er', 'erh', 'erm', 'ere', 'ereh',  # 泉　鍋
    'ee', 'eeh', 'uee',  # 漳　家
    'eng',
    'ir', 'irh', 'irp', 'irt', 'irk', 'irm', 'irn', 'irng', 'irinn',
    'ie',  # 鹿港偏泉腔
    'or', 'orh', 'ior', 'iorh',  # 蚵
    'uang',  # 金門偏泉腔　　風　huang1
    'oi', 'oih',  # 詞彙方言差.csv:硩⿰落去
}
臺灣閩南語羅馬字拼音韻母表 = 臺灣閩南語羅馬字拼音通行韻母表 | 臺灣閩南語羅馬字拼音次方言韻母表

iNULL = "iNULL"
TONES = list(map(str, range(1, 10)))
entering_tones = ['4', '8']
entering_tone_suffixes = "hptk"

is_phn = lambda final, tone: tone == "" or ((final[-1] in entering_tone_suffixes) == (tone in entering_tones))

is_final = lambda final: ((final[0][-1] in entering_tone_suffixes) == (final[-1] in entering_tones))

join_pair = lambda pair: "".join(pair)

all_toneless_syls = set(map(join_pair, product(臺灣閩南語羅馬字拼音聲母表, 臺灣閩南語羅馬字拼音韻母表)))
all_syls = set(map(join_pair, product(臺灣閩南語羅馬字拼音聲母表, map(join_pair, filter(is_final, product(臺灣閩南語羅馬字拼音韻母表, TONES))))))

class Stratum(Enum):
    無 = 0
    文 = 1
    白 = 2
    俗 = 3
    替 = 4

from 臺灣言語工具.音標系統.閩南語.臺灣閩南語羅馬字拼音轉音值模組 \
    import 臺灣閩南語羅馬字拼音對照音值聲母表, 臺灣閩南語羅馬字拼音對照音值韻母表 

音值對照臺灣閩南語羅馬字拼音聲母表 = {
    value: key for key, value in 臺灣閩南語羅馬字拼音對照音值聲母表.items()
}

音值對照臺灣閩南語羅馬字拼音韻母表 = {
    value: key for key, value in 臺灣閩南語羅馬字拼音對照音值韻母表.items()
}

音值對照臺灣閩南語羅馬字拼音表 = {**音值對照臺灣閩南語羅馬字拼音聲母表,
                                  **音值對照臺灣閩南語羅馬字拼音韻母表}
音值對照臺灣閩南語羅馬字拼音表['ə'] = 'o'
音值對照臺灣閩南語羅馬字拼音表['əʔ'] = 'oh'
音值對照臺灣閩南語羅馬字拼音表['iə'] = 'io'
音值對照臺灣閩南語羅馬字拼音表['iəʔ'] = 'ioh'
for i in range(1, 10):
    音值對照臺灣閩南語羅馬字拼音表[str(i)] = str(i)
音值對照臺灣閩南語羅馬字拼音表['10'] = '4'
