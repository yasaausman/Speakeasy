import Foundation

/// Starter prompts for the Home screen — they solve the "blank canvas" problem
/// (a voice/chat-first app where new users don't know what they can ask) by
/// showing a few concrete, tappable examples. Each is localized into the app's
/// languages so a non-English speaker sees the example in their own language;
/// unlisted languages fall back to English. Tapping a chip submits that goal
/// (the confirm gate still guards every call).
struct Suggestion: Identifiable {
    let id = UUID()
    let icon: String            // SF Symbol
    private let phrases: [String: String]  // language code → phrase

    /// The example phrase in the given language, English as the fallback.
    func text(for code: String) -> String { phrases[code] ?? phrases["en"] ?? "" }

    static func all() -> [Suggestion] { catalog }

    private static let catalog: [Suggestion] = [
        Suggestion(icon: "scissors", phrases: [
            "en": "Book a haircut",
            "es": "Reservar un corte de pelo",
            "zh": "预约理发",
            "hi": "बाल कटवाने की बुकिंग करें",
            "ar": "احجز موعد حلاقة",
            "vi": "Đặt lịch cắt tóc",
            "fr": "Réserver une coupe de cheveux",
            "pt": "Agendar um corte de cabelo",
            "ko": "이발 예약하기",
            "ru": "Записаться на стрижку",
        ]),
        Suggestion(icon: "takeoutbag.and.cup.and.straw.fill", phrases: [
            "en": "Order takeout",
            "es": "Pedir comida para llevar",
            "zh": "点外卖",
            "hi": "खाना ऑर्डर करें",
            "ar": "اطلب طعامًا",
            "vi": "Đặt đồ ăn mang về",
            "fr": "Commander à emporter",
            "pt": "Pedir comida para viagem",
            "ko": "음식 주문하기",
            "ru": "Заказать еду",
        ]),
        Suggestion(icon: "cross.case.fill", phrases: [
            "en": "Find a clinic near me",
            "es": "Buscar una clínica cerca",
            "zh": "查找附近的诊所",
            "hi": "पास की क्लिनिक खोजें",
            "ar": "ابحث عن عيادة قريبة",
            "vi": "Tìm phòng khám gần đây",
            "fr": "Trouver une clinique près de moi",
            "pt": "Encontrar uma clínica perto",
            "ko": "근처 병원 찾기",
            "ru": "Найти клинику рядом",
        ]),
        Suggestion(icon: "calendar.badge.plus", phrases: [
            "en": "Book a dentist appointment",
            "es": "Reservar cita con el dentista",
            "zh": "预约牙医",
            "hi": "डेंटिस्ट अपॉइंटमेंट बुक करें",
            "ar": "احجز موعدًا مع طبيب الأسنان",
            "vi": "Đặt lịch hẹn nha sĩ",
            "fr": "Prendre un rendez-vous dentiste",
            "pt": "Agendar consulta no dentista",
            "ko": "치과 예약하기",
            "ru": "Записаться к стоматологу",
        ]),
    ]
}

/// A short, friendly prompt shown above the starter chips, localized.
enum HomeGreeting {
    private static let byCode: [String: String] = [
        "en": "What can I help with?",
        "es": "¿En qué puedo ayudarte?",
        "zh": "有什么可以帮您的？",
        "hi": "मैं किसमें मदद करूँ?",
        "ar": "كيف يمكنني المساعدة؟",
        "vi": "Tôi có thể giúp gì cho bạn?",
        "fr": "Comment puis-je vous aider ?",
        "pt": "Como posso ajudar?",
        "ko": "무엇을 도와드릴까요?",
        "ru": "Чем я могу помочь?",
    ]
    static func text(for code: String) -> String { byCode[code] ?? byCode["en"]! }
}

/// The two prominent Home captions, localized so they don't sit in English right
/// next to the localized greeting and chips. English fallback for other languages.
enum HomeStrings {
    private static let hold: [String: String] = [
        "en": "Hold to speak — or type below",
        "es": "Mantén para hablar — o escribe abajo",
        "zh": "按住说话 — 或在下方输入",
        "hi": "बोलने के लिए दबाए रखें — या नीचे लिखें",
        "ar": "اضغط مطولًا للتحدث — أو اكتب بالأسفل",
        "vi": "Giữ để nói — hoặc nhập bên dưới",
        "fr": "Maintenez pour parler — ou écrivez ci-dessous",
        "pt": "Segure para falar — ou digite abaixo",
        "ko": "길게 눌러 말하기 — 또는 아래에 입력",
        "ru": "Удерживайте, чтобы говорить — или напишите ниже",
    ]
    private static let placeholder: [String: String] = [
        "en": "What do you need?",
        "es": "¿Qué necesitas?",
        "zh": "您需要什么？",
        "hi": "आपको क्या चाहिए?",
        "ar": "ماذا تحتاج؟",
        "vi": "Bạn cần gì?",
        "fr": "De quoi avez-vous besoin ?",
        "pt": "Do que você precisa?",
        "ko": "무엇이 필요하세요?",
        "ru": "Что вам нужно?",
    ]
    static func holdToSpeak(for code: String) -> String { hold[code] ?? hold["en"]! }
    static func inputPlaceholder(for code: String) -> String { placeholder[code] ?? placeholder["en"]! }
}
