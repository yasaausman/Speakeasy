import Foundation

/// Localized UI chrome for the primary flow (confirm gate, live call, result), so a
/// language-first app doesn't show English buttons next to a translated readback.
/// Covers the app's languages with an English fallback for any not listed (Tagalog,
/// Haitian Creole) and for any missing key. Readbacks/outcomes are already translated
/// by the backend; this is only the on-device chrome.
enum LKey {
    case confirmTitle, addDetail, edit, yesCall
    case onTheCall, connecting
    case tryAgain, newRequest, play, stop
    case confirmation, addToCalendar, added
    case statusDone, statusNoAnswer, statusVoicemail, statusBusy, statusDeclined, statusFailed
}

enum L {
    static func t(_ key: LKey, _ code: String) -> String {
        let row = table[key] ?? [:]
        return row[code] ?? row["en"] ?? ""
    }

    private static let table: [LKey: [String: String]] = [
        .confirmTitle: ["en": "Did I get this right?", "es": "¿Entendí bien?", "zh": "我理解得对吗？", "hi": "क्या मैंने सही समझा?", "ar": "هل فهمت هذا بشكل صحيح؟", "vi": "Tôi hiểu đúng chứ?", "fr": "Ai-je bien compris ?", "pt": "Entendi certo?", "ko": "제가 맞게 이해했나요?", "ru": "Я правильно понял?"],
        .addDetail: ["en": "Add a detail", "es": "Añadir un detalle", "zh": "添加详情", "hi": "एक विवरण जोड़ें", "ar": "أضف تفصيلاً", "vi": "Thêm chi tiết", "fr": "Ajouter un détail", "pt": "Adicionar um detalhe", "ko": "세부 정보 추가", "ru": "Добавить деталь"],
        .edit: ["en": "Edit", "es": "Editar", "zh": "编辑", "hi": "बदलें", "ar": "تعديل", "vi": "Sửa", "fr": "Modifier", "pt": "Editar", "ko": "편집", "ru": "Изменить"],
        .yesCall: ["en": "Yes, call", "es": "Sí, llamar", "zh": "好的，拨打", "hi": "हाँ, कॉल करें", "ar": "نعم، اتصل", "vi": "Vâng, gọi", "fr": "Oui, appeler", "pt": "Sim, ligar", "ko": "네, 전화하기", "ru": "Да, позвонить"],
        .onTheCall: ["en": "On the call", "es": "En la llamada", "zh": "通话中", "hi": "कॉल पर", "ar": "أثناء المكالمة", "vi": "Đang gọi", "fr": "En appel", "pt": "Na chamada", "ko": "통화 중", "ru": "На связи"],
        .connecting: ["en": "Connecting…", "es": "Conectando…", "zh": "正在接通…", "hi": "कनेक्ट हो रहा है…", "ar": "جارٍ الاتصال…", "vi": "Đang kết nối…", "fr": "Connexion…", "pt": "Conectando…", "ko": "연결 중…", "ru": "Соединение…"],
        .tryAgain: ["en": "Try again", "es": "Intentar de nuevo", "zh": "重试", "hi": "फिर से कोशिश करें", "ar": "حاول مجددًا", "vi": "Thử lại", "fr": "Réessayer", "pt": "Tentar de novo", "ko": "다시 시도", "ru": "Повторить"],
        .newRequest: ["en": "New request", "es": "Nueva solicitud", "zh": "新请求", "hi": "नया अनुरोध", "ar": "طلب جديد", "vi": "Yêu cầu mới", "fr": "Nouvelle demande", "pt": "Nova solicitação", "ko": "새 요청", "ru": "Новый запрос"],
        .play: ["en": "Play narration", "es": "Reproducir", "zh": "播放", "hi": "सुनें", "ar": "تشغيل", "vi": "Phát", "fr": "Écouter", "pt": "Reproduzir", "ko": "재생", "ru": "Воспроизвести"],
        .stop: ["en": "Stop", "es": "Detener", "zh": "停止", "hi": "रोकें", "ar": "إيقاف", "vi": "Dừng", "fr": "Arrêter", "pt": "Parar", "ko": "정지", "ru": "Стоп"],
        .confirmation: ["en": "Confirmation", "es": "Confirmación", "zh": "确认号", "hi": "पुष्टि", "ar": "رقم التأكيد", "vi": "Xác nhận", "fr": "Confirmation", "pt": "Confirmação", "ko": "확인 번호", "ru": "Подтверждение"],
        .addToCalendar: ["en": "Add to Calendar", "es": "Añadir al calendario", "zh": "添加到日历", "hi": "कैलेंडर में जोड़ें", "ar": "أضف إلى التقويم", "vi": "Thêm vào lịch", "fr": "Ajouter au calendrier", "pt": "Adicionar à agenda", "ko": "캘린더에 추가", "ru": "В календарь"],
        .added: ["en": "Added", "es": "Añadido", "zh": "已添加", "hi": "जोड़ा गया", "ar": "تمت الإضافة", "vi": "Đã thêm", "fr": "Ajouté", "pt": "Adicionado", "ko": "추가됨", "ru": "Добавлено"],
        .statusDone: ["en": "Done", "es": "Listo", "zh": "完成", "hi": "हो गया", "ar": "تم", "vi": "Xong", "fr": "Terminé", "pt": "Concluído", "ko": "완료", "ru": "Готово"],
        .statusNoAnswer: ["en": "No answer", "es": "Sin respuesta", "zh": "无人接听", "hi": "कोई जवाब नहीं", "ar": "لا يوجد رد", "vi": "Không trả lời", "fr": "Pas de réponse", "pt": "Sem resposta", "ko": "응답 없음", "ru": "Нет ответа"],
        .statusVoicemail: ["en": "Voicemail", "es": "Buzón de voz", "zh": "语音信箱", "hi": "वॉइसमेल", "ar": "بريد صوتي", "vi": "Hộp thư thoại", "fr": "Messagerie vocale", "pt": "Correio de voz", "ko": "음성 메일", "ru": "Голосовая почта"],
        .statusBusy: ["en": "Line busy", "es": "Línea ocupada", "zh": "占线", "hi": "लाइन व्यस्त", "ar": "الخط مشغول", "vi": "Máy bận", "fr": "Ligne occupée", "pt": "Linha ocupada", "ko": "통화 중", "ru": "Линия занята"],
        .statusDeclined: ["en": "Declined", "es": "Rechazada", "zh": "已拒绝", "hi": "अस्वीकृत", "ar": "مرفوضة", "vi": "Bị từ chối", "fr": "Refusé", "pt": "Recusada", "ko": "거절됨", "ru": "Отклонено"],
        .statusFailed: ["en": "Couldn't finish", "es": "No se pudo completar", "zh": "未能完成", "hi": "पूरा नहीं हो सका", "ar": "تعذّر الإكمال", "vi": "Chưa hoàn tất", "fr": "Échec", "pt": "Não concluída", "ko": "완료하지 못함", "ru": "Не удалось"],
    ]
}
