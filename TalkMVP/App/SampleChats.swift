//
//  SampleChats.swift
//  TalkMVP
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import Foundation

/// The chats test mode starts with: short conversations, so the chat list shows real previews
/// and unread counts from the first look. The other side writes in their own language; the
/// reader's lines are in the app's language, as if they had written them.
nonisolated enum SampleChats {
    enum Speaker: Equatable {
        case reader
        case person(String)

        /// Who wrote it, or nil for the reader.
        var name: String? {
            if case .person(let name) = self { name } else { nil }
        }
    }

    struct Line: Equatable {
        let speaker: Speaker
        let text: String
    }

    struct Room {
        /// The localization key of a group's name, or the key of a one-to-one room.
        let key: String
        /// The other person's name in a one-to-one room; nil for a group, which is named by `key`.
        let personName: String?
        let members: [String]
        /// How long ago the last message was sent.
        let minutesAgo: Int
        let lines: [Line]

        /// The messages after the reader's last one, which they haven't read.
        var unreadCount: Int { lines.reversed().prefix { $0.speaker != .reader }.count }
        var lastMessage: String { lines.last?.text ?? "" }
    }

    /// Minutes between one sample message and the next.
    static let minutesBetweenLines = 3

    /// The sample rooms, newest first, with the reader's lines in `readerLanguage` (English
    /// when the app doesn't speak it).
    static func rooms(readerLanguage: String) -> [Room] {
        let mine = readerLines[languageKey(readerLanguage)] ?? readerLines["en"] ?? [:]
        func reader(_ key: String, _ index: Int) -> Line { Line(speaker: .reader, text: mine[key]?[index] ?? "") }
        func line(_ name: String, _ text: String) -> Line { Line(speaker: .person(name), text: text) }

        return [
            Room(key: "study_group", personName: nil, members: TestData.groupMembers["study_group"] ?? [], minutesAgo: 5, lines: [
                line("佐藤ゆき", "来週の勉強会、何時から始めますか？"),
                line("Lucía García", "¿Qué tal el sábado a las tres de la tarde?"),
                reader("study_group", 0),
                line("佐藤ゆき", "了解です！資料を準備しておきますね 📚"),
                line("Lucía García", "¡Genial! Yo llevo café para todos ☕"),
            ]),
            Room(key: "family_group", personName: nil, members: TestData.groupMembers["family_group"] ?? [], minutesAgo: 40, lines: [
                line("한서연", "이번 주말에 다 같이 저녁 먹을까요?"),
                line("강민재", "좋아요! 토요일 어때요?"),
                reader("family_group", 0),
                line("한서연", "그럼 토요일 7시에 우리 집에서 봐요 🍲"),
            ]),
            Room(key: "minji", personName: "김민지", members: [], minutesAgo: 180, lines: [
                line("김민지", "안녕하세요! 지난주 합정 북카페 스터디에서 만난 민지예요 😊"),
                reader("minji", 0),
                line("김민지", "다음 모임에도 오실 거예요?"),
            ]),
            Room(key: "work_colleagues", personName: nil, members: TestData.groupMembers["work_colleagues"] ?? [], minutesAgo: 20 * 60, lines: [
                line("유지훈", "내일 회의 자료 방금 공유했어요. 7쪽부터 보시면 돼요."),
                reader("work_colleagues", 0),
                line("조하린", "발표는 제가 먼저 할게요."),
                reader("work_colleagues", 1),
            ]),
            // A long, unread planning chat: opening it offers the summary, and its dates, owners
            // and open question give the meeting notes something real to find.
            Room(key: "family_trip", personName: nil, members: TestData.groupMembers["family_trip"] ?? [], minutesAgo: 26 * 60, lines: [
                line("한서연", "다음 달 제주 여행 날짜 정해요! 12월 19일부터 22일까지 어때요?"),
                line("Emma Kang", "That works for me! I'll fly in from Los Angeles on the 18th."),
                reader("family_trip", 0),
                line("한서연", "숙소는 애월 쪽 펜션 두 곳 중에서 골라요."),
                line("Emma Kang", "The one with the ocean view looks great. Is it big enough for six people?"),
                line("한서연", "방이 세 개라 여섯 명 충분해요. 1박에 32만 원이에요."),
                line("Emma Kang", "Perfect. Can you book it by Friday? The price goes up after that."),
                line("한서연", "네, 금요일까지 제가 예약할게요."),
                line("Emma Kang", "I'll book the flights for Mom and Dad from Gimpo."),
                line("한서연", "고마워요! 할머니가 휠체어를 쓰셔서 공항 도움 서비스도 같이 신청해 줄 수 있어요?"),
                line("Emma Kang", "Of course, I'll request wheelchair assistance when I book the flights."),
                line("한서연", "첫날 저녁은 흑돼지 어때요? 식당은 제가 찾아볼게요."),
                line("Emma Kang", "Yes please! Does anyone know if we need to book the boat tour ahead of time?"),
                line("한서연", "그건 아직 모르겠어요. 누가 확인해 줄 수 있을까요?"),
            ]),
        ]
    }

    /// Traditional Chinese ("zh-Hant", or a Taiwan or Hong Kong code) has its own lines; other codes
    /// go by their language, so "zh-Hans" and "zh" share the Simplified ones.
    private static func languageKey(_ code: String) -> String {
        let lowered = code.lowercased()
        let traditional = ["zh-hant", "zh-tw", "zh-hk", "zh-mo"]
        if traditional.contains(where: { lowered.hasPrefix($0) }) { return "zh-Hant" }
        return String(lowered.prefix(2))
    }

    /// The reader's lines in each room, by language.
    private static let readerLines: [String: [String: [String]]] = [
        "en": [
            "study_group": ["Saturday at three works for me!"],
            "family_group": ["Saturday works for me, I'll bring dessert."],
            "minji": ["Hi Minji! It's good to hear from you."],
            "work_colleagues": ["Thanks, I'll read it tonight.", "Sounds good, see you at ten tomorrow."],
            "family_trip": ["The 19th works for me. I'll look into a rental car."],
        ],
        "ko": [
            "study_group": ["토요일 3시 좋아요!"],
            "family_group": ["토요일 좋아요, 디저트는 제가 가져갈게요."],
            "minji": ["민지 씨, 안녕하세요! 연락 주셔서 반가워요."],
            "work_colleagues": ["감사합니다, 오늘 밤에 읽어 볼게요.", "좋아요, 내일 10시에 봬요."],
            "family_trip": ["19일부터 좋아요. 렌터카는 제가 알아볼게요."],
        ],
        "ja": [
            "study_group": ["土曜日の3時で大丈夫です！"],
            "family_group": ["土曜日なら行けます、デザートを持っていきますね。"],
            "minji": ["ミンジさん、こんにちは！連絡ありがとうございます。"],
            "work_colleagues": ["ありがとうございます、今夜読んでおきます。", "いいですね、明日の10時に会いましょう。"],
            "family_trip": ["19日からで大丈夫です。レンタカーは私が調べておきますね。"],
        ],
        "zh": [
            "study_group": ["周六下午三点我可以！"],
            "family_group": ["周六我可以，我来带甜点。"],
            "minji": ["敏智你好！很高兴收到你的消息。"],
            "work_colleagues": ["谢谢，我今晚会看的。", "好的，明天十点见。"],
            "family_trip": ["19号开始我可以。租车的事我来查一下。"],
        ],
        "zh-Hant": [
            "study_group": ["週六下午三點我可以！"],
            "family_group": ["週六我可以，我來帶甜點。"],
            "minji": ["敏智你好！很高興收到你的訊息。"],
            "work_colleagues": ["謝謝，我今晚會看的。", "好的，明天十點見。"],
            "family_trip": ["19號開始我可以。租車的事我來查一下。"],
        ],
        "es": [
            "study_group": ["¡El sábado a las tres me viene bien!"],
            "family_group": ["El sábado me viene bien, yo llevo el postre."],
            "minji": ["¡Hola, Minji! Qué alegría saber de ti."],
            "work_colleagues": ["Gracias, lo leo esta noche.", "Perfecto, nos vemos mañana a las diez."],
            "family_trip": ["Desde el 19 me viene bien. Yo me encargo del coche de alquiler."],
        ],
    ]
}
