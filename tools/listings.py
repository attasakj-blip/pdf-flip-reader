"""Play Store listing text per language.

Run: python3 tools/listings.py OUT_DIR  -> OUT_DIR/<lang>.txt
Checks Google Play limits: title <= 30, short <= 80, full <= 4000 characters.
Translations are drafts; have a native speaker review before publishing.
"""
import os
import sys

L = {}

L['en'] = dict(
    title='PDF Flip Reader: Book-like PDF',
    short='Flip PDFs like a real book on your phone, a projector or AI glasses.',
    full='''Turn any PDF into a book you can flip through.

PDF Flip Reader shows your PDF as a real book. Pages curl under your finger as you swipe, with natural shading and shadows, so reading feels like holding paper.

★ REALISTIC PAGE TURNING
• Swipe left for the next page, swipe right to go back
• The page follows your finger and curls back if you let go early
• Two-page spread (like an open book) or one page at a time

★ JUMP ANYWHERE
• Double-tap the page, type a page number and press Enter
• Slider and arrow buttons for quick moves

★ FIND YOUR FILES EASILY
• Choose a PDF from any folder on your phone
• Recent books show the file name, folder and the page you stopped at
• Reopen a book and continue where you left off

★ PAGE-TURN SOUNDS
• 10 sounds to choose from, with volume control
• Turn sound off any time

★ FOR PROJECTORS AND AI GLASSES
• Mirror your phone to a mini projector, a TV, or AI / display glasses that show your phone screen
• Great for documents, journal articles, reports, children's stories and novels
• Aim a projector at the ceiling and read in bed before you sleep
• Tap once to hide the controls for a clean full-screen page; the screen stays on while you read

★ 23 LANGUAGES
English, Thai, Chinese (Simplified and Traditional), Japanese, Korean, French, German, Italian, Spanish, Portuguese, Russian, Ukrainian, Polish, Dutch, Turkish, Arabic, Hindi, Bengali, Indonesian, Malay, Vietnamese and Filipino. Follows your phone language automatically.

★ PRIVATE
Your PDFs stay on your phone. Nothing is uploaded.

Free with a small banner on the file screen only. Ads are limited to content suitable for general audiences, and never appear while you read.''')

