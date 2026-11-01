"""Translations for choosing the page-turn style and the licences page."""
from translations_feedback import LANGS, row  # noqa: F401

FLIP = {
    'flipNone': row(
        'None (show the page straight away)', 'ไม่มีเอฟเฟกต์ (แสดงหน้าถัดไปทันที)', '无（直接显示页面）', '無（直接顯示頁面）',
        'なし（すぐにページを表示）', '없음 (바로 페이지 표시)', 'Aucune (afficher la page directement)',
        'Keine (Seite sofort zeigen)', 'Nessuna (mostra subito la pagina)', 'Ninguna (mostrar la página al instante)',
        'Nenhuma (mostrar a página na hora)', 'Нет (сразу показать страницу)', 'Немає (одразу показати сторінку)',
        'Brak (od razu pokaż stronę)', 'Geen (pagina meteen tonen)', 'Yok (sayfayı hemen göster)',
        'بدون (عرض الصفحة مباشرة)', 'कोई नहीं (पेज तुरंत दिखाएँ)', 'কোনোটি নয় (সঙ্গে সঙ্গে পৃষ্ঠা দেখাও)',
        'Tidak ada (langsung tampilkan halaman)', 'Tiada (terus papar halaman)', 'Không (hiện trang ngay)',
        'Wala (ipakita agad ang pahina)'),
    'flipCurl': row(
        'Corner curl', 'ม้วนมุมกระดาษ', '卷角翻页', '捲角翻頁', '角をめくる', '모서리 말림', 'Coin qui s’enroule',
        'Eselsohr-Umblättern', 'Angolo arrotolato', 'Esquina enrollada', 'Canto enrolado', 'Загиб уголка',
        'Загин кутика', 'Zawijany róg', 'Omkrullende hoek', 'Köşe kıvırma', 'طي الزاوية', 'कोना मोड़ना',
        'কোণ মোড়ানো', 'Lipatan sudut', 'Lipatan bucu', 'Cuộn góc', 'Pagkulot ng sulok'),
    'flipFold': row(
        'Straight fold', 'พับตรงแนวตั้ง', '竖直对折', '豎直對折', 'まっすぐ折る', '세로 접기', 'Pli droit',
        'Gerade Faltung', 'Piega dritta', 'Doblez recto', 'Dobra reta', 'Прямой сгиб', 'Прямий згин', 'Proste zgięcie',
        'Rechte vouw', 'Düz katlama', 'طي مستقيم', 'सीधा मोड़', 'সোজা ভাঁজ', 'Lipatan lurus', 'Lipatan lurus',
        'Gập thẳng', 'Tuwid na tiklop'),
    'flipSlide': row(
        'Slide', 'เลื่อนสไลด์', '滑动', '滑動', 'スライド', '슬라이드', 'Glissement', 'Schieben', 'Scorrimento',
        'Deslizar', 'Deslizar', 'Сдвиг', 'Зсув', 'Przesunięcie', 'Schuiven', 'Kaydırma', 'انزلاق', 'स्लाइड',
        'স্লাইড', 'Geser', 'Gelongsor', 'Trượt', 'Pag-slide'),
    'flipFade': row(
        'Cross-fade', 'จางซ้อน', '淡入淡出', '淡入淡出', 'クロスフェード', '크로스페이드', 'Fondu enchaîné',
        'Überblenden', 'Dissolvenza', 'Fundido', 'Transição suave', 'Плавная смена', 'Плавна зміна', 'Przenikanie',
        'Overvloeien', 'Geçişli solma', 'تلاشي متداخل', 'क्रॉस-फ़ेड', 'ক্রস-ফেড', 'Pudar silang', 'Pudar silang',
        'Mờ chuyển', 'Cross-fade'),
    'flipHinge': row(
        'Swing around the spine (3D)', 'หมุนรอบสันหนังสือ (3 มิติ)', '绕书脊翻转（3D）', '繞書脊翻轉（3D）',
        '背を軸に回転（3D）', '책등 회전 (3D)', 'Rotation autour du dos (3D)', 'Drehung um den Buchrücken (3D)',
        'Rotazione sul dorso (3D)', 'Giro sobre el lomo (3D)', 'Giro pela lombada (3D)', 'Поворот вокруг корешка (3D)',
        'Поворот навколо корінця (3D)', 'Obrót wokół grzbietu (3D)', 'Draaien om de rug (3D)', 'Sırt etrafında dönüş (3B)',
        'دوران حول كعب الكتاب (ثلاثي الأبعاد)', 'जिल्द के चारों ओर घुमाव (3D)', 'বাঁধাইয়ের চারপাশে ঘোরা (3D)',
        'Putar di punggung buku (3D)', 'Putar di tulang buku (3D)', 'Xoay quanh gáy sách (3D)',
        'Pag-ikot sa gulugod ng aklat (3D)'),
    'flipCover': row(
        'New page slides over', 'หน้าใหม่ซ้อนทับ', '新页覆盖', '新頁覆蓋', '新しいページが重なる', '새 페이지가 덮기',
        'La nouvelle page recouvre', 'Neue Seite schiebt sich darüber', 'La nuova pagina copre',
        'La página nueva se superpone', 'A nova página cobre', 'Новая страница наезжает', 'Нова сторінка насувається',
        'Nowa strona nachodzi', 'Nieuwe pagina schuift eroverheen', 'Yeni sayfa üstüne kayar', 'الصفحة الجديدة تغطي',
        'नया पेज ऊपर आता है', 'নতুন পৃষ্ঠা ওপরে আসে', 'Halaman baru menimpa', 'Halaman baharu menindih',
        'Trang mới phủ lên', 'Tumatakip ang bagong pahina'),
    'flipUncover': row(
        'Old page lifts away', 'ยกหน้าเดิมออก', '旧页移开', '舊頁移開', '前のページが離れる', '이전 페이지 걷어내기',
        'L’ancienne page s’écarte', 'Alte Seite hebt sich weg', 'La pagina precedente si alza',
        'La página anterior se aparta', 'A página anterior se afasta', 'Старая страница уходит', 'Стара сторінка відходить',
        'Stara strona odjeżdża', 'Oude pagina schuift weg', 'Eski sayfa kalkar', 'الصفحة القديمة تُرفع',
        'पुराना पेज हटता है', 'পুরনো পৃষ্ঠা সরে যায়', 'Halaman lama terangkat', 'Halaman lama terangkat',
        'Trang cũ nhấc ra', 'Umaalis ang lumang pahina'),
    'flipZoom': row(
        'Soft zoom and fade', 'ย่อจางนุ่ม ๆ', '柔和缩放淡出', '柔和縮放淡出', 'やわらかズーム', '부드러운 확대·페이드',
        'Zoom doux et fondu', 'Sanftes Zoomen und Blenden', 'Zoom morbido e dissolvenza', 'Zoom suave y fundido',
        'Zoom suave e esmaecer', 'Мягкий зум и затухание', 'М’який зум і згасання', 'Delikatny zoom i przenikanie',
        'Zacht zoomen en vervagen', 'Yumuşak yakınlaştırma', 'تكبير وتلاشٍ ناعم', 'हल्का ज़ूम और फ़ेड',
        'নরম জুম ও ফেড', 'Zoom lembut dan pudar', 'Zum lembut dan pudar', 'Thu phóng mờ nhẹ',
        'Malambot na zoom at fade'),
    'licenses': row(
        'Open-source licences', 'สัญญาอนุญาตโอเพนซอร์ส', '开源许可', '開源授權', 'オープンソースライセンス',
        '오픈소스 라이선스', 'Licences open source', 'Open-Source-Lizenzen', 'Licenze open source',
        'Licencias de código abierto', 'Licenças de código aberto', 'Лицензии open source',
        'Ліцензії open source', 'Licencje open source', 'Opensourcelicenties', 'Açık kaynak lisansları',
        'تراخيص المصادر المفتوحة', 'ओपन-सोर्स लाइसेंस', 'ওপেন-সোর্স লাইসেন্স', 'Lisensi sumber terbuka',
        'Lesen sumber terbuka', 'Giấy phép nguồn mở', 'Mga lisensiyang open-source'),
    'zoomIn': row(
        'Zoom in', 'ซูมเข้า', '放大', '放大', '拡大', '확대', 'Zoom avant', 'Vergrößern', 'Ingrandisci', 'Acercar',
        'Aumentar zoom', 'Увеличить', 'Збільшити', 'Powiększ', 'Inzoomen', 'Yakınlaştır', 'تكبير', 'ज़ूम इन',
        'জুম ইন', 'Perbesar', 'Zum masuk', 'Phóng to', 'Palakihin'),
    'zoomOut': row(
        'Zoom out', 'ซูมออก', '缩小', '縮小', '縮小', '축소', 'Zoom arrière', 'Verkleinern', 'Riduci', 'Alejar',
        'Diminuir zoom', 'Уменьшить', 'Зменшити', 'Pomniejsz', 'Uitzoomen', 'Uzaklaştır', 'تصغير', 'ज़ूम आउट',
        'জুম আউট', 'Perkecil', 'Zum keluar', 'Thu nhỏ', 'Paliitin'),
    'insertText': row(
        'Insert text', 'แทรกข้อความ', '插入文字', '插入文字', 'テキストを挿入', '텍스트 삽입', 'Insérer du texte',
        'Text einfügen', 'Inserisci testo', 'Insertar texto', 'Inserir texto', 'Вставить текст', 'Вставити текст',
        'Wstaw tekst', 'Tekst invoegen', 'Metin ekle', 'إدراج نص', 'टेक्स्ट डालें', 'লেখা যোগ করুন', 'Sisipkan teks',
        'Sisipkan teks', 'Chèn văn bản', 'Maglagay ng teksto'),
    'textHint': row(
        'Drag a text box to move it, drag its right handle to change the width',
        'ลากกล่องข้อความเพื่อย้าย ลากปุ่มด้านขวาเพื่อปรับความกว้าง',
        '拖动文本框可移动，拖动右侧手柄可改变宽度', '拖曳文字方塊可移動，拖曳右側控點可改變寬度',
        'テキストボックスをドラッグで移動、右のハンドルで幅を変更', '텍스트 상자를 끌어 이동하고 오른쪽 핸들로 너비를 바꾸세요',
        'Faites glisser une zone de texte pour la déplacer, et sa poignée droite pour changer la largeur',
        'Textfeld ziehen zum Verschieben, rechten Griff ziehen für die Breite',
        'Trascina una casella per spostarla, la maniglia destra per cambiarne la larghezza',
        'Arrastra un cuadro de texto para moverlo y su asa derecha para cambiar el ancho',
        'Arraste a caixa de texto para movê-la e a alça direita para mudar a largura',
        'Перетащите блок текста, чтобы переместить, и правый маркер, чтобы изменить ширину',
        'Перетягніть блок тексту, щоб перемістити, і правий маркер, щоб змінити ширину',
        'Przeciągnij pole tekstowe, aby je przesunąć, a prawy uchwyt, aby zmienić szerokość',
        'Sleep een tekstvak om het te verplaatsen, en de rechtergreep om de breedte te wijzigen',
        'Taşımak için metin kutusunu, genişlik için sağ tutamacı sürükleyin',
        'اسحب مربع النص لنقله، واسحب المقبض الأيمن لتغيير العرض',
        'टेक्स्ट बॉक्स को खिसकाने के लिए खींचें, चौड़ाई बदलने के लिए दायाँ हैंडल खींचें',
        'সরাতে লেখার বাক্স টানুন, প্রস্থ বদলাতে ডান হ্যান্ডেল টানুন',
        'Seret kotak teks untuk memindahkan, seret pegangan kanan untuk mengubah lebar',
        'Seret kotak teks untuk mengalih, seret pemegang kanan untuk menukar lebar',
        'Kéo hộp văn bản để di chuyển, kéo tay cầm bên phải để đổi độ rộng',
        'I-drag ang text box para ilipat, i-drag ang kanang hawakan para baguhin ang lapad'),
    'addText': row(
        'Add text', 'เพิ่มข้อความ', '添加文字', '新增文字', 'テキストを追加', '텍스트 추가', 'Ajouter du texte',
        'Text hinzufügen', 'Aggiungi testo', 'Añadir texto', 'Adicionar texto', 'Добавить текст', 'Додати текст',
        'Dodaj tekst', 'Tekst toevoegen', 'Metin ekle', 'إضافة نص', 'टेक्स्ट जोड़ें', 'লেখা যোগ করুন', 'Tambah teks',
        'Tambah teks', 'Thêm văn bản', 'Magdagdag ng teksto'),
    'fontName': row(
        'Font', 'ฟอนต์', '字体', '字型', 'フォント', '글꼴', 'Police', 'Schriftart', 'Carattere', 'Fuente', 'Fonte',
        'Шрифт', 'Шрифт', 'Czcionka', 'Lettertype', 'Yazı tipi', 'الخط', 'फ़ॉन्ट', 'ফন্ট', 'Font', 'Fon', 'Phông chữ',
        'Font'),
    'fontSize': row(
        'Size', 'ขนาด', '字号', '字級', 'サイズ', '크기', 'Taille', 'Größe', 'Dimensione', 'Tamaño', 'Tamanho', 'Размер',
        'Розмір', 'Rozmiar', 'Grootte', 'Boyut', 'الحجم', 'आकार', 'আকার', 'Ukuran', 'Saiz', 'Cỡ chữ', 'Laki'),
    'bold': row(
        'Bold', 'ตัวหนา', '加粗', '粗體', '太字', '굵게', 'Gras', 'Fett', 'Grassetto', 'Negrita', 'Negrito', 'Жирный',
        'Жирний', 'Pogrubienie', 'Vet', 'Kalın', 'غامق', 'बोल्ड', 'বোল্ড', 'Tebal', 'Tebal', 'Đậm', 'Bold'),
    'italic': row(
        'Italic', 'ตัวเอียง', '斜体', '斜體', '斜体', '기울임꼴', 'Italique', 'Kursiv', 'Corsivo', 'Cursiva', 'Itálico',
        'Курсив', 'Курсив', 'Kursywa', 'Cursief', 'İtalik', 'مائل', 'इटैलिक', 'ইটালিক', 'Miring', 'Condong', 'Nghiêng',
        'Italic'),
    'underline': row(
        'Underline', 'ขีดเส้นใต้', '下划线', '底線', '下線', '밑줄', 'Souligné', 'Unterstrichen', 'Sottolineato',
        'Subrayado', 'Sublinhado', 'Подчёркнутый', 'Підкреслений', 'Podkreślenie', 'Onderstrepen', 'Altı çizili',
        'تسطير', 'रेखांकित', 'নিচে দাগ', 'Garis bawah', 'Garis bawah', 'Gạch chân', 'Salungguhit'),
    'typeHere': row(
        'Type your text here', 'พิมพ์ข้อความที่นี่', '在此输入文字', '在此輸入文字', 'ここに入力', '여기에 입력하세요',
        'Tapez votre texte ici', 'Text hier eingeben', 'Scrivi qui il testo', 'Escribe aquí tu texto',
        'Digite seu texto aqui', 'Введите текст здесь', 'Введіть текст тут', 'Wpisz tutaj tekst', 'Typ hier je tekst',
        'Metninizi buraya yazın', 'اكتب النص هنا', 'यहाँ टेक्स्ट लिखें', 'এখানে লেখা টাইপ করুন', 'Ketik teks di sini',
        'Taip teks di sini', 'Nhập văn bản tại đây', 'I-type ang teksto rito'),
    'editText': row(
        'Edit text', 'แก้ไขข้อความ', '编辑文字', '編輯文字', 'テキストを編集', '텍스트 편집', 'Modifier le texte',
        'Text bearbeiten', 'Modifica testo', 'Editar texto', 'Editar texto', 'Изменить текст', 'Змінити текст',
        'Edytuj tekst', 'Tekst bewerken', 'Metni düzenle', 'تعديل النص', 'टेक्स्ट संपादित करें', 'লেখা সম্পাদনা',
        'Edit teks', 'Sunting teks', 'Sửa văn bản', 'I-edit ang teksto'),
    'stepText': row(
        'Text on page {n}', 'แทรกข้อความที่หน้า {n}', '第 {n} 页的文字', '第 {n} 頁的文字', '{n} ページのテキスト',
        '{n}페이지 텍스트', 'Texte sur la page {n}', 'Text auf Seite {n}', 'Testo a pagina {n}', 'Texto en la página {n}',
        'Texto na página {n}', 'Текст на стр. {n}', 'Текст на с. {n}', 'Tekst na stronie {n}', 'Tekst op pagina {n}',
        '{n}. sayfada metin', 'نص في الصفحة {n}', 'पेज {n} पर टेक्स्ट', 'পৃষ্ঠা {n}-এ লেখা', 'Teks di halaman {n}',
        'Teks di halaman {n}', 'Văn bản ở trang {n}', 'Teksto sa pahina {n}'),
}
