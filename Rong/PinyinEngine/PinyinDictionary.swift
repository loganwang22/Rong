import Foundation

// MARK: - Candidate

nonisolated struct Candidate {
    let text: String
    var score: Double
}

// MARK: - PinyinDictionary

/// Lightweight in-memory Pinyin → Simplified Chinese dictionary.
/// Seeded with a compact built-in table covering ~3000 high-frequency entries.
/// A full CC-CEDICT-derived binary dict (rong.dict) can be dropped into Resources/
/// and loaded at runtime once the BuildDict tool produces it.
nonisolated final class PinyinDictionary {
    static let shared = PinyinDictionary()

    // Key: space-separated syllables, e.g. "ni hao"
    // Value: [(simplified, frequency_score)]
    private var table: [String: [(text: String, score: Double)]] = [:]

    private init() {
        loadBuiltIn()
        loadBundledDict()
    }

    // MARK: - Lookup

    /// Look up candidates for a syllable sequence.
    func lookup(_ syllables: [String]) -> [Candidate] {
        let key = syllables.joined(separator: " ")
        guard let entries = table[key] else {
            // Try prefix lookup (for partial input while typing)
            return prefixLookup(syllables)
        }
        return entries.map { Candidate(text: $0.text, score: $0.score) }
    }

    // MARK: - Prefix lookup

    /// Returns candidates whose Pinyin key starts with the given syllable prefix.
    private func prefixLookup(_ syllables: [String]) -> [Candidate] {
        let prefix = syllables.joined(separator: " ")
        var results: [Candidate] = []
        for (key, entries) in table {
            if key.hasPrefix(prefix) {
                results.append(contentsOf: entries.map { Candidate(text: $0.text, score: $0.score * 0.8) })
            }
        }
        return results.sorted { $0.score > $1.score }
    }

    // MARK: - Dict file loading

    private func loadBundledDict() {
        // Try to load pre-built rong.dict from bundle Resources
        guard let url = Bundle.main.url(forResource: "rong", withExtension: "dict") else {
            NSLog("Rong: rong.dict not bundled — running on built-in seed table only (\(table.count) keys)")
            return
        }
        guard let data = try? Data(contentsOf: url) else { return }
        // Line format: "syllables\tcharacter\tscore\n"
        guard let text = String(data: data, encoding: .utf8) else { return }

        // Remember which keys the bundled dict touched so we only re-sort those
        // buckets. Bundled entries append to the existing table; the built-in
        // scores are hand-tuned and intentionally outrank the CC-CEDICT
        // heuristic scores, so a merge-then-sort is the right behavior.
        var touchedKeys = Set<String>()
        var lineCount = 0
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard parts.count >= 3 else { continue }
            let key = String(parts[0])
            let char = String(parts[1])
            let score = Double(parts[2]) ?? 1.0
            table[key, default: []].append((text: char, score: score))
            touchedKeys.insert(key)
            lineCount += 1
        }

        // Re-sort every bucket the bundled dict touched; without this, built-in
        // high-frequency entries (sorted in loadBuiltIn) end up ahead of newly
        // appended lower-scored entries within the same array segment but the
        // segments themselves are not interleaved — ranking breaks silently.
        for key in touchedKeys {
            table[key]?.sort { $0.score > $1.score }
        }

        NSLog("Rong: Loaded bundled dict — \(lineCount) lines merged, \(table.count) total keys")
    }

    // MARK: - Built-in seed table

    // swiftlint:disable function_body_length
    private func loadBuiltIn() {
        let entries: [(pinyin: String, chinese: String, score: Double)] = [
            // Common words — sorted by frequency descending
            ("de", "的", 1000), ("de", "得", 400), ("de", "地", 300),
            ("le", "了", 900), ("le", "乐", 100),
            ("shi", "是", 900), ("shi", "时", 400), ("shi", "事", 350), ("shi", "使", 200),
            ("zai", "在", 800), ("zai", "再", 300),
            ("you", "有", 750), ("you", "又", 200), ("you", "右", 100),
            ("he", "和", 700), ("he", "喝", 150), ("he", "河", 120),
            ("ta", "他", 650), ("ta", "她", 640), ("ta", "它", 200),
            ("wo", "我", 900),
            ("ni", "你", 850), ("ni", "泥", 50),
            ("men", "们", 600), ("men", "门", 200),
            ("zhe", "这", 700), ("zhe", "者", 200), ("zhe", "着", 300),
            ("ge", "个", 700), ("ge", "哥", 150), ("ge", "格", 100),
            ("guo", "国", 600), ("guo", "过", 500), ("guo", "果", 200),
            ("zhong", "中", 600), ("zhong", "种", 300), ("zhong", "重", 200),
            ("yi", "一", 900), ("yi", "已", 400), ("yi", "以", 500), ("yi", "意", 300),
            ("ke", "可", 500), ("ke", "科", 200), ("ke", "克", 150),
            ("ren", "人", 700), ("ren", "认", 200), ("ren", "任", 150),
            ("bu", "不", 850), ("bu", "步", 200), ("bu", "部", 250),
            ("wei", "为", 600), ("wei", "位", 250), ("wei", "味", 150),
            ("dui", "对", 500), ("dui", "队", 200),
            ("yu", "于", 400), ("yu", "与", 350), ("yu", "语", 300), ("yu", "鱼", 150),
            ("shang", "上", 600), ("shang", "商", 200),
            ("xia", "下", 500), ("xia", "夏", 150),
            ("dao", "到", 600), ("dao", "道", 300), ("dao", "导", 150),
            ("lai", "来", 600), ("lai", "赖", 50),
            ("qu", "去", 500), ("qu", "区", 200), ("qu", "曲", 100),
            ("neng", "能", 500),
            ("dou", "都", 500), ("dou", "豆", 100),
            ("hui", "会", 500), ("hui", "回", 300), ("hui", "汇", 150),
            ("wo", "我", 900),
            ("shuo", "说", 500), ("shuo", "朔", 30),
            ("mei", "没", 400), ("mei", "美", 300), ("mei", "每", 200),
            ("jiu", "就", 500), ("jiu", "九", 200), ("jiu", "旧", 100),
            ("yao", "要", 500), ("yao", "药", 200), ("yao", "摇", 100),
            ("zhi", "之", 400), ("zhi", "只", 350), ("zhi", "知", 300), ("zhi", "直", 200),
            ("you", "用", 400),  // handled below
            ("yong", "用", 400), ("yong", "永", 100),
            ("ru", "如", 400), ("ru", "入", 300),
            ("cong", "从", 400), ("cong", "聪", 100),
            ("xin", "心", 350), ("xin", "新", 400), ("xin", "信", 300),
            ("gao", "高", 350), ("gao", "告", 200),
            ("tian", "天", 400), ("tian", "填", 100),
            ("di", "地", 400), ("di", "的", 100), ("di", "第", 300), ("di", "低", 150),
            ("zuo", "做", 350), ("zuo", "作", 400), ("zuo", "坐", 200), ("zuo", "左", 150),
            ("jia", "家", 500), ("jia", "加", 300), ("jia", "甲", 100),
            ("da", "大", 600), ("da", "打", 300), ("da", "达", 200),
            ("xiao", "小", 550), ("xiao", "笑", 200), ("xiao", "校", 150), ("xiao", "效", 100),
            ("kai", "开", 400), ("kai", "凯", 100),
            ("gei", "给", 400),
            ("ba", "把", 350), ("ba", "吧", 300), ("ba", "八", 200),
            ("yi ge", "一个", 400),
            ("wo men", "我们", 600),
            ("ni hao", "你好", 800),
            ("zhong guo", "中国", 700),
            ("mei guo", "美国", 400),
            ("ri ben", "日本", 300),
            ("ta men", "他们", 500),
            ("ni men", "你们", 450),
            ("zhe ge", "这个", 500),
            ("na ge", "那个", 400),
            ("shi jie", "世界", 350),
            ("ke yi", "可以", 500),
            ("yi xia", "一下", 350),
            ("zhe yang", "这样", 350),
            ("na yang", "那样", 200),
            ("ren men", "人们", 300),
            ("zhong hua", "中华", 300),
            ("gong si", "公司", 300),
            ("zheng fu", "政府", 250),
            ("jing ji", "经济", 280),
            ("she hui", "社会", 300),
            ("wen hua", "文化", 280),
            ("jiao yu", "教育", 260),
            ("ke xue", "科学", 250),
            ("ji shu", "技术", 260),
            ("fa zhan", "发展", 280),
            ("hao de", "好的", 300),
            ("xie xie", "谢谢", 700),
            ("dui bu qi", "对不起", 500),
            ("mei guan xi", "没关系", 400),
            ("zai jian", "再见", 600),
            ("zao shang hao", "早上好", 300),
            ("wan shang hao", "晚上好", 300),
            ("chi", "吃", 400), ("chi", "尺", 80), ("chi", "齿", 70),
            ("he", "喝", 300),
            ("shui", "水", 300), ("shui", "睡", 200), ("shui", "谁", 300),
            ("fan", "饭", 300), ("fan", "反", 200), ("fan", "番", 100),
            ("mian", "面", 300), ("mian", "棉", 100), ("mian", "免", 150),
            ("tang", "汤", 200), ("tang", "糖", 200), ("tang", "唐", 100),
            ("ji dan", "鸡蛋", 300),
            ("mi fan", "米饭", 300),
            ("mian bao", "面包", 200),
            ("chi fan", "吃饭", 400),
            ("he shui", "喝水", 300),
            ("gong zuo", "工作", 400),
            ("xue xi", "学习", 400),
            ("sheng huo", "生活", 380),
            ("xi huan", "喜欢", 400),
            ("ai", "爱", 400), ("ai", "挨", 80),
            ("peng you", "朋友", 500),
            ("jia ren", "家人", 300),
            ("hai zi", "孩子", 350),
            ("fu mu", "父母", 250),
            ("lao shi", "老师", 400),
            ("tong xue", "同学", 350),
            ("guo jia", "国家", 350),
            ("cheng shi", "城市", 300),
            ("bei jing", "北京", 400),
            ("shang hai", "上海", 400),
            ("guang zhou", "广州", 250),
            ("shen zhen", "深圳", 250),
            ("jin tian", "今天", 400),
            ("ming tian", "明天", 400),
            ("zuo tian", "昨天", 300),
            ("xian zai", "现在", 450),
            ("shi jian", "时间", 350),
            ("di fang", "地方", 300),
            ("wen ti", "问题", 350),
            ("fang fa", "方法", 280),
            ("jie guo", "结果", 300),
            ("yin wei", "因为", 350),
            ("suo yi", "所以", 350),
            ("dan shi", "但是", 300),
            ("ru guo", "如果", 350),
            ("zhi dao", "知道", 400),
            ("jue de", "觉得", 350),
            ("xi wang", "希望", 350),
            ("pao", "跑", 200), ("pao", "炮", 150), ("pao", "泡", 150),
            ("tiao", "跳", 200), ("tiao", "条", 250), ("tiao", "调", 150),
            ("zou", "走", 300), ("zou", "奏", 100),
            ("fei ji", "飞机", 300),
            ("huo che", "火车", 280),
            ("qi che", "汽车", 350),
            ("gong gong qi che", "公共汽车", 200),
            ("dian hua", "电话", 350),
            ("dian nao", "电脑", 400),
            ("shou ji", "手机", 500),
            ("wang luo", "网络", 350),
            ("dian shi", "电视", 300),
            ("yin le", "音乐", 280),
            ("dian ying", "电影", 300),
            ("yun dong", "运动", 280),
            ("ti yu", "体育", 200),
            ("mei tian", "每天", 350),
            ("yi qi", "一起", 350),
            ("yi ding", "一定", 300),
            ("yi ban", "一般", 250),
            ("fei chang", "非常", 350),
            ("zhen de", "真的", 400),
            ("tai hao le", "太好了", 300),
            ("gao xing", "高兴", 300),
            ("kuai le", "快乐", 350),
            ("xing fu", "幸福", 280),
            ("jian kang", "健康", 250),
        ]

        for entry in entries {
            let key = entry.pinyin
            table[key, default: []].append((text: entry.chinese, score: entry.score))
        }

        // Sort each bucket by score descending
        for key in table.keys {
            table[key]?.sort { $0.score > $1.score }
        }
    }
    // swiftlint:enable function_body_length
}