L['th'] = dict(
    title='PDF Flip Reader อ่านแบบหนังสือ',
    short='อ่าน PDF เหมือนพลิกหนังสือจริง บนมือถือ โปรเจกเตอร์ หรือแว่น AI',
    full='''เปลี่ยน PDF ทุกไฟล์ให้เป็นหนังสือที่พลิกอ่านได้จริง

PDF Flip Reader แสดง PDF ของคุณเหมือนหนังสือเล่มจริง หน้ากระดาษโค้งงอตามนิ้วที่ปัด มีแสงเงาเป็นธรรมชาติ อ่านแล้วรู้สึกเหมือนถือกระดาษอยู่ในมือ

★ พลิกหน้าเสมือนจริง
• ปัดซ้ายไปหน้าถัดไป ปัดขวาย้อนกลับ
• หน้ากระดาษเคลื่อนตามนิ้ว ถ้าปล่อยกลางทางจะพับกลับที่เดิม
• ดูแบบสองหน้า (เหมือนกางหนังสือ) หรือทีละหน้า

★ ไปหน้าไหนก็ได้ทันที
• แตะสองครั้ง พิมพ์เลขหน้า แล้วกด Enter
• มีแถบเลื่อนและปุ่มลูกศรให้เลื่อนเร็ว

★ เลือกไฟล์ง่าย
• เลือก PDF จากโฟลเดอร์ใดก็ได้ในเครื่อง
• รายการล่าสุดแสดงชื่อไฟล์ โฟลเดอร์ และหน้าที่อ่านค้างไว้
• เปิดอีกครั้งอ่านต่อจากหน้าเดิมได้เลย

★ เสียงพลิกหน้ากระดาษ
• เลือกได้ 10 แบบ ปรับระดับเสียงได้
• ปิดเสียงได้ทุกเมื่อ

★ เหมาะกับโปรเจกเตอร์และแว่น AI
• สะท้อนหน้าจอไปมินิโปรเจกเตอร์ ทีวี หรือแว่น AI / แว่นจอภาพที่แสดงหน้าจอมือถือได้
• เหมาะกับเอกสารทั่วไป บทความวารสาร รายงาน นิทาน และนิยาย
• ปรับโปรเจกเตอร์ฉายขึ้นเพดาน นอนอ่านหนังสือก่อนนอนได้สบายๆ
• แตะครั้งเดียวซ่อนแถบเครื่องมือ ได้หน้ากระดาษเต็มจอ และหน้าจอไม่ดับระหว่างอ่าน

★ 23 ภาษา
ไทย อังกฤษ จีน (ตัวย่อและตัวเต็ม) ญี่ปุ่น เกาหลี ฝรั่งเศส เยอรมัน อิตาลี สเปน โปรตุเกส รัสเซีย ยูเครน โปแลนด์ ดัตช์ ตุรกี อาหรับ ฮินดี เบงกาลี อินโดนีเซีย มาเลย์ เวียดนาม และฟิลิปปินส์ เปลี่ยนตามภาษาของโทรศัพท์อัตโนมัติ

★ เป็นส่วนตัว
ไฟล์ PDF อยู่ในเครื่องของคุณ ไม่มีการอัปโหลด

ใช้ฟรี มีแบนเนอร์เล็กๆ เฉพาะหน้าเลือกไฟล์ โฆษณาจำกัดเฉพาะเนื้อหาสำหรับบุคคลทั่วไป และไม่แสดงระหว่างอ่าน''')

L['de'] = dict(
    title='PDF Flip Reader: PDF als Buch',
    short='PDFs blättern wie ein echtes Buch: auf dem Handy, am Beamer oder mit KI-Brille.',
    full='''Verwandle jedes PDF in ein Buch zum Durchblättern.

PDF Flip Reader zeigt dein PDF wie ein echtes Buch. Die Seiten wölben sich unter deinem Finger, mit natürlichen Schatten, als hieltest du Papier in der Hand.

★ ECHTES UMBLÄTTERN
• Nach links wischen: nächste Seite, nach rechts: zurück
• Die Seite folgt deinem Finger und fällt zurück, wenn du früh loslässt
• Doppelseite wie ein aufgeschlagenes Buch oder eine Seite allein

★ ZU JEDER SEITE SPRINGEN
• Doppeltippen, Seitenzahl eingeben, Enter drücken
• Schieberegler und Pfeiltasten für schnelles Blättern

★ DATEIEN LEICHT FINDEN
• PDF aus jedem Ordner auf dem Handy wählen
• Zuletzt geöffnet: Dateiname, Ordner und die Seite, bei der du warst
• Beim nächsten Öffnen genau dort weiterlesen

★ BLÄTTERGERÄUSCHE
• 10 Klänge zur Auswahl, mit Lautstärkeregler
• Jederzeit ausschaltbar

★ FÜR BEAMER UND KI-BRILLEN
• Spiegle dein Handy auf einen Mini-Beamer, einen Fernseher oder eine KI- bzw. Display-Brille, die deinen Handybildschirm zeigt
• Ideal für Dokumente, Fachartikel, Berichte, Kindergeschichten und Romane
• Richte den Beamer an die Decke und lies abends im Bett
• Einmal tippen blendet die Bedienelemente aus; der Bildschirm bleibt beim Lesen an

★ 23 SPRACHEN
Deutsch, Englisch, Französisch, Italienisch, Spanisch, Portugiesisch, Niederländisch, Polnisch, Russisch, Ukrainisch, Türkisch, Arabisch, Chinesisch, Japanisch, Koreanisch, Thai und mehr. Richtet sich automatisch nach der Handysprache.

★ PRIVAT
Deine PDFs bleiben auf deinem Handy. Es wird nichts hochgeladen.

Kostenlos, mit einem kleinen Banner nur im Dateibildschirm. Die Werbung ist auf jugendfreie Inhalte beschränkt und erscheint nie beim Lesen.''')

