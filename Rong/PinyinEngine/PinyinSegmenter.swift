import Foundation

/// Segments a raw Pinyin string (e.g. "nihao") into valid syllable arrays (e.g. ["ni","hao"]).
/// Uses maximum-forward matching with fallback to find all valid segmentations.
nonisolated struct PinyinSegmenter {

    // MARK: - Valid Pinyin Syllables (411 syllables)

    static let validSyllables: Set<String> = {
        // All valid Mandarin Pinyin syllables (tone-marks stripped)
        let syllables = [
            // a-group
            "a","ai","an","ang","ao",
            // b-group
            "ba","bai","ban","bang","bao","bei","ben","beng","bi","bian","biao","bie",
            "bin","bing","bo","bu",
            // c-group
            "ca","cai","can","cang","cao","ce","cen","ceng","cha","chai","chan","chang",
            "chao","che","chen","cheng","chi","chong","chou","chu","chua","chuai","chuan",
            "chuang","chui","chun","chuo","ci","cong","cou","cu","cuan","cui","cun","cuo",
            // d-group
            "da","dai","dan","dang","dao","de","dei","den","deng","di","dia","dian","diao",
            "die","ding","diu","dong","dou","du","duan","dui","dun","duo",
            // e-group
            "e","ei","en","eng","er",
            // f-group
            "fa","fan","fang","fei","fen","feng","fo","fou","fu",
            // g-group
            "ga","gai","gan","gang","gao","ge","gei","gen","geng","gong","gou","gu","gua",
            "guai","guan","guang","gui","gun","guo",
            // h-group
            "ha","hai","han","hang","hao","he","hei","hen","heng","hong","hou","hu","hua",
            "huai","huan","huang","hui","hun","huo",
            // i (standalone)
            "yi","yin","ying","yo","yong","you","yu","yuan","yue","yun",
            // j-group
            "ji","jia","jian","jiang","jiao","jie","jin","jing","jiong","jiu","ju","juan",
            "jue","jun",
            // k-group
            "ka","kai","kan","kang","kao","ke","kei","ken","keng","kong","kou","ku","kua",
            "kuai","kuan","kuang","kui","kun","kuo",
            // l-group
            "la","lai","lan","lang","lao","le","lei","leng","li","lia","lian","liang","liao",
            "lie","lin","ling","liu","lo","long","lou","lu","luan","lun","luo","lv","lve","lue",
            // m-group
            "ma","mai","man","mang","mao","me","mei","men","meng","mi","mian","miao","mie",
            "min","ming","miu","mo","mou","mu",
            // n-group
            "na","nai","nan","nang","nao","ne","nei","nen","neng","ni","nian","niang","niao",
            "nie","nin","ning","niu","nong","nou","nu","nuan","nun","nuo","nv","nve","nue",
            // o-group
            "o","ou",
            // p-group
            "pa","pai","pan","pang","pao","pei","pen","peng","pi","pian","piao","pie","pin",
            "ping","po","pou","pu",
            // q-group
            "qi","qia","qian","qiang","qiao","qie","qin","qing","qiong","qiu","qu","quan",
            "que","qun",
            // r-group
            "ran","rang","rao","re","ren","reng","ri","rong","rou","ru","rua","ruan","rui",
            "run","ruo",
            // s-group
            "sa","sai","san","sang","sao","se","sen","seng","sha","shai","shan","shang","shao",
            "she","shei","shen","sheng","shi","shou","shu","shua","shuai","shuan","shuang",
            "shui","shun","shuo","si","song","sou","su","suan","sui","sun","suo",
            // t-group
            "ta","tai","tan","tang","tao","te","tei","teng","ti","tian","tiao","tie","ting",
            "tong","tou","tu","tuan","tui","tun","tuo",
            // u (standalone) — handled via "wu" and "w" prefix
            "wa","wai","wan","wang","wei","wen","weng","wo","wu",
            // x-group
            "xi","xia","xian","xiang","xiao","xie","xin","xing","xiong","xiu","xu","xuan",
            "xue","xun",
            // y-group
            "ya","yan","yang","yao","ye","yi","yin","ying","yo","yong","you","yu","yuan",
            "yue","yun",
            // z-group
            "za","zai","zan","zang","zao","ze","zei","zen","zeng","zha","zhai","zhan","zhang",
            "zhao","zhe","zhei","zhen","zheng","zhi","zhong","zhou","zhu","zhua","zhuai","zhuan",
            "zhuang","zhui","zhun","zhuo","zi","zong","zou","zu","zuan","zui","zun","zuo",
        ]
        return Set(syllables)
    }()

    // Maximum Pinyin syllable length
    private static let maxSyllableLength = 6

    // MARK: - Segmentation

    /// Returns the best segmentation (greedy max-forward match).
    /// Falls back to shortest sub-word if no valid segmentation exists.
    func segment(_ input: String) -> [[String]] {
        let lower = input.lowercased()
        guard !lower.isEmpty else { return [] }

        // Try greedy max-forward first
        if let greedy = greedySegment(lower) {
            var results = [greedy]
            // Also try alternative segmentations for common ambiguities
            if let alt = alternativeSegment(lower, excluding: greedy) {
                results.append(alt)
            }
            return results
        }

        // Partial match: return whatever valid prefix we can
        if let partial = longestValidPrefix(lower) {
            return [partial]
        }

        return []
    }

    /// Returns true if the entire string is a valid Pinyin sequence.
    func isValidPinyin(_ input: String) -> Bool {
        let lower = input.lowercased()
        return greedySegment(lower) != nil
    }

    // MARK: - Private

    private func greedySegment(_ s: String) -> [String]? {
        var result: [String] = []
        var idx = s.startIndex
        while idx < s.endIndex {
            var matched = false
            let remaining = s[idx...]
            // Try longest match first
            for len in stride(from: min(Self.maxSyllableLength, remaining.count), through: 1, by: -1) {
                let end = s.index(idx, offsetBy: len, limitedBy: s.endIndex) ?? s.endIndex
                let sub = String(s[idx..<end])
                if Self.validSyllables.contains(sub) {
                    result.append(sub)
                    idx = end
                    matched = true
                    break
                }
            }
            if !matched { return nil }
        }
        return result.isEmpty ? nil : result
    }

    /// Try an alternative segmentation by not taking the longest match at position 0.
    private func alternativeSegment(_ s: String, excluding primary: [String]) -> [String]? {
        // Try all valid starting syllables of length < max
        guard let first = primary.first else { return nil }
        let maxLen = first.count

        for len in stride(from: maxLen - 1, through: 1, by: -1) {
            guard len <= s.count else { continue }
            let end = s.index(s.startIndex, offsetBy: len)
            let sub = String(s[s.startIndex..<end])
            guard Self.validSyllables.contains(sub) else { continue }
            let rest = String(s[end...])
            if let restSeg = greedySegment(rest) {
                let candidate = [sub] + restSeg
                if candidate != primary { return candidate }
            }
        }
        return nil
    }

    private func longestValidPrefix(_ s: String) -> [String]? {
        // Try segmenting increasing prefixes
        for len in stride(from: s.count, through: 1, by: -1) {
            let prefix = String(s.prefix(len))
            if let seg = greedySegment(prefix) {
                return seg
            }
        }
        return nil
    }
}
