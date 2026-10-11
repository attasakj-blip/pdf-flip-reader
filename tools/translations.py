"""Source of the app's UI translations. Run to regenerate lib/strings.g.dart.

Placeholders: {x} folder, {n} page, {e} error, {range} {total} pages.
"""
import json
import pathlib

KEYS = [
    'pickPdf', 'pickHint', 'recent', 'unknownFolder', 'folder', 'readTo', 'removeFromList',
    'fileMissing', 'openFailed', 'flipSoundMenu', 'exitApp', 'language', 'systemLanguage',
    'pageLabel', 'backToFiles', 'singlePage', 'twoPage', 'goToPageMenu', 'coverAlone',
    'otherFile', 'soundSwitch', 'volume', 'preview', 'gotoTitle', 'gotoError', 'cancel', 'go',
    's1', 's2', 's3', 's4', 's5', 's6', 's7', 's8', 's9', 's10',
]

# code: (native name, [values in KEYS order])
LANGS = {
    'en': ('English', [
        'Choose a PDF file', 'Pick any folder and file in your phone\'s file picker', 'Recent',
        'Unknown folder', 'Folder: {x}', 'Stopped at page {n}', 'Remove from list',
        'This file is no longer available. Please choose it again.', 'Could not open the file: {e}',
        'Page-turn sound', 'Exit app', 'Language', 'Phone language',
        'Page {range} / {total}', 'Back to files', 'Single page', 'Two pages', 'Go to page…',
        'Show cover on its own', 'Open another file', 'Page-turn sound', 'Volume', 'Play sound',
        'Which page do you want to go to?', 'Enter a page from 1 to {total}', 'Cancel', 'Go',
        'Paperback', 'Thin paper', 'Hardcover', 'Old book', 'Glossy magazine', 'Quick flick',
        'Slow turn', 'Fluttering page', 'Board book', 'Notebook']),
    'th': ('ไทย', [
        'เลือกไฟล์ PDF จากเครื่อง', 'เลือกโฟลเดอร์และไฟล์ได้จากหน้าต่างเลือกไฟล์ของมือถือ', 'เปิดล่าสุด',
        'ไม่ทราบโฟลเดอร์', 'โฟลเดอร์: {x}', 'อ่านถึงหน้า {n}', 'ลบออกจากรายการ',
        'ไม่พบไฟล์นี้แล้ว กรุณาเลือกไฟล์ใหม่อีกครั้ง', 'เปิดไฟล์ไม่ได้: {e}',
        'เสียงพลิกหน้า', 'ออกจากแอป', 'ภาษา', 'ตามภาษาของเครื่อง',
        'หน้า {range} / {total}', 'กลับไปเลือกไฟล์', 'หน้าเดี่ยว', 'หน้าคู่', 'ไปที่หน้า…',
        'หน้าปกแสดงเดี่ยว', 'เลือกไฟล์อื่น', 'เสียงพลิกหน้ากระดาษ', 'ความดัง', 'ฟังเสียง',
        'ต้องการไปที่หน้าที่เท่าไหร่?', 'ใส่เลขหน้า 1 ถึง {total}', 'ยกเลิก', 'ไป',
        'หนังสือปกอ่อน', 'กระดาษบาง', 'หนังสือปกแข็ง', 'หนังสือเก่า', 'นิตยสารกระดาษมัน', 'พลิกเร็ว',
        'พลิกช้าๆ', 'กระดาษปลิว', 'หนังสือกระดาษแข็ง', 'สมุดโน้ต']),
    'zh': ('简体中文', [
        '选择 PDF 文件', '在手机的文件选择器中选择任意文件夹和文件', '最近打开',
        '未知文件夹', '文件夹：{x}', '读到第 {n} 页', '从列表中移除',
        '找不到此文件，请重新选择。', '无法打开文件：{e}',
        '翻页音效', '退出应用', '语言', '跟随手机语言',
        '第 {range} 页 / 共 {total} 页', '返回文件列表', '单页', '双页', '跳转到页面…',
        '封面单独显示', '打开其他文件', '翻页音效', '音量', '试听',
        '要跳转到第几页？', '请输入 1 到 {total} 之间的页码', '取消', '跳转',
        '平装书', '薄纸', '精装书', '旧书', '铜版纸杂志', '快速翻页',
        '慢慢翻页', '纸页飘动', '硬纸板书', '笔记本']),
    'zh_Hant': ('繁體中文', [
        '選擇 PDF 檔案', '在手機的檔案選擇器中選擇任何資料夾和檔案', '最近開啟',
        '未知資料夾', '資料夾：{x}', '讀到第 {n} 頁', '從清單中移除',
        '找不到此檔案，請重新選擇。', '無法開啟檔案：{e}',
        '翻頁音效', '結束應用程式', '語言', '跟隨手機語言',
        '第 {range} 頁 / 共 {total} 頁', '返回檔案清單', '單頁', '雙頁', '跳至頁面…',
        '封面單獨顯示', '開啟其他檔案', '翻頁音效', '音量', '試聽',
        '要跳到第幾頁？', '請輸入 1 到 {total} 之間的頁碼', '取消', '前往',
        '平裝書', '薄紙', '精裝書', '舊書', '亮面雜誌', '快速翻頁',
        '慢慢翻頁', '紙頁飄動', '硬紙板書', '筆記本']),
    'ja': ('日本語', [
        'PDF ファイルを選ぶ', 'スマホのファイル選択画面で、フォルダとファイルを選べます', '最近開いたファイル',
        'フォルダ不明', 'フォルダ：{x}', '{n} ページまで読みました', 'リストから削除',
        'このファイルが見つかりません。もう一度選んでください。', 'ファイルを開けませんでした：{e}',
        'ページめくり音', 'アプリを終了', '言語', '端末の言語',
        '{range} ページ / 全 {total} ページ', 'ファイル選択に戻る', '単ページ', '見開き', 'ページへ移動…',
        '表紙を単独で表示', '別のファイルを開く', 'ページめくり音', '音量', '試聴',
        '何ページに移動しますか？', '1〜{total} のページ番号を入力してください', 'キャンセル', '移動',
        'ペーパーバック', '薄い紙', 'ハードカバー', '古い本', '光沢紙の雑誌', 'すばやくめくる',
        'ゆっくりめくる', 'ひらひら舞う紙', 'ボードブック', 'ノート']),
    'ko': ('한국어', [
        'PDF 파일 선택', '휴대폰 파일 선택 창에서 원하는 폴더와 파일을 고르세요', '최근 파일',
        '알 수 없는 폴더', '폴더: {x}', '{n}페이지까지 읽음', '목록에서 삭제',
        '이 파일을 더 이상 찾을 수 없습니다. 다시 선택해 주세요.', '파일을 열 수 없습니다: {e}',
        '페이지 넘김 소리', '앱 종료', '언어', '휴대폰 언어 따르기',
        '{range}페이지 / 총 {total}페이지', '파일 목록으로', '한 페이지', '두 페이지', '페이지로 이동…',
        '표지만 따로 보기', '다른 파일 열기', '페이지 넘김 소리', '음량', '미리 듣기',
        '몇 페이지로 이동할까요?', '1부터 {total}까지 페이지 번호를 입력하세요', '취소', '이동',
        '페이퍼백', '얇은 종이', '양장본', '오래된 책', '광택지 잡지', '빠르게 넘기기',
        '천천히 넘기기', '팔랑이는 종이', '보드북', '공책']),
    'fr': ('Français', [
        'Choisir un fichier PDF', 'Choisissez n\'importe quel dossier et fichier dans le sélecteur du téléphone', 'Récents',
        'Dossier inconnu', 'Dossier : {x}', 'Arrêté à la page {n}', 'Retirer de la liste',
        'Ce fichier n\'est plus disponible. Veuillez le choisir à nouveau.', 'Impossible d\'ouvrir le fichier : {e}',
        'Son de page', 'Quitter l\'application', 'Langue', 'Langue du téléphone',
        'Page {range} / {total}', 'Retour aux fichiers', 'Page simple', 'Double page', 'Aller à la page…',
        'Afficher la couverture seule', 'Ouvrir un autre fichier', 'Son de page tournée', 'Volume', 'Écouter',
        'À quelle page voulez-vous aller ?', 'Saisissez une page entre 1 et {total}', 'Annuler', 'Aller',
        'Livre de poche', 'Papier fin', 'Livre relié', 'Vieux livre', 'Magazine glacé', 'Tourner vite',
        'Tourner lentement', 'Page qui virevolte', 'Livre cartonné', 'Cahier']),
    'de': ('Deutsch', [
        'PDF-Datei auswählen', 'Wählen Sie im Dateiauswahlfenster des Telefons einen beliebigen Ordner und eine Datei', 'Zuletzt geöffnet',
        'Unbekannter Ordner', 'Ordner: {x}', 'Gelesen bis Seite {n}', 'Aus Liste entfernen',
        'Diese Datei ist nicht mehr verfügbar. Bitte wählen Sie sie erneut aus.', 'Datei konnte nicht geöffnet werden: {e}',
        'Blätterton', 'App beenden', 'Sprache', 'Telefonsprache',
        'Seite {range} / {total}', 'Zurück zu den Dateien', 'Einzelseite', 'Doppelseite', 'Gehe zu Seite…',
        'Titelseite einzeln anzeigen', 'Andere Datei öffnen', 'Blätterton', 'Lautstärke', 'Anhören',
        'Zu welcher Seite möchten Sie springen?', 'Geben Sie eine Seite von 1 bis {total} ein', 'Abbrechen', 'Los',
        'Taschenbuch', 'Dünnes Papier', 'Gebundenes Buch', 'Altes Buch', 'Hochglanzmagazin', 'Schnell blättern',
        'Langsam blättern', 'Flatterndes Blatt', 'Pappbilderbuch', 'Notizbuch']),
    'it': ('Italiano', [
        'Scegli un file PDF', 'Scegli qualsiasi cartella e file dal selettore del telefono', 'Recenti',
        'Cartella sconosciuta', 'Cartella: {x}', 'Fermato a pagina {n}', 'Rimuovi dall\'elenco',
        'Questo file non è più disponibile. Sceglilo di nuovo.', 'Impossibile aprire il file: {e}',
        'Suono della pagina', 'Esci dall\'app', 'Lingua', 'Lingua del telefono',
        'Pagina {range} / {total}', 'Torna ai file', 'Pagina singola', 'Pagina doppia', 'Vai alla pagina…',
        'Mostra la copertina da sola', 'Apri un altro file', 'Suono della pagina', 'Volume', 'Ascolta',
        'A quale pagina vuoi andare?', 'Inserisci una pagina da 1 a {total}', 'Annulla', 'Vai',
        'Tascabile', 'Carta sottile', 'Libro rilegato', 'Libro antico', 'Rivista patinata', 'Sfogliata veloce',
        'Sfogliata lenta', 'Pagina svolazzante', 'Libro cartonato', 'Quaderno']),
    'es': ('Español', [
        'Elegir un archivo PDF', 'Elige cualquier carpeta y archivo en el selector del teléfono', 'Recientes',
        'Carpeta desconocida', 'Carpeta: {x}', 'Leído hasta la página {n}', 'Quitar de la lista',
        'Este archivo ya no está disponible. Vuelve a elegirlo.', 'No se pudo abrir el archivo: {e}',
        'Sonido de página', 'Salir de la app', 'Idioma', 'Idioma del teléfono',
        'Página {range} / {total}', 'Volver a los archivos', 'Una página', 'Dos páginas', 'Ir a la página…',
        'Mostrar la portada sola', 'Abrir otro archivo', 'Sonido al pasar página', 'Volumen', 'Escuchar',
        '¿A qué página quieres ir?', 'Introduce una página del 1 al {total}', 'Cancelar', 'Ir',
        'Libro de bolsillo', 'Papel fino', 'Tapa dura', 'Libro antiguo', 'Revista satinada', 'Pasar rápido',
        'Pasar despacio', 'Hoja al viento', 'Libro de cartón', 'Cuaderno']),
    'pt': ('Português', [
        'Escolher um arquivo PDF', 'Escolha qualquer pasta e arquivo no seletor do telefone', 'Recentes',
        'Pasta desconhecida', 'Pasta: {x}', 'Parou na página {n}', 'Remover da lista',
        'Este arquivo não está mais disponível. Escolha-o novamente.', 'Não foi possível abrir o arquivo: {e}',
        'Som da página', 'Sair do app', 'Idioma', 'Idioma do telefone',
        'Página {range} / {total}', 'Voltar aos arquivos', 'Página única', 'Duas páginas', 'Ir para a página…',
        'Mostrar a capa sozinha', 'Abrir outro arquivo', 'Som ao virar a página', 'Volume', 'Ouvir',
        'Para qual página você quer ir?', 'Digite uma página de 1 a {total}', 'Cancelar', 'Ir',
        'Brochura', 'Papel fino', 'Capa dura', 'Livro antigo', 'Revista brilhante', 'Virar rápido',
        'Virar devagar', 'Folha ao vento', 'Livro cartonado', 'Caderno']),
    'ru': ('Русский', [
        'Выбрать PDF-файл', 'Выберите любую папку и файл в окне выбора файлов телефона', 'Недавние',
        'Неизвестная папка', 'Папка: {x}', 'Остановились на странице {n}', 'Удалить из списка',
        'Этот файл больше недоступен. Выберите его снова.', 'Не удалось открыть файл: {e}',
        'Звук страницы', 'Выйти из приложения', 'Язык', 'Язык телефона',
        'Стр. {range} / {total}', 'Назад к файлам', 'Одна страница', 'Разворот', 'Перейти к странице…',
        'Показывать обложку отдельно', 'Открыть другой файл', 'Звук перелистывания', 'Громкость', 'Прослушать',
        'На какую страницу перейти?', 'Введите номер страницы от 1 до {total}', 'Отмена', 'Перейти',
        'Мягкая обложка', 'Тонкая бумага', 'Твёрдая обложка', 'Старая книга', 'Глянцевый журнал', 'Быстро',
        'Медленно', 'Порхающий лист', 'Картонная книжка', 'Тетрадь']),
    'uk': ('Українська', [
        'Вибрати PDF-файл', 'Виберіть будь-яку папку та файл у вікні вибору файлів телефона', 'Нещодавні',
        'Невідома папка', 'Папка: {x}', 'Зупинилися на сторінці {n}', 'Видалити зі списку',
        'Цей файл більше недоступний. Виберіть його знову.', 'Не вдалося відкрити файл: {e}',
        'Звук сторінки', 'Вийти з додатка', 'Мова', 'Мова телефона',
        'Стор. {range} / {total}', 'Назад до файлів', 'Одна сторінка', 'Розворот', 'Перейти до сторінки…',
        'Показувати обкладинку окремо', 'Відкрити інший файл', 'Звук гортання', 'Гучність', 'Прослухати',
        'На яку сторінку перейти?', 'Введіть номер сторінки від 1 до {total}', 'Скасувати', 'Перейти',
        'М\'яка обкладинка', 'Тонкий папір', 'Тверда обкладинка', 'Стара книга', 'Глянцевий журнал', 'Швидко',
        'Повільно', 'Пурхаючий аркуш', 'Картонна книжка', 'Зошит']),
    'pl': ('Polski', [
        'Wybierz plik PDF', 'Wybierz dowolny folder i plik w oknie wyboru plików telefonu', 'Ostatnie',
        'Nieznany folder', 'Folder: {x}', 'Przeczytano do strony {n}', 'Usuń z listy',
        'Ten plik nie jest już dostępny. Wybierz go ponownie.', 'Nie udało się otworzyć pliku: {e}',
        'Dźwięk strony', 'Zamknij aplikację', 'Język', 'Język telefonu',
        'Strona {range} / {total}', 'Wróć do plików', 'Jedna strona', 'Dwie strony', 'Przejdź do strony…',
        'Pokaż okładkę osobno', 'Otwórz inny plik', 'Dźwięk przewracania', 'Głośność', 'Odsłuchaj',
        'Do której strony przejść?', 'Wpisz numer strony od 1 do {total}', 'Anuluj', 'Przejdź',
        'Miękka okładka', 'Cienki papier', 'Twarda okładka', 'Stara książka', 'Błyszczący magazyn', 'Szybko',
        'Powoli', 'Fruwająca kartka', 'Książeczka kartonowa', 'Zeszyt']),
    'nl': ('Nederlands', [
        'Kies een pdf-bestand', 'Kies elke map en elk bestand in de bestandskiezer van je telefoon', 'Recent',
        'Onbekende map', 'Map: {x}', 'Gestopt bij pagina {n}', 'Uit lijst verwijderen',
        'Dit bestand is niet meer beschikbaar. Kies het opnieuw.', 'Kan het bestand niet openen: {e}',
        'Bladergeluid', 'App afsluiten', 'Taal', 'Taal van telefoon',
        'Pagina {range} / {total}', 'Terug naar bestanden', 'Eén pagina', 'Twee pagina\'s', 'Ga naar pagina…',
        'Omslag apart tonen', 'Ander bestand openen', 'Bladergeluid', 'Volume', 'Beluisteren',
        'Naar welke pagina wil je gaan?', 'Voer een pagina in van 1 tot {total}', 'Annuleren', 'Ga',
        'Paperback', 'Dun papier', 'Gebonden boek', 'Oud boek', 'Glossy tijdschrift', 'Snel bladeren',
        'Langzaam bladeren', 'Fladderend blad', 'Kartonboek', 'Schrift']),
    'tr': ('Türkçe', [
        'PDF dosyası seç', 'Telefonun dosya seçicisinden istediğiniz klasörü ve dosyayı seçin', 'Son açılanlar',
        'Bilinmeyen klasör', 'Klasör: {x}', '{n}. sayfada kalındı', 'Listeden kaldır',
        'Bu dosya artık mevcut değil. Lütfen yeniden seçin.', 'Dosya açılamadı: {e}',
        'Sayfa sesi', 'Uygulamadan çık', 'Dil', 'Telefonun dili',
        'Sayfa {range} / {total}', 'Dosyalara dön', 'Tek sayfa', 'Çift sayfa', 'Sayfaya git…',
        'Kapağı tek göster', 'Başka dosya aç', 'Sayfa çevirme sesi', 'Ses düzeyi', 'Dinle',
        'Hangi sayfaya gitmek istiyorsunuz?', '1 ile {total} arasında bir sayfa girin', 'İptal', 'Git',
        'Karton kapak', 'İnce kâğıt', 'Ciltli kitap', 'Eski kitap', 'Parlak dergi', 'Hızlı çevirme',
        'Yavaş çevirme', 'Uçuşan sayfa', 'Karton kitap', 'Defter']),
    'ar': ('العربية', [
        'اختيار ملف PDF', 'اختر أي مجلد وملف من أداة اختيار الملفات في هاتفك', 'الملفات الأخيرة',
        'مجلد غير معروف', 'المجلد: {x}', 'توقفت عند الصفحة {n}', 'إزالة من القائمة',
        'هذا الملف لم يعد متاحًا. يرجى اختياره مرة أخرى.', 'تعذّر فتح الملف: {e}',
        'صوت تقليب الصفحة', 'الخروج من التطبيق', 'اللغة', 'لغة الهاتف',
        'الصفحة {range} / {total}', 'العودة إلى الملفات', 'صفحة واحدة', 'صفحتان', 'الانتقال إلى صفحة…',
        'عرض الغلاف وحده', 'فتح ملف آخر', 'صوت تقليب الصفحة', 'مستوى الصوت', 'استماع',
        'إلى أي صفحة تريد الانتقال؟', 'أدخل رقم صفحة من 1 إلى {total}', 'إلغاء', 'انتقال',
        'كتاب ورقي الغلاف', 'ورق رقيق', 'غلاف مقوّى', 'كتاب قديم', 'مجلة لامعة', 'تقليب سريع',
        'تقليب بطيء', 'ورقة متطايرة', 'كتاب من الورق المقوّى', 'دفتر']),
    'hi': ('हिन्दी', [
        'PDF फ़ाइल चुनें', 'फ़ोन के फ़ाइल चयन से कोई भी फ़ोल्डर और फ़ाइल चुनें', 'हाल की फ़ाइलें',
        'अज्ञात फ़ोल्डर', 'फ़ोल्डर: {x}', 'पेज {n} तक पढ़ा', 'सूची से हटाएँ',
        'यह फ़ाइल अब उपलब्ध नहीं है। कृपया इसे फिर से चुनें।', 'फ़ाइल नहीं खुल सकी: {e}',
        'पेज पलटने की आवाज़', 'ऐप बंद करें', 'भाषा', 'फ़ोन की भाषा',
        'पेज {range} / {total}', 'फ़ाइलों पर वापस', 'एक पेज', 'दो पेज', 'पेज पर जाएँ…',
        'कवर अकेले दिखाएँ', 'दूसरी फ़ाइल खोलें', 'पेज पलटने की आवाज़', 'आवाज़', 'सुनें',
        'किस पेज पर जाना है?', '1 से {total} तक पेज नंबर डालें', 'रद्द करें', 'जाएँ',
        'पेपरबैक', 'पतला कागज़', 'हार्डकवर', 'पुरानी किताब', 'चमकदार पत्रिका', 'तेज़ी से पलटना',
        'धीरे पलटना', 'उड़ता पन्ना', 'बोर्ड बुक', 'नोटबुक']),
    'bn': ('বাংলা', [
        'PDF ফাইল বেছে নিন', 'ফোনের ফাইল নির্বাচক থেকে যেকোনো ফোল্ডার ও ফাইল বেছে নিন', 'সাম্প্রতিক',
        'অজানা ফোল্ডার', 'ফোল্ডার: {x}', '{n} পৃষ্ঠা পর্যন্ত পড়া হয়েছে', 'তালিকা থেকে সরান',
        'এই ফাইলটি আর পাওয়া যাচ্ছে না। আবার বেছে নিন।', 'ফাইল খোলা যায়নি: {e}',
        'পাতা ওল্টানোর শব্দ', 'অ্যাপ বন্ধ করুন', 'ভাষা', 'ফোনের ভাষা',
        'পৃষ্ঠা {range} / {total}', 'ফাইলে ফিরে যান', 'এক পৃষ্ঠা', 'দুই পৃষ্ঠা', 'পৃষ্ঠায় যান…',
        'প্রচ্ছদ আলাদা দেখান', 'অন্য ফাইল খুলুন', 'পাতা ওল্টানোর শব্দ', 'শব্দের মাত্রা', 'শুনুন',
        'কোন পৃষ্ঠায় যেতে চান?', '1 থেকে {total} পর্যন্ত পৃষ্ঠা নম্বর লিখুন', 'বাতিল', 'যান',
        'পেপারব্যাক', 'পাতলা কাগজ', 'হার্ডকভার', 'পুরোনো বই', 'চকচকে পত্রিকা', 'দ্রুত ওল্টানো',
        'ধীরে ওল্টানো', 'উড়ন্ত পাতা', 'বোর্ড বই', 'খাতা']),
    'id': ('Bahasa Indonesia', [
        'Pilih file PDF', 'Pilih folder dan file apa saja di pemilih file ponsel', 'Terbaru',
        'Folder tidak diketahui', 'Folder: {x}', 'Terakhir di halaman {n}', 'Hapus dari daftar',
        'File ini tidak tersedia lagi. Silakan pilih lagi.', 'Tidak dapat membuka file: {e}',
        'Suara halaman', 'Keluar aplikasi', 'Bahasa', 'Bahasa ponsel',
        'Halaman {range} / {total}', 'Kembali ke file', 'Satu halaman', 'Dua halaman', 'Buka halaman…',
        'Tampilkan sampul sendiri', 'Buka file lain', 'Suara membalik halaman', 'Volume', 'Dengarkan',
        'Mau ke halaman berapa?', 'Masukkan halaman 1 sampai {total}', 'Batal', 'Buka',
        'Buku saku', 'Kertas tipis', 'Sampul keras', 'Buku tua', 'Majalah mengilap', 'Balik cepat',
        'Balik pelan', 'Kertas melayang', 'Buku karton', 'Buku catatan']),
    'ms': ('Bahasa Melayu', [
        'Pilih fail PDF', 'Pilih mana-mana folder dan fail dalam pemilih fail telefon', 'Terkini',
        'Folder tidak diketahui', 'Folder: {x}', 'Berhenti di halaman {n}', 'Buang daripada senarai',
        'Fail ini tidak lagi tersedia. Sila pilih semula.', 'Tidak dapat membuka fail: {e}',
        'Bunyi halaman', 'Keluar aplikasi', 'Bahasa', 'Bahasa telefon',
        'Halaman {range} / {total}', 'Kembali ke fail', 'Satu halaman', 'Dua halaman', 'Pergi ke halaman…',
        'Tunjukkan kulit buku sahaja', 'Buka fail lain', 'Bunyi selak halaman', 'Kelantangan', 'Dengar',
        'Mahu ke halaman berapa?', 'Masukkan halaman 1 hingga {total}', 'Batal', 'Pergi',
        'Buku kulit lembut', 'Kertas nipis', 'Kulit keras', 'Buku lama', 'Majalah berkilat', 'Selak pantas',
        'Selak perlahan', 'Kertas berterbangan', 'Buku kadbod', 'Buku nota']),
    'vi': ('Tiếng Việt', [
        'Chọn tệp PDF', 'Chọn bất kỳ thư mục và tệp nào trong trình chọn tệp của điện thoại', 'Gần đây',
        'Thư mục không xác định', 'Thư mục: {x}', 'Đã đọc đến trang {n}', 'Xóa khỏi danh sách',
        'Tệp này không còn nữa. Vui lòng chọn lại.', 'Không mở được tệp: {e}',
        'Âm thanh lật trang', 'Thoát ứng dụng', 'Ngôn ngữ', 'Ngôn ngữ của điện thoại',
        'Trang {range} / {total}', 'Quay lại danh sách tệp', 'Một trang', 'Hai trang', 'Đến trang…',
        'Hiển thị bìa riêng', 'Mở tệp khác', 'Âm thanh lật trang', 'Âm lượng', 'Nghe thử',
        'Bạn muốn đến trang nào?', 'Nhập số trang từ 1 đến {total}', 'Hủy', 'Đi',
        'Sách bìa mềm', 'Giấy mỏng', 'Sách bìa cứng', 'Sách cũ', 'Tạp chí giấy bóng', 'Lật nhanh',
        'Lật chậm', 'Trang giấy bay', 'Sách bìa cứng cho bé', 'Vở ghi']),
    'fil': ('Filipino', [
        'Pumili ng PDF file', 'Pumili ng anumang folder at file sa file picker ng telepono', 'Kamakailan',
        'Hindi kilalang folder', 'Folder: {x}', 'Huminto sa pahina {n}', 'Alisin sa listahan',
        'Wala na ang file na ito. Pakipili itong muli.', 'Hindi mabuksan ang file: {e}',
        'Tunog ng pahina', 'Lumabas sa app', 'Wika', 'Wika ng telepono',
        'Pahina {range} / {total}', 'Bumalik sa mga file', 'Isang pahina', 'Dalawang pahina', 'Pumunta sa pahina…',
        'Ipakita nang hiwalay ang pabalat', 'Magbukas ng ibang file', 'Tunog ng paglipat ng pahina', 'Lakas ng tunog', 'Pakinggan',
        'Saang pahina mo gustong pumunta?', 'Maglagay ng pahina mula 1 hanggang {total}', 'Kanselahin', 'Pumunta',
        'Paperback', 'Manipis na papel', 'Hardcover', 'Lumang libro', 'Makintab na magasin', 'Mabilis na lipat',
        'Mabagal na lipat', 'Lumilipad na pahina', 'Board book', 'Kuwaderno']),
}