L['fr'] = dict(
    title='PDF Flip Reader : PDF en livre',
    short='Feuilletez vos PDF comme un vrai livre : téléphone, projecteur ou lunettes IA.',
    full='''Transformez n'importe quel PDF en livre à feuilleter.

PDF Flip Reader affiche votre PDF comme un vrai livre. La page se courbe sous votre doigt, avec des ombres naturelles, comme du vrai papier.

★ DES PAGES QUI SE TOURNENT VRAIMENT
• Glissez à gauche pour la page suivante, à droite pour revenir
• La page suit votre doigt et retombe si vous la lâchez trop tôt
• Double page comme un livre ouvert, ou une page à la fois

★ ALLER À N'IMPORTE QUELLE PAGE
• Touchez deux fois, tapez le numéro et appuyez sur Entrée
• Curseur et flèches pour avancer vite

★ RETROUVER SES FICHIERS
• Choisissez un PDF dans n'importe quel dossier du téléphone
• Les livres récents affichent le nom, le dossier et la page où vous vous êtes arrêté
• Reprenez votre lecture là où vous l'aviez laissée

★ SONS DE PAGE
• 10 sons au choix, volume réglable
• Coupez le son quand vous voulez

★ POUR VIDÉOPROJECTEURS ET LUNETTES IA
• Dupliquez l'écran sur un mini vidéoprojecteur, une TV ou des lunettes IA / à écran qui affichent votre téléphone
• Idéal pour les documents, articles de revues, rapports, contes pour enfants et romans
• Projetez au plafond et lisez au lit avant de dormir
• Touchez une fois pour masquer les commandes et lire en plein écran ; l'écran reste allumé

★ 23 LANGUES
Français, anglais, allemand, italien, espagnol, portugais, néerlandais, polonais, russe, ukrainien, turc, arabe, chinois, japonais, coréen, thaï et plus. Suit automatiquement la langue du téléphone.

★ CONFIDENTIEL
Vos PDF restent sur votre téléphone. Rien n'est envoyé en ligne.

Gratuit, avec une petite bannière uniquement sur l'écran des fichiers. Les publicités sont limitées aux contenus tous publics et n'apparaissent jamais pendant la lecture.''')

L['it'] = dict(
    title='PDF Flip Reader: sfoglia PDF',
    short='Sfoglia i PDF come un vero libro: su telefono, proiettore o occhiali IA.',
    full='''Trasforma qualsiasi PDF in un libro da sfogliare.

PDF Flip Reader mostra il tuo PDF come un vero libro. La pagina si piega sotto il dito, con ombre naturali, come la carta vera.

★ SFOGLIA COME UN VERO LIBRO
• Scorri a sinistra per la pagina successiva, a destra per tornare
• La pagina segue il dito e ricade se la lasci presto
• Doppia pagina come un libro aperto, oppure una pagina alla volta

★ VAI A QUALSIASI PAGINA
• Doppio tocco, scrivi il numero e premi Invio
• Cursore e frecce per spostarti in fretta

★ TROVA I FILE CON FACILITÀ
• Scegli un PDF da qualsiasi cartella del telefono
• I libri recenti mostrano nome, cartella e pagina a cui eri arrivato
• Riapri e riprendi da dove avevi lasciato

★ SUONI DI PAGINA
• 10 suoni tra cui scegliere, volume regolabile
• Disattivabili in qualsiasi momento

★ PER PROIETTORI E OCCHIALI IA
• Duplica lo schermo su un mini proiettore, una TV o occhiali IA / con display che mostrano lo schermo del telefono
• Ideale per documenti, articoli di riviste, relazioni, fiabe e romanzi
• Punta il proiettore sul soffitto e leggi a letto prima di dormire
• Un tocco nasconde i comandi per una pagina a schermo intero; lo schermo resta acceso

★ 23 LINGUE
Italiano, inglese, francese, tedesco, spagnolo, portoghese, olandese, polacco, russo, ucraino, turco, arabo, cinese, giapponese, coreano, thailandese e altre. Segue automaticamente la lingua del telefono.

★ PRIVATO
I tuoi PDF restano sul telefono. Nulla viene caricato online.

Gratis, con un piccolo banner solo nella schermata dei file. Gli annunci sono limitati a contenuti adatti a tutti e non compaiono mai durante la lettura.''')

