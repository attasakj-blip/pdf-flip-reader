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
}