# Keys added after the first release: key -> {code: value}. Appended to KEYS.
ADDED = {
    'rtlPages': {
        'en': 'Turn pages right to left', 'th': 'พลิกหน้าจากขวาไปซ้าย', 'zh': '从右向左翻页',
        'zh_Hant': '由右向左翻頁', 'ja': '右から左へめくる', 'ko': '오른쪽에서 왼쪽으로 넘기기',
        'fr': 'Tourner les pages de droite à gauche', 'de': 'Von rechts nach links blättern',
        'it': 'Sfoglia da destra a sinistra', 'es': 'Pasar páginas de derecha a izquierda',
        'pt': 'Virar páginas da direita para a esquerda', 'ru': 'Листать справа налево',
        'uk': 'Гортати справа наліво', 'pl': 'Przewracaj strony od prawej do lewej',
        'nl': "Pagina's van rechts naar links omslaan", 'tr': 'Sayfaları sağdan sola çevir',
        'ar': 'تقليب الصفحات من اليمين إلى اليسار', 'hi': 'पन्ने दाएँ से बाएँ पलटें',
        'bn': 'ডান থেকে বামে পাতা উল্টান', 'id': 'Balik halaman dari kanan ke kiri',
        'ms': 'Selak halaman dari kanan ke kiri', 'vi': 'Lật trang từ phải sang trái',
        'fil': 'Ilipat ang pahina mula kanan pakaliwa',
    },
    'nightMode': {
        'en': 'Night mode', 'th': 'โหมดกลางคืน', 'zh': '夜间模式', 'zh_Hant': '夜間模式', 'ja': 'ナイトモード',
        'ko': '야간 모드', 'fr': 'Mode nuit', 'de': 'Nachtmodus', 'it': 'Modalità notte', 'es': 'Modo nocturno',
        'pt': 'Modo noturno', 'ru': 'Ночной режим', 'uk': 'Нічний режим', 'pl': 'Tryb nocny', 'nl': 'Nachtmodus',
        'tr': 'Gece modu', 'ar': 'الوضع الليلي', 'hi': 'नाइट मोड', 'bn': 'নাইট মোড', 'id': 'Mode malam',
        'ms': 'Mod malam', 'vi': 'Chế độ ban đêm', 'fil': 'Night mode',
    },
    'rotateScreen': {
        'en': 'Rotate screen', 'th': 'หมุนจอ', 'zh': '旋转屏幕', 'zh_Hant': '旋轉畫面', 'ja': '画面を回転',
        'ko': '화면 회전', 'fr': "Faire pivoter l'écran", 'de': 'Bildschirm drehen', 'it': 'Ruota schermo',
        'es': 'Girar pantalla', 'pt': 'Girar tela', 'ru': 'Повернуть экран', 'uk': 'Повернути екран',
        'pl': 'Obróć ekran', 'nl': 'Scherm draaien', 'tr': 'Ekranı döndür', 'ar': 'تدوير الشاشة',
        'hi': 'स्क्रीन घुमाएँ', 'bn': 'স্ক্রিন ঘোরান', 'id': 'Putar layar', 'ms': 'Putar skrin',
        'vi': 'Xoay màn hình', 'fil': 'I-rotate ang screen',
    },
}
from translations_features import FEATURES  # noqa: E402

ADDED.update(FEATURES)
for _key, _vals in ADDED.items():
    KEYS.append(_key)
    for _code, (_, _list) in LANGS.items():
        _list.append(_vals[_code])


def dart_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def main():
    for code, (_, vals) in LANGS.items():
        assert len(vals) == len(KEYS), (code, len(vals))
    out = ['// GENERATED by tools/translations.py. Do not edit by hand.', '',
           'const languageNames = <String, String>{']
    out += [f'  {dart_str(c)}: {dart_str(n)},' for c, (n, _) in LANGS.items()]
    out += ['};', '', 'const translations = <String, Map<String, String>>{']
    for code, (_, vals) in LANGS.items():
        out.append(f'  {dart_str(code)}: {{')
        out += [f'    {dart_str(k)}: {dart_str(v)},' for k, v in zip(KEYS, vals)]
        out.append('  },')
    out += ['};', '']
    path = pathlib.Path(__file__).resolve().parent.parent / 'lib' / 'strings.g.dart'
    path.write_text('\n'.join(out), encoding='utf-8')
    print(f'{len(LANGS)} languages x {len(KEYS)} strings -> {path}')


if __name__ == '__main__':
    main()