L['es'] = dict(
    title='PDF Flip Reader: hojea tus PDF',
    short='Hojea tus PDF como un libro real: en el móvil, un proyector o gafas con IA.',
    full='''Convierte cualquier PDF en un libro para hojear.

PDF Flip Reader muestra tu PDF como un libro de verdad. La página se curva bajo tu dedo, con sombras naturales, como papel real.

★ PASA PÁGINAS DE VERDAD
• Desliza a la izquierda para avanzar y a la derecha para volver
• La página sigue tu dedo y vuelve a su sitio si la sueltas antes
• Doble página como un libro abierto, o una página a la vez

★ VE A CUALQUIER PÁGINA
• Toca dos veces, escribe el número y pulsa Intro
• Barra deslizante y flechas para moverte rápido

★ ENCUENTRA TUS ARCHIVOS
• Elige un PDF de cualquier carpeta del teléfono
• Los libros recientes muestran el nombre, la carpeta y la página donde te quedaste
• Vuelve a abrirlo y sigue donde lo dejaste

★ SONIDOS DE PÁGINA
• 10 sonidos para elegir, con control de volumen
• Desactívalos cuando quieras

★ PARA PROYECTORES Y GAFAS CON IA
• Duplica la pantalla en un miniproyector, una TV o gafas con IA / con pantalla que muestran tu teléfono
• Ideal para documentos, artículos de revistas, informes, cuentos infantiles y novelas
• Proyecta en el techo y lee en la cama antes de dormir
• Toca una vez para ocultar los controles y leer a pantalla completa; la pantalla no se apaga

★ 23 IDIOMAS
Español, inglés, portugués, francés, alemán, italiano, neerlandés, polaco, ruso, ucraniano, turco, árabe, chino, japonés, coreano, tailandés y más. Sigue automáticamente el idioma del teléfono.

★ PRIVADO
Tus PDF se quedan en tu teléfono. No se sube nada.

Gratis, con un pequeño banner solo en la pantalla de archivos. Los anuncios se limitan a contenido apto para todo público y nunca aparecen mientras lees.''')

