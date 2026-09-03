import Foundation
import CoreFoundation
import NaturalLanguage

public final class Romanizer: @unchecked Sendable {
    public static let shared = Romanizer()
    
    // MARK: - Script Detection
    
    public static func hasHangul(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            (0xAC00...0xD7AF).contains(scalar.value) ||
            (0x1100...0x11FF).contains(scalar.value) ||
            (0x3130...0x318F).contains(scalar.value)
        }
    }
    
    public static func hasJapaneseKana(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            (0x3040...0x309F).contains(scalar.value) || // Hiragana
            (0x30A0...0x30FF).contains(scalar.value)    // Katakana
        }
    }
    
    public static func hasHanzi(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||
            (0x3400...0x4DBF).contains(scalar.value)
        }
    }
    
    public static func hasCyrillic(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            (0x0400...0x04FF).contains(scalar.value)
        }
    }
    
    public static func hasDevanagari(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            (0x0900...0x097F).contains(scalar.value)
        }
    }
    
    public static func hasGreek(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            (0x0370...0x03FF).contains(scalar.value)
        }
    }
    
    public static func needsRomanization(_ text: String) -> Bool {
        return hasHangul(text) || hasJapaneseKana(text) || hasHanzi(text) ||
               hasCyrillic(text) || hasDevanagari(text) || hasGreek(text)
    }

    // MARK: - Phonetic Maps
    
    private static let cyrillicMap: [Character: String] = [
        "А":"A","а":"a","Б":"B","б":"b","В":"V","в":"v","Г":"G","г":"g","Д":"D","д":"d",
        "Е":"E","е":"e","Ё":"Yo","ё":"yo","Ж":"Zh","ж":"zh","З":"Z","з":"z","И":"I","и":"i",
        "Й":"Y","й":"y","К":"K","к":"k","Л":"L","л":"l","М":"M","м":"m","Н":"N","н":"n",
        "О":"O","о":"o","П":"P","п":"p","Р":"R","р":"r","С":"S","с":"s","Т":"T","т":"t",
        "У":"U","у":"u","Ф":"F","ф":"f","Х":"Kh","х":"kh","Ц":"Ts","ц":"ts","Ч":"Ch","ч":"ch",
        "Ш":"Sh","ш":"sh","Щ":"Shch","щ":"shch","Ъ":"","ъ":"","Ы":"Y","ы":"y","Ь":"","ь":"",
        "Э":"E","э":"e","Ю":"Yu","ю":"yu","Я":"Ya","я":"ya",
        "І":"I","і":"i","Ї":"Yi","ї":"yi","Є":"Ye","є":"ye","Ґ":"G","ґ":"g"
    ]
    
    private static let devanagariMap: [Character: String] = [
        "अ":"a","आ":"aa","इ":"i","ई":"ee","उ":"u","ऊ":"oo","ऋ":"ri","ए":"e","ऐ":"ai","ओ":"o","औ":"au",
        "क":"ka","ख":"kha","ग":"ga","घ":"gha","ङ":"nga",
        "च":"cha","छ":"chha","ज":"ja","झ":"jha","ञ":"nya",
        "ट":"ta","ठ":"tha","ड":"da","ढ":"dha","ण":"na",
        "त":"ta","थ":"tha","द":"da","ध":"dha","न":"na",
        "प":"pa","फ":"pha","ब":"ba","भ":"bha","म":"ma",
        "य":"ya","र":"ra","ल":"la","व":"va","श":"sha","ष":"sha","स":"sa","ह":"ha",
        "ा":"a","ि":"i","ी":"ee","ु":"u","ू":"oo","ृ":"ri","े":"e","ै":"ai","ो":"o","ौ":"au",
        "ं":"n","ः":"h","्":"","़":""
    ]
    
    private static let greekMap: [Character: String] = [
        "Α":"A","α":"a","Β":"V","β":"v","Γ":"G","γ":"g","Δ":"D","δ":"d","Ε":"E","ε":"e",
        "Ζ":"Z","ζ":"z","Η":"I","η":"i","Θ":"Th","θ":"th","Ι":"I","ι":"i","Κ":"K","κ":"k",
        "Λ":"L","λ":"l","Μ":"M","μ":"m","Ν":"N","ν":"n","Ξ":"X","ξ":"x","Ο":"O","ο":"o",
        "Π":"P","π":"p","Ρ":"R","р":"r","Σ":"S","σ":"s","ς":"s","Τ":"T","τ":"t","Υ":"Y","υ":"y",
        "Φ":"F","φ":"f","Χ":"Ch","χ":"ch","Ψ":"Ps","ψ":"ps","Ω":"O","ω":"o"
    ]

    // MARK: - Korean Romanizer Engine (Revised Romanization of Korean)
    
    private static let krChoseong: [String] = [
        "g", "kk", "n", "d", "tt", "r", "m", "b", "pp", "s", "ss", "", "j", "jj", "ch", "k", "t", "p", "h"
    ]
    
    private static let krJungseong: [String] = [
        "a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae", "oe", "yo", "u", "wo", "we", "wi", "yu", "eu", "ui", "i"
    ]
    
    private static let krJongseong: [String] = [
        "", "k", "k", "k", "n", "n", "n", "t", "l", "k", "m", "l", "l", "l", "p", "l", "m", "p", "p", "t", "t", "ng", "t", "t", "k", "t", "p", "t"
    ]
    
    private struct KrSyllable {
        let initial: Int
        let vowel: Int
        let final: Int
        let isHangul: Bool
        let rawChar: Character
    }
    
    private static func decomposeHangul(_ char: Character) -> KrSyllable {
        guard let scalar = char.unicodeScalars.first,
              scalar.value >= 0xAC00 && scalar.value <= 0xD7A3 else {
            return KrSyllable(initial: -1, vowel: -1, final: -1, isHangul: false, rawChar: char)
        }
        let code = Int(scalar.value - 0xAC00)
        let initial = code / (21 * 28)
        let vowel = (code % (21 * 28)) / 28
        let final = code % 28
        return KrSyllable(initial: initial, vowel: vowel, final: final, isHangul: true, rawChar: char)
    }
    
    private static func romanizeHangulWord(_ word: String) -> String {
        let chars = Array(word)
        let syllables = chars.map { decomposeHangul($0) }
        var result = ""
        
        for i in 0..<syllables.count {
            let curr = syllables[i]
            if !curr.isHangul {
                result.append(curr.rawChar)
                continue
            }
            
            let next = (i + 1 < syllables.count) ? syllables[i + 1] : nil
            
            // 1. Initial consonant sound
            var initSound = krChoseong[curr.initial]
            if curr.initial == 5 { // ㄹ
                initSound = "r"
            }
            
            // Aspiration from preceding final consonant ㅎ
            if i > 0 && syllables[i - 1].isHangul && syllables[i - 1].final == 27 {
                if curr.initial == 0 { initSound = "k" }
                else if curr.initial == 3 { initSound = "t" }
                else if curr.initial == 7 { initSound = "p" }
                else if curr.initial == 12 { initSound = "ch" }
            }
            
            // 2. Vowel sound
            let vowelSound = krJungseong[curr.vowel]
            
            // 3. Final consonant sound (Batchim)
            var finalSound = krJongseong[curr.final]
            
            if curr.final != 0, let next = next, next.isHangul {
                // Next syllable has empty initial ㅇ (Index 11) -> Resyllabification / Liaison
                if next.initial == 11 {
                    switch curr.final {
                    case 1: finalSound = ""
                    case 7: finalSound = ""
                    case 8: finalSound = ""
                    case 16: finalSound = ""
                    case 17: finalSound = ""
                    case 19: finalSound = ""
                    case 20: finalSound = ""
                    case 22: finalSound = ""
                    case 23: finalSound = ""
                    case 25: finalSound = ""
                    case 26: finalSound = ""
                    case 27: finalSound = "" // ㅎ before vowel is silent
                    case 3: finalSound = "k" // ㄳ -> k + s
                    case 5: finalSound = "n" // ㄵ -> n + j
                    case 6: finalSound = "n" // ㄶ -> n
                    case 9: finalSound = "l" // ㄺ -> l + g
                    case 10: finalSound = "l" // ㄻ -> l + m
                    case 11: finalSound = "l" // ㄼ -> l + b
                    case 18: finalSound = "p" // ㅄ -> p + s
                    default: break
                    }
                }
                // Palatalization: ㄷ, ㅌ + 이 -> ji, chi
                else if (curr.final == 7 || curr.final == 25) && next.initial == 11 && next.vowel == 20 {
                    finalSound = ""
                }
                // Aspiration: final consonant + initial ㅎ
                else if (curr.final == 1 || curr.final == 7 || curr.final == 17 || curr.final == 22) && next.initial == 18 {
                    finalSound = ""
                }
                // Final ㅎ + initial ㄱ, ㄷ, ㅂ, ㅈ -> aspirated into next syllable
                else if curr.final == 27 && (next.initial == 0 || next.initial == 3 || next.initial == 7 || next.initial == 12) {
                    finalSound = ""
                }
                // Liquid assimilation: ㄴ + ㄹ -> ll, ㄹ + ㄴ -> ll
                else if curr.final == 4 && next.initial == 5 {
                    finalSound = "l"
                }
                else if curr.final == 8 && next.initial == 2 {
                    finalSound = "l"
                }
                // Nasalization before ㄴ, ㅁ
                else if (curr.final == 1 || curr.final == 2 || curr.final == 24) && (next.initial == 2 || next.initial == 6) {
                    finalSound = "ng"
                }
                else if (curr.final == 7 || curr.final == 19 || curr.final == 20 || curr.final == 22 || curr.final == 23 || curr.final == 25) && (next.initial == 2 || next.initial == 6) {
                    finalSound = "n"
                }
                else if (curr.final == 17 || curr.final == 26) && (next.initial == 2 || next.initial == 6) {
                    finalSound = "m"
                }
                // Nasalization before ㄹ
                else if (curr.final == 1 || curr.final == 17 || curr.final == 21 || curr.final == 16) && next.initial == 5 {
                    if curr.final == 1 { finalSound = "ng" }
                    else if curr.final == 17 { finalSound = "m" }
                }
            }
            
            // Consonant carried over from previous syllable
            if i > 0 && syllables[i - 1].isHangul && curr.initial == 11 {
                let prev = syllables[i - 1]
                switch prev.final {
                case 1: initSound = "g"
                case 7: initSound = (curr.vowel == 20) ? "j" : "d"
                case 8: initSound = "r"
                case 16: initSound = "m"
                case 17: initSound = "b"
                case 19: initSound = "s"
                case 20: initSound = "ss"
                case 22: initSound = "j"
                case 23: initSound = "ch"
                case 25: initSound = (curr.vowel == 20) ? "ch" : "t"
                case 26: initSound = "p"
                case 3: initSound = "s"
                case 5: initSound = "j"
                case 9: initSound = "g"
                case 10: initSound = "m"
                case 11: initSound = "b"
                case 18: initSound = "s"
                default: break
                }
            }
            // Liquid assimilation on next syllable initial
            else if i > 0 && syllables[i - 1].isHangul {
                let prev = syllables[i - 1]
                if prev.final == 4 && curr.initial == 5 {
                    initSound = "l"
                } else if (prev.final == 1 || prev.final == 17 || prev.final == 21 || prev.final == 16) && curr.initial == 5 {
                    initSound = "n"
                }
            }
            
            result.append(initSound + vowelSound + finalSound)
        }
        return result
    }
    
    public static func romanizeKorean(_ text: String) -> String {
        var output = ""
        var currentHangulWord = ""
        
        for ch in text {
            if let scalar = ch.unicodeScalars.first, scalar.value >= 0xAC00 && scalar.value <= 0xD7A3 {
                currentHangulWord.append(ch)
            } else {
                if !currentHangulWord.isEmpty {
                    output.append(romanizeHangulWord(currentHangulWord))
                    currentHangulWord = ""
                }
                output.append(ch)
            }
        }
        if !currentHangulWord.isEmpty {
            output.append(romanizeHangulWord(currentHangulWord))
        }
        return output
    }

    // MARK: - Japanese Romanizer Engine (Morphological CFStringTokenizer)
    
    public static func romanizeJapanese(_ text: String) -> String {
        let cfStr = text as CFString
        let length = CFStringGetLength(cfStr)
        guard length > 0 else { return text }
        let range = CFRangeMake(0, length)
        let locale = CFLocaleCreate(kCFAllocatorDefault, CFLocaleIdentifier("ja_JP" as CFString))
        guard let tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, cfStr, range, kCFStringTokenizerUnitWordBoundary, locale) else {
            return text
        }
        
        var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        var result = ""
        var lastEnd = 0
        
        while tokenType != [] {
            let tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            
            if tokenRange.location > lastEnd {
                let gapRange = CFRangeMake(lastEnd, tokenRange.location - lastEnd)
                let gap = CFStringCreateWithSubstring(kCFAllocatorDefault, cfStr, gapRange) as String
                result.append(gap)
            }
            
            let rawSub = CFStringCreateWithSubstring(kCFAllocatorDefault, cfStr, tokenRange) as String
            
            // Only transliterate if token contains Japanese/CJK characters
            if (hasJapaneseKana(rawSub) || hasHanzi(rawSub)),
               let latinRef = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String {
                var latin = latinRef.precomposedStringWithCanonicalMapping
                
                // Normalizing long vowels / macrons
                latin = latin.replacingOccurrences(of: "ō", with: "ou")
                latin = latin.replacingOccurrences(of: "ū", with: "uu")
                latin = latin.replacingOccurrences(of: "ā", with: "aa")
                latin = latin.replacingOccurrences(of: "ī", with: "ii")
                latin = latin.replacingOccurrences(of: "ē", with: "ee")
                latin = latin.replacingOccurrences(of: "Ō", with: "Ou")
                latin = latin.replacingOccurrences(of: "Ū", with: "Uu")
                latin = latin.replacingOccurrences(of: "Ā", with: "Aa")
                latin = latin.replacingOccurrences(of: "Ī", with: "Ii")
                latin = latin.replacingOccurrences(of: "Ē", with: "Ee")
                latin = latin.replacingOccurrences(of: "\u{0304}", with: "")
                
                // Japanese lyric particle & reading refinements
                if rawSub == "は" && (latin == "ha" || latin == "wa") {
                    latin = "wa"
                }
                if rawSub == "を" && (latin == "wo" || latin == "o") {
                    latin = "wo"
                }
                if rawSub == "へ" && latin == "he" {
                    latin = "e"
                }
                if rawSub == "私" && latin == "watakushi" {
                    latin = "watashi"
                }
                if rawSub == "明日" && (latin == "asu" || latin == "myounichi") {
                    latin = "ashita"
                }
                if rawSub == "君" && latin == "kun" {
                    latin = "kimi"
                }
                
                if let lastChar = result.last, (lastChar.isLetter || lastChar.isNumber) {
                    result.append(" ")
                }
                result.append(latin)
            } else {
                result.append(rawSub)
            }
            
            lastEnd = tokenRange.location + tokenRange.length
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }
        
        if lastEnd < length {
            let remRange = CFRangeMake(lastEnd, length - lastEnd)
            let rem = CFStringCreateWithSubstring(kCFAllocatorDefault, cfStr, remRange) as String
            result.append(rem)
        }
        
        return result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Chinese Romanizer Engine (Pinyin with Word Segmentation)
    
    public static func romanizeChinese(_ text: String) -> String {
        let cfStr = text as CFString
        let length = CFStringGetLength(cfStr)
        guard length > 0 else { return text }
        let range = CFRangeMake(0, length)
        let locale = CFLocaleCreate(kCFAllocatorDefault, CFLocaleIdentifier("zh_CN" as CFString))
        guard let tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, cfStr, range, kCFStringTokenizerUnitWordBoundary, locale) else {
            return text
        }
        
        var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        var result = ""
        var lastEnd = 0
        
        while tokenType != [] {
            let tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            
            if tokenRange.location > lastEnd {
                let gapRange = CFRangeMake(lastEnd, tokenRange.location - lastEnd)
                let gap = CFStringCreateWithSubstring(kCFAllocatorDefault, cfStr, gapRange) as String
                result.append(gap)
            }
            
            let rawSub = CFStringCreateWithSubstring(kCFAllocatorDefault, cfStr, tokenRange) as String
            
            if hasHanzi(rawSub),
               let latinRef = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String {
                let ms = NSMutableString(string: latinRef)
                CFStringTransform(ms, nil, kCFStringTransformStripDiacritics, false)
                let latin = (ms as String).replacingOccurrences(of: "\u{0304}|\u{0301}|\u{030c}|\u{0300}", with: "", options: .regularExpression)
                
                if let lastChar = result.last, (lastChar.isLetter || lastChar.isNumber) {
                    result.append(" ")
                }
                result.append(latin)
            } else {
                result.append(rawSub)
            }
            
            lastEnd = tokenRange.location + tokenRange.length
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }
        
        if lastEnd < length {
            let remRange = CFRangeMake(lastEnd, length - lastEnd)
            let rem = CFStringCreateWithSubstring(kCFAllocatorDefault, cfStr, remRange) as String
            result.append(rem)
        }
        
        return result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Cyrillic, Devanagari, Greek
    
    public static func romanizeCyrillic(_ text: String) -> String {
        return String(text.map { cyrillicMap[$0] ?? String($0) }.joined())
    }
    
    private static let devanagariScalarMap: [UInt32: String] = [
        0x0905:"a",0x0906:"aa",0x0907:"i",0x0908:"ee",0x0909:"u",0x090A:"oo",0x090B:"ri",0x090F:"e",0x0910:"ai",0x0913:"o",0x0914:"au",
        0x0915:"ka",0x0916:"kha",0x0917:"ga",0x0918:"gha",0x0919:"nga",
        0x091A:"cha",0x091B:"chha",0x091C:"ja",0x091D:"jha",0x091E:"nya",
        0x091F:"ta",0x0920:"tha",0x0921:"da",0x0922:"dha",0x0923:"na",
        0x0924:"ta",0x0925:"tha",0x0926:"da",0x0927:"dha",0x0928:"na",
        0x092A:"pa",0x092B:"pha",0x092C:"ba",0x092D:"bha",0x092E:"ma",
        0x092F:"ya",0x0930:"ra",0x0932:"la",0x0935:"va",0x0936:"sha",0x0937:"sha",0x0938:"sa",0x0939:"ha",
        0x093E:"a",0x093F:"i",0x0940:"ee",0x0941:"u",0x0942:"oo",0x0943:"ri",0x0947:"e",0x0948:"ai",0x094B:"o",0x094C:"au",
        0x0902:"n",0x0903:"h",0x094D:"",0x093C:""
    ]

    public static func romanizeDevanagari(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var result = ""
        var i = 0
        while i < scalars.count {
            let sc = scalars[i].value
            let next = (i + 1 < scalars.count) ? scalars[i + 1].value : 0
            if let mapped = devanagariScalarMap[sc], mapped.hasSuffix("a"), next == 0x094D {
                result.append(String(mapped.dropLast()))
                i += 2
                continue
            }
            if let mapped = devanagariScalarMap[sc], mapped.hasSuffix("a"), let nextMapped = devanagariScalarMap[next], (0x093E...0x094C).contains(next) {
                result.append(String(mapped.dropLast()) + nextMapped)
                i += 2
                continue
            }
            if let mapped = devanagariScalarMap[sc] {
                result.append(mapped)
            } else if let uni = UnicodeScalar(sc) {
                result.append(String(uni))
            }
            i += 1
        }
        return result
    }
    
    public static func romanizeGreek(_ text: String) -> String {
        return String(text.map { greekMap[$0] ?? String($0) }.joined())
    }

    // MARK: - Unified Single Line & Multi-Line Romanization
    
    public static func romanizeText(_ text: String, preferredLanguage: String? = nil) -> String {
        guard !text.isEmpty else { return text }
        
        if hasHangul(text) {
            return romanizeKorean(text)
        }
        if hasJapaneseKana(text) {
            return romanizeJapanese(text)
        }
        if hasDevanagari(text) {
            return romanizeDevanagari(text)
        }
        if hasCyrillic(text) {
            return romanizeCyrillic(text)
        }
        if hasGreek(text) {
            return romanizeGreek(text)
        }
        if hasHanzi(text) {
            if preferredLanguage == "ja" {
                return romanizeJapanese(text)
            } else {
                return romanizeChinese(text)
            }
        }
        return text
    }
    
    public static func romanizeLines(_ lines: [LyricLine]) -> [LyricLine] {
        let allText = lines.map { $0.text }.joined(separator: "\n")
        let songHasKana = hasJapaneseKana(allText)
        let songHasHanzi = hasHanzi(allText)
        
        var preferredLang: String? = nil
        if songHasKana {
            preferredLang = "ja"
        } else if songHasHanzi {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(allText)
            if recognizer.dominantLanguage == .japanese {
                preferredLang = "ja"
            } else {
                preferredLang = "zh"
            }
        }
        
        var hasChanges = false
        var result: [LyricLine] = []
        
        for line in lines {
            let rom = romanizeText(line.text, preferredLanguage: preferredLang)
            if rom != line.text {
                hasChanges = true
            }
            result.append(LyricLine(timestamp: line.timestamp, text: rom))
        }
        
        return hasChanges ? result : []
    }
}
