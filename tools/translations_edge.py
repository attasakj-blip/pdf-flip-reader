"""Translations for text highlighting and the edge menus."""
LANGS = ['en', 'th', 'zh', 'zh_Hant', 'ja', 'ko', 'fr', 'de', 'it', 'es', 'pt', 'ru', 'uk', 'pl', 'nl', 'tr', 'ar',
         'hi', 'bn', 'id', 'ms', 'vi', 'fil']


def row(*values):
  assert len(values) == len(LANGS)
  return dict(zip(LANGS, values))


EDGE = {
    # Replaces the earlier label: the mode now covers highlighting too.
    'markup': row(
        'Draw, highlight and mark up', 'วาด ไฮไลท์ และทำเครื่องหมาย', '绘图、高亮和标注', '繪圖、螢光標示和標註',
        '描画・ハイライト・マークアップ', '그리기, 형광펜, 표시', 'Dessiner, surligner et annoter',
        'Zeichnen, hervorheben und markieren', 'Disegna, evidenzia e annota', 'Dibujar, resaltar y marcar',
        'Desenhar, destacar e marcar', 'Рисование, выделение и пометки', 'Малювання, виділення й позначки',
        'Rysuj, zakreślaj i zaznaczaj', 'Tekenen, markeren en aantekenen', 'Çiz, vurgula ve işaretle',
        'الرسم والتظليل والتعليق', 'ड्रॉ, हाइलाइट और मार्क करें', 'আঁকুন, হাইলাইট ও চিহ্নিত করুন',
        'Gambar, sorot, dan tandai', 'Lukis, serlah dan tanda', 'Vẽ, tô sáng và đánh dấu',
        'Gumuhit, mag-highlight at magmarka'),
    'toolTextHighlight': row(
        'Highlight text', 'ไฮไลท์ข้อความ', '高亮文字', '螢光標示文字', 'テキストをハイライト', '텍스트 형광펜',
        'Surligner le texte', 'Text hervorheben', 'Evidenzia testo', 'Resaltar texto', 'Destacar texto',
        'Выделить текст', 'Виділити текст', 'Zakreśl tekst', 'Tekst markeren', 'Metni vurgula', 'تظليل النص',
        'टेक्स्ट हाइलाइट करें', 'লেখা হাইলাইট করুন', 'Sorot teks', 'Serlah teks', 'Tô sáng văn bản',
        'I-highlight ang teksto'),
    'noTextHere': row(
        'No text to highlight on this page. Use the highlighter brush instead.',
        'หน้านี้ไม่มีข้อความให้ไฮไลท์ ใช้ปากกาเน้นข้อความระบายแทนได้',
        '此页没有可高亮的文字，请改用荧光笔涂抹。', '此頁沒有可標示的文字，請改用螢光筆塗抹。',
        'このページにはハイライトできる文字がありません。蛍光ペンで塗ってください。',
        '이 페이지에는 강조할 텍스트가 없습니다. 형광펜으로 칠해 주세요.',
        'Aucun texte à surligner sur cette page. Utilisez plutôt le surligneur.',
        'Auf dieser Seite gibt es keinen Text zum Hervorheben. Nutzen Sie stattdessen den Textmarker.',
        'Nessun testo da evidenziare in questa pagina. Usa invece l\'evidenziatore.',
        'No hay texto para resaltar en esta página. Usa el marcador.',
        'Não há texto para destacar nesta página. Use o marca-texto.',
        'На этой странице нет текста для выделения. Используйте маркер.',
        'На цій сторінці немає тексту для виділення. Скористайтеся маркером.',
        'Na tej stronie nie ma tekstu do zakreślenia. Użyj zakreślacza.',
        'Geen tekst om te markeren op deze pagina. Gebruik de markeerstift.',
        'Bu sayfada vurgulanacak metin yok. Bunun yerine fosforlu kalemi kullanın.',
        'لا يوجد نص لتظليله في هذه الصفحة. استخدم قلم التظليل بدلاً من ذلك.',
        'इस पेज पर हाइलाइट करने के लिए टेक्स्ट नहीं है। इसकी जगह हाइलाइटर ब्रश इस्तेमाल करें।',
        'এই পাতায় হাইলাইট করার মতো লেখা নেই। এর বদলে হাইলাইটার ব্যবহার করুন।',
        'Tidak ada teks untuk disorot di halaman ini. Gunakan stabilo.',
        'Tiada teks untuk diserlahkan di halaman ini. Gunakan pen penyerlah.',
        'Trang này không có văn bản để tô sáng. Hãy dùng bút dạ quang.',
        'Walang tekstong ma-highlight sa pahinang ito. Gamitin na lang ang highlighter.'),
    'edgeEditTitle': row(
        'Edit', 'แก้ไขเอกสาร', '编辑', '編輯', '編集', '편집', 'Modifier', 'Bearbeiten', 'Modifica', 'Editar',
        'Editar', 'Правка', 'Редагування', 'Edycja', 'Bewerken', 'Düzenle', 'تحرير', 'संपादन', 'সম্পাদনা',
        'Edit', 'Sunting', 'Chỉnh sửa', 'I-edit'),
    'edgeViewTitle': row(
        'Translate and view', 'แปลและการแสดงผล', '翻译和显示', '翻譯和顯示', '翻訳と表示', '번역 및 보기',
        'Traduire et afficher', 'Übersetzen und Ansicht', 'Traduci e visualizza', 'Traducir y ver',
        'Traduzir e exibir', 'Перевод и вид', 'Переклад і вигляд', 'Tłumacz i widok', 'Vertalen en weergave',
        'Çeviri ve görünüm', 'الترجمة والعرض', 'अनुवाद और दृश्य', 'অনুবাদ ও প্রদর্শন', 'Terjemahkan dan tampilan',
        'Terjemah dan paparan', 'Dịch và hiển thị', 'Isalin at tingnan'),
    'edgeTip': row(
        'Tip: swipe in from the left or right edge of the screen for quick menus.',
        'เคล็ดลับ: ปัดนิ้วจากขอบซ้ายหรือขอบขวาของจอเข้ามา เพื่อเปิดเมนูลัด',
        '提示：从屏幕左边或右边向内滑动，可打开快捷菜单。', '提示：從螢幕左邊或右邊向內滑動，可開啟快速選單。',
        'ヒント：画面の左端または右端から内側へスワイプすると、クイックメニューが開きます。',
        '팁: 화면 왼쪽이나 오른쪽 가장자리에서 안쪽으로 밀면 빠른 메뉴가 열립니다.',
        'Astuce : balayez depuis le bord gauche ou droit de l\'écran pour ouvrir les menus rapides.',
        'Tipp: Wischen Sie vom linken oder rechten Bildschirmrand nach innen, um Schnellmenüs zu öffnen.',
        'Suggerimento: scorri dal bordo sinistro o destro dello schermo per aprire i menu rapidi.',
        'Consejo: desliza desde el borde izquierdo o derecho de la pantalla para abrir los menús rápidos.',
        'Dica: deslize a partir da borda esquerda ou direita da tela para abrir os menus rápidos.',
        'Совет: проведите от левого или правого края экрана, чтобы открыть быстрые меню.',
        'Порада: проведіть від лівого або правого краю екрана, щоб відкрити швидкі меню.',
        'Wskazówka: przesuń palcem od lewej lub prawej krawędzi ekranu, aby otworzyć szybkie menu.',
        'Tip: veeg vanaf de linker- of rechterrand van het scherm voor snelmenu\'s.',
        'İpucu: hızlı menüler için ekranın sol veya sağ kenarından içeri kaydırın.',
        'تلميح: اسحب من الحافة اليسرى أو اليمنى للشاشة لفتح القوائم السريعة.',
        'सुझाव: त्वरित मेनू के लिए स्क्रीन के बाएँ या दाएँ किनारे से अंदर की ओर स्वाइप करें।',
        'টিপ: দ্রুত মেনুর জন্য স্ক্রিনের বাঁ বা ডান কিনারা থেকে ভেতরের দিকে সোয়াইপ করুন।',
        'Tips: geser dari tepi kiri atau kanan layar untuk membuka menu cepat.',
        'Petua: leret dari tepi kiri atau kanan skrin untuk membuka menu pantas.',
        'Mẹo: vuốt từ cạnh trái hoặc phải của màn hình vào trong để mở menu nhanh.',
        'Tip: mag-swipe mula sa kaliwa o kanang gilid ng screen para sa mabilisang menu.'),
}