L['pt'] = dict(
    title='PDF Flip Reader: folheie PDFs',
    short='Folheie PDFs como um livro de verdade: no celular, projetor ou óculos com IA.',
    full='''Transforme qualquer PDF em um livro para folhear.

O PDF Flip Reader mostra seu PDF como um livro de verdade. A página se curva sob o seu dedo, com sombras naturais, como papel real.

★ VIRE AS PÁGINAS DE VERDADE
• Deslize para a esquerda para avançar e para a direita para voltar
• A página acompanha o dedo e volta ao lugar se você soltar antes
• Página dupla como um livro aberto, ou uma página por vez

★ VÁ PARA QUALQUER PÁGINA
• Toque duas vezes, digite o número e pressione Enter
• Barra deslizante e setas para ir rápido

★ ENCONTRE SEUS ARQUIVOS
• Escolha um PDF de qualquer pasta do celular
• Os livros recentes mostram o nome, a pasta e a página onde você parou
• Abra de novo e continue de onde parou

★ SONS DE PÁGINA
• 10 sons para escolher, com controle de volume
• Desligue quando quiser

★ PARA PROJETORES E ÓCULOS COM IA
• Espelhe a tela em um miniprojetor, uma TV ou óculos com IA / com tela que mostram o seu celular
• Ideal para documentos, artigos de revistas, relatórios, histórias infantis e romances
• Projete no teto e leia na cama antes de dormir
• Toque uma vez para esconder os controles e ler em tela cheia; a tela fica ligada

★ 23 IDIOMAS
Português, inglês, espanhol, francês, alemão, italiano, holandês, polonês, russo, ucraniano, turco, árabe, chinês, japonês, coreano, tailandês e outros. Segue automaticamente o idioma do celular.

★ PRIVADO
Seus PDFs ficam no seu celular. Nada é enviado.

Grátis, com um pequeno banner apenas na tela de arquivos. Os anúncios são limitados a conteúdo livre para todos os públicos e nunca aparecem durante a leitura.''')

L['ja'] = dict(
    title='PDF Flip Reader 本のように読む',
    short='PDFを本のようにめくって読む。スマホでも、プロジェクターやAIグラスでも。',
    full='''どんなPDFも、めくって読める本に。

PDF Flip Reader は、PDFを本物の本のように表示します。指の動きに合わせてページがしなり、自然な陰影がつくので、紙をめくっているような感覚で読めます。

★ リアルなページめくり
・左へスワイプで次のページ、右へスワイプで前のページ
・ページは指に追従し、途中で離すと元に戻ります
・本を開いたような見開き表示、または1ページずつ表示

★ 好きなページへすぐ移動
・ダブルタップしてページ番号を入力し、Enter
・スライダーと矢印ボタンですばやく移動

★ ファイルを簡単に選べる
・スマホのどのフォルダからでもPDFを選択
・最近開いた本は、ファイル名・フォルダ・読みかけのページを表示
・次に開いたときは続きから読めます

★ ページめくり音
・10種類から選べて、音量も調整可能
・いつでもオフにできます

★ プロジェクターやAIグラスに最適
・ミニプロジェクター、テレビ、スマホ画面を映せるAIグラス／ディスプレイグラスにミラーリング
・一般文書、学術論文、レポート、絵本、小説の閲覧に
・プロジェクターを天井に向ければ、ベッドで寝る前の読書にも
・1回タップで操作バーを隠して全画面表示。読書中は画面が消えません

★ 23言語に対応
日本語、英語、中国語（簡体字・繁体字）、韓国語、フランス語、ドイツ語、イタリア語、スペイン語、ポルトガル語、ロシア語、アラビア語、タイ語など。スマホの言語設定に自動で合わせます。

★ プライバシー
PDFはスマホの中だけに保存され、アップロードされることはありません。

無料。小さなバナー広告はファイル選択画面にのみ表示されます。広告は全年齢向けの内容に限定され、読書中には表示されません。''')

L['zh_Hant'] = dict(
    title='PDF Flip Reader 像書一樣讀 PDF',
    short='像真正的書一樣翻閱 PDF：手機、投影機、AI 眼鏡都適用。',
    full='''把任何 PDF 變成可以翻閱的書。

PDF Flip Reader 會把你的 PDF 顯示成一本真正的書。頁面隨手指彎曲，搭配自然的光影，讀起來就像手裡拿著紙本。

★ 逼真的翻頁效果
・向左滑翻到下一頁，向右滑回到上一頁
・頁面跟著手指移動，中途放開會自動回到原位
・可選雙頁（像攤開的書）或單頁顯示

★ 隨時跳到任何一頁
・點兩下，輸入頁碼，按 Enter
・滑桿與箭頭按鈕可快速移動

★ 輕鬆找到檔案
・從手機任何資料夾選擇 PDF
・最近閱讀會顯示檔名、資料夾和上次讀到的頁數
・再次開啟可從上次的地方繼續

★ 翻頁音效
・10 種音效可選，可調整音量
・隨時可以關閉

★ 適合投影機與 AI 眼鏡
・將畫面鏡像到迷你投影機、電視，或能顯示手機畫面的 AI 眼鏡／顯示眼鏡
・適合一般文件、期刊論文、報告、童話故事與小說
・把投影機投向天花板，躺在床上就能睡前閱讀
・點一下即可隱藏工具列，全螢幕閱讀；閱讀時螢幕不會關閉

★ 支援 23 種語言
繁體中文、簡體中文、英文、日文、韓文、法文、德文、義大利文、西班牙文、葡萄牙文、俄文、阿拉伯文、泰文等，自動跟隨手機語言。

★ 保護隱私
PDF 只存放在你的手機裡，不會上傳。

免費使用，只有選擇檔案的畫面有小型橫幅廣告。廣告僅限適合所有年齡的內容，閱讀時絕不顯示。''')

L['zh'] = dict(
    title='PDF Flip Reader 像书一样读 PDF',
    short='像真正的书一样翻阅 PDF：手机、投影仪、AI 眼镜都适用。',
    full='''把任何 PDF 变成可以翻阅的书。

PDF Flip Reader 会把你的 PDF 显示成一本真正的书。页面随手指弯曲，搭配自然的光影，读起来就像手里拿着纸质书。

★ 逼真的翻页效果
・向左滑翻到下一页，向右滑回到上一页
・页面跟着手指移动，中途松开会自动回到原位
・可选双页（像摊开的书）或单页显示

★ 随时跳到任何一页
・点两下，输入页码，按 Enter
・滑块与箭头按钮可快速移动

★ 轻松找到文件
・从手机任何文件夹选择 PDF
・最近阅读会显示文件名、文件夹和上次读到的页数
・再次打开可从上次的地方继续

★ 翻页音效
・10 种音效可选，可调节音量
・随时可以关闭

★ 适合投影仪与 AI 眼镜
・将画面投屏到迷你投影仪、电视，或能显示手机画面的 AI 眼镜／显示眼镜
・适合一般文档、期刊论文、报告、童话故事与小说
・把投影仪投向天花板，躺在床上就能睡前阅读
・点一下即可隐藏工具栏，全屏阅读；阅读时屏幕不会熄灭

★ 支持 23 种语言
简体中文、繁体中文、英语、日语、韩语、法语、德语、意大利语、西班牙语、葡萄牙语、俄语、阿拉伯语、泰语等，自动跟随手机语言。

★ 保护隐私
PDF 只保存在你的手机里，不会上传。

免费使用，只有选择文件的界面有小型横幅广告。广告仅限适合所有年龄的内容，阅读时绝不显示。''')

L['ko'] = dict(
    title='PDF Flip Reader 책처럼 읽기',
    short='PDF를 진짜 책처럼 넘겨 읽기. 휴대폰, 프로젝터, AI 안경에서도.',
    full='''어떤 PDF든 넘겨 읽는 책으로.

PDF Flip Reader는 PDF를 진짜 책처럼 보여 줍니다. 손가락을 따라 페이지가 휘어지고 자연스러운 그림자가 생겨서 종이를 넘기는 느낌으로 읽을 수 있습니다.

★ 실감 나는 페이지 넘기기
• 왼쪽으로 밀면 다음 페이지, 오른쪽으로 밀면 이전 페이지
• 페이지가 손가락을 따라오고, 중간에 놓으면 제자리로 돌아갑니다
• 펼친 책 같은 두 쪽 보기 또는 한 쪽씩 보기

★ 원하는 페이지로 바로 이동
• 두 번 탭하고 페이지 번호를 입력한 뒤 Enter
• 슬라이더와 화살표 버튼으로 빠르게 이동

★ 파일을 쉽게 찾기
• 휴대폰의 어느 폴더에서든 PDF 선택
• 최근 책 목록에 파일 이름, 폴더, 읽던 페이지 표시
• 다시 열면 읽던 곳부터 이어서

★ 책장 넘기는 소리
• 10가지 소리 중 선택, 음량 조절 가능
• 언제든 끌 수 있습니다

★ 프로젝터와 AI 안경에 딱
• 미니 프로젝터, TV, 휴대폰 화면을 보여 주는 AI 안경 / 디스플레이 안경에 화면 미러링
• 일반 문서, 학술 논문, 보고서, 동화, 소설 읽기에 적합
• 프로젝터를 천장에 비추면 잠들기 전 침대에서 독서
• 한 번 탭하면 도구 막대가 사라져 전체 화면으로 읽기, 읽는 동안 화면이 꺼지지 않습니다

★ 23개 언어
한국어, 영어, 일본어, 중국어(간체·번체), 프랑스어, 독일어, 이탈리아어, 스페인어, 포르투갈어, 러시아어, 아랍어, 태국어 등. 휴대폰 언어를 자동으로 따릅니다.

★ 개인정보 보호
PDF는 휴대폰에만 저장되며 업로드되지 않습니다.

무료이며, 파일 선택 화면에만 작은 배너 광고가 있습니다. 광고는 전체 이용가 콘텐츠로 제한되고 읽는 중에는 표시되지 않습니다.''')

L['ar'] = dict(
    title='PDF Flip Reader قارئ كالكتاب',
    short='تصفّح ملفات PDF كأنها كتاب حقيقي على الهاتف أو جهاز العرض أو النظارات الذكية.',
    full='''حوّل أي ملف PDF إلى كتاب تقلّب صفحاته.

يعرض PDF Flip Reader ملفك كأنه كتاب حقيقي. تنثني الصفحة تحت إصبعك مع ظلال طبيعية، فتشعر وكأنك تمسك الورق بيدك.

★ تقليب واقعي للصفحات
• اسحب لليسار للصفحة التالية ولليمين للرجوع
• تتبع الصفحة إصبعك وتعود إلى مكانها إذا تركتها مبكرًا
• عرض صفحتين مثل الكتاب المفتوح أو صفحة واحدة

★ انتقل إلى أي صفحة
• انقر مرتين واكتب رقم الصفحة ثم اضغط Enter
• شريط تمرير وأزرار أسهم للتنقل السريع

★ اعثر على ملفاتك بسهولة
• اختر ملف PDF من أي مجلد في هاتفك
• تعرض الكتب الأخيرة اسم الملف والمجلد والصفحة التي توقفت عندها
• افتح الكتاب مجددًا وتابع من حيث توقفت

★ أصوات تقليب الصفحات
• 10 أصوات للاختيار مع التحكم في مستوى الصوت
• يمكنك إيقاف الصوت في أي وقت

★ مثالي لأجهزة العرض والنظارات الذكية
• اعرض شاشة هاتفك على جهاز عرض صغير أو تلفاز أو نظارات ذكية بالذكاء الاصطناعي تعرض شاشة الهاتف
• مناسب للمستندات والمقالات العلمية والتقارير وقصص الأطفال والروايات
• وجّه جهاز العرض إلى السقف واقرأ في سريرك قبل النوم
• انقر مرة واحدة لإخفاء الأزرار والقراءة بملء الشاشة، وتبقى الشاشة مضاءة أثناء القراءة

★ 23 لغة
العربية والإنجليزية والفرنسية والألمانية والإيطالية والإسبانية والبرتغالية والروسية والتركية والصينية واليابانية والكورية والتايلاندية وغيرها، وتتبع لغة الهاتف تلقائيًا. الواجهة تدعم الكتابة من اليمين إلى اليسار.

★ خصوصية تامة
تبقى ملفاتك على هاتفك ولا يُرفع أي شيء.

مجاني مع شريط إعلاني صغير في شاشة الملفات فقط. تقتصر الإعلانات على محتوى مناسب لجميع الأعمار ولا تظهر أبدًا أثناء القراءة.''')

L['ru'] = dict(
    title='PDF Flip Reader: PDF как книга',
    short='Листайте PDF как настоящую книгу: на телефоне, проекторе или в AI-очках.',
    full='''Превратите любой PDF в книгу, которую можно листать.

PDF Flip Reader показывает PDF как настоящую книгу. Страница изгибается под пальцем, с естественными тенями, словно вы держите бумагу.

★ РЕАЛИСТИЧНОЕ ЛИСТАНИЕ
• Смахните влево для следующей страницы, вправо для предыдущей
• Страница следует за пальцем и возвращается, если отпустить раньше
• Разворот, как в открытой книге, или по одной странице

★ ПЕРЕХОД НА ЛЮБУЮ СТРАНИЦУ
• Коснитесь дважды, введите номер и нажмите Enter
• Ползунок и кнопки-стрелки для быстрого перехода

★ УДОБНЫЙ ВЫБОР ФАЙЛОВ
• Выбирайте PDF из любой папки телефона
• В недавних книгах видно имя файла, папку и страницу, где вы остановились
• Откройте снова и продолжайте с того же места

★ ЗВУКИ ПЕРЕЛИСТЫВАНИЯ
• 10 звуков на выбор, регулировка громкости
• Звук можно выключить в любой момент

★ ДЛЯ ПРОЕКТОРОВ И AI-ОЧКОВ
• Транслируйте экран на мини-проектор, телевизор или AI-очки / очки с дисплеем, которые показывают экран телефона
• Подходит для документов, журнальных статей, отчётов, детских сказок и романов
• Направьте проектор на потолок и читайте в кровати перед сном
• Одно касание скрывает панели для чтения на весь экран; экран не гаснет во время чтения

★ 23 ЯЗЫКА
Русский, украинский, английский, немецкий, французский, итальянский, испанский, португальский, польский, турецкий, арабский, китайский, японский, корейский, тайский и другие. Язык телефона выбирается автоматически.

★ КОНФИДЕНЦИАЛЬНО
Ваши PDF остаются на телефоне. Ничего не загружается в сеть.

Бесплатно, с небольшим баннером только на экране выбора файлов. Реклама ограничена материалами для всех возрастов и никогда не показывается во время чтения.''')

# Play Console language codes for each listing.
PLAY_CODE = {
    'en': 'en-US (default), en-GB', 'th': 'th', 'de': 'de-DE', 'fr': 'fr-FR, fr-CA', 'it': 'it-IT',
    'es': 'es-ES, es-419', 'pt': 'pt-BR, pt-PT', 'ja': 'ja-JP', 'zh_Hant': 'zh-TW, zh-HK',
    'zh': 'zh-CN', 'ko': 'ko-KR', 'ar': 'ar', 'ru': 'ru-RU',
}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else 'listings'
    os.makedirs(out, exist_ok=True)
    bad = False
    for code, d in L.items():
        lens = {k: len(d[k]) for k in ('title', 'short', 'full')}
        for k, lim in (('title', 30), ('short', 80), ('full', 4000)):
            if lens[k] > lim:
                print(f'{code}: {k} is {lens[k]} > {lim}')
                bad = True
        with open(f'{out}/{code}.txt', 'w', encoding='utf-8') as f:
            f.write(f'Play Console language: {PLAY_CODE[code]}\n\n')
            f.write(f'[App name] ({lens["title"]}/30)\n{d["title"]}\n\n')
            f.write(f'[Short description] ({lens["short"]}/80)\n{d["short"]}\n\n')
            f.write(f'[Full description] ({lens["full"]}/4000)\n{d["full"]}\n')
    print('FAIL' if bad else f'ok, {len(L)} languages')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
