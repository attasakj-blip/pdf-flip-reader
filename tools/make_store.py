import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
F = '/home/claude/fonts/'
LANG = sys.argv[1] if len(sys.argv) > 1 else 'th'
RAW = '/home/claude/storekit/raw/' if LANG == 'th' else f'/home/claude/storekit/raw_{LANG}/'
OUT = '/home/claude/storekit/out/' if LANG == 'th' else f'/home/claude/storekit/out_{LANG}/'
os.makedirs(OUT, exist_ok=True)

# Caption fonts per script: (bold, regular)
FONTS = {
    'th': ('Kanit-SemiBold.ttf', 'Sarabun-Regular.ttf'),
    'ja': ('NotoSansJP-Bold.ttf', 'NotoSansJP-Regular.ttf'),
    'zh_Hant': ('NotoSansTC-Bold.ttf', 'NotoSansTC-Regular.ttf'),
    'ar': ('NotoSansArabic-Bold.ttf', 'NotoSansArabic-Regular.ttf'),
}
BOLD, REG = FONTS.get(LANG, ('Kanit-SemiBold.ttf', 'NotoSans-Regular.ttf'))

# (title, subtitle) for screenshots 1-5, then feature graphic (line1, line2, features)
CAPTIONS = {
    'th': [('พลิกหน้าเหมือนหนังสือจริง', 'หน้ากระดาษม้วนตามปลายนิ้ว แสดงแบบหน้าคู่ได้'),
           ('อ่านแบบหน้าเดี่ยวก็ได้', 'ปัดซ้ายไปหน้าถัดไป ปัดขวาย้อนกลับ'),
           ('เคาะสองครั้ง ไปหน้าที่ต้องการ', 'พิมพ์เลขหน้าแล้วกด Enter'),
           ('เลือกไฟล์ PDF จากเครื่อง', 'จำหน้าที่อ่านค้างไว้ให้อัตโนมัติ'),
           ('เสียงพลิกหน้า 10 แบบ', 'เลือกเสียง เปิดปิด และปรับความดังได้'),
           ('อ่าน PDF', 'เหมือนพลิกหนังสือจริง', 'โปรเจกเตอร์  ·  แว่น AI  ·  เสียงพลิกหน้า')],
    'en': [('Turn pages like a real book', 'Pages curl under your finger, in two-page view'),
           ('Or read one page at a time', 'Swipe left for next, right to go back'),
           ('Double-tap to jump to any page', 'Type a page number and press Enter'),
           ('Open any PDF on your phone', 'Picks up where you left off'),
           ('10 page-turn sounds', 'Choose a sound, turn it off, set the volume'),
           ('Read PDFs', 'like a real book', 'Projector  ·  AI glasses  ·  Flip sounds')],
    'de': [('Blättern wie in einem echten Buch', 'Die Seite folgt Ihrem Finger, auch als Doppelseite'),
           ('Oder Seite für Seite lesen', 'Nach links wischen: weiter, nach rechts: zurück'),
           ('Doppeltippen, zu jeder Seite springen', 'Seitenzahl eingeben und Enter drücken'),
           ('Jede PDF auf Ihrem Handy öffnen', 'Liest dort weiter, wo Sie aufgehört haben'),
           ('10 Blättergeräusche', 'Ton wählen, ausschalten, Lautstärke regeln'),
           ('PDFs lesen', 'wie ein echtes Buch', 'Beamer  ·  KI-Brillen  ·  Blätterton')],
    'fr': [('Tournez les pages comme un vrai livre', 'La page suit votre doigt, aussi en double page'),
           ('Ou lisez page par page', 'Glissez à gauche pour avancer, à droite pour revenir'),
           ('Touchez deux fois pour aller à une page', 'Tapez le numéro et appuyez sur Entrée'),
           ('Ouvrez n\'importe quel PDF', 'Reprend là où vous vous êtes arrêté'),
           ('10 sons de page', 'Choisissez un son, coupez-le, réglez le volume'),
           ('Lisez vos PDF', 'comme un vrai livre', 'Projecteur  ·  Lunettes IA  ·  Sons de page')],
    'it': [('Sfoglia come un vero libro', 'La pagina segue il dito, anche a doppia pagina'),
           ('Oppure leggi una pagina alla volta', 'Scorri a sinistra per avanti, a destra per tornare'),
           ('Doppio tocco per andare a una pagina', 'Scrivi il numero e premi Invio'),
           ('Apri qualsiasi PDF del telefono', 'Riprende da dove eri rimasto'),
           ('10 suoni di pagina', 'Scegli un suono, disattivalo, regola il volume'),
           ('Leggi i PDF', 'come un vero libro', 'Proiettore  ·  Occhiali IA  ·  Suoni')],
    'es': [('Pasa páginas como en un libro real', 'La página sigue tu dedo, también a doble página'),
           ('O lee página a página', 'Desliza a la izquierda para avanzar y a la derecha para volver'),
           ('Toca dos veces para ir a una página', 'Escribe el número y pulsa Intro'),
           ('Abre cualquier PDF del teléfono', 'Sigue donde lo dejaste'),
           ('10 sonidos de página', 'Elige un sonido, apágalo o ajusta el volumen'),
           ('Lee tus PDF', 'como un libro real', 'Proyector  ·  Gafas con IA  ·  Sonidos')],
    'ja': [('本物の本のようにページをめくる', '指に合わせてページがめくれる、見開き表示も'),
           ('1ページずつ読むこともできます', '左へスワイプで次へ、右へスワイプで戻る'),
           ('ダブルタップで好きなページへ', 'ページ番号を入力して Enter'),
           ('スマホの PDF を開くだけ', '読みかけのページから再開'),
           ('10種類のページめくり音', '音の選択、オフ、音量調整ができます'),
           ('PDF を', '本のようにめくって読む', 'プロジェクター  ·  AIグラス  ·  めくり音')],
    'zh_Hant': [('像真正的書一樣翻頁', '頁面隨手指捲起，也能雙頁顯示'),
                ('也可以單頁閱讀', '向左滑下一頁，向右滑上一頁'),
                ('點兩下，跳到任何一頁', '輸入頁碼後按 Enter'),
                ('開啟手機裡的任何 PDF', '自動記住上次讀到的頁數'),
                ('10 種翻頁音效', '可選擇音效、關閉或調整音量'),
                ('像翻書一樣', '閱讀 PDF', '投影機  ·  AI 眼鏡  ·  翻頁音效')],
    'ar': [('قلّب الصفحات كأنه كتاب حقيقي', 'تنثني الصفحة مع إصبعك، مع عرض الصفحتين'),
           ('أو اقرأ صفحة واحدة في كل مرة', 'اسحب لليسار للصفحة التالية ولليمين للرجوع'),
           ('انقر مرتين للانتقال إلى أي صفحة', 'اكتب رقم الصفحة واضغط Enter'),
           ('افتح أي ملف PDF على هاتفك', 'يتذكر آخر صفحة قرأتها'),
           ('10 أصوات لتقليب الصفحات', 'اختر الصوت أو أوقفه أو اضبط مستواه'),
           ('اقرأ ملفات PDF', 'كأنها كتاب حقيقي', 'جهاز عرض  ·  نظارات ذكية  ·  صوت التقليب')],
}
C = CAPTIONS[LANG]

def fit(text, fontname, size, maxw):
    f = font(fontname, size)
    while f.getlength(text) > maxw and size > 20:
        size -= 2
        f = font(fontname, size)
    return f
R = ImageFont.Layout.RAQM
def font(name, size): return ImageFont.truetype(F + name, size, layout_engine=R)

def gradient(w, h, top, bottom):
    im = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line((0, y, w, y), fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return im

BROWN_T, BROWN_B = (93, 64, 55), (46, 33, 28)

def rounded(im, r):
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.size[0], im.size[1]), r, fill=255)
    out = Image.new('RGBA', im.size); out.paste(im, (0, 0), mask); return out

def drop(canvas, im, xy, r=40, blur=30, alpha=150):
    sh = Image.new('RGBA', (im.size[0] + blur * 4, im.size[1] + blur * 4), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((blur * 2, blur * 2, blur * 2 + im.size[0], blur * 2 + im.size[1]), r, fill=(0, 0, 0, alpha))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste(sh, (xy[0] - blur * 2, xy[1] - blur * 2 + 16), sh)
    canvas.paste(im, xy, im)

# ---------------------------------------------------------------- icon ---
def icon(size=2048):
    s = size
    im = gradient(s, s, (141, 110, 99), (78, 52, 46)).convert('RGBA')
    d = ImageDraw.Draw(im)
    cx, cy = s / 2, s * 0.53
    pw, ph = s * 0.34, s * 0.46
    # book shadow
    sh = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((cx - pw - 30, cy - ph / 2 + 60, cx + pw + 30, cy + ph / 2 + 90), 60, fill=(0, 0, 0, 120))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(60)))
    d = ImageDraw.Draw(im)
    # left page
    d.polygon([(cx, cy - ph / 2 + 40), (cx - pw, cy - ph / 2), (cx - pw, cy + ph / 2), (cx, cy + ph / 2 + 40)], fill='#FFF8EC')
    # right page (under)
    d.polygon([(cx, cy - ph / 2 + 40), (cx + pw, cy - ph / 2), (cx + pw, cy + ph / 2), (cx, cy + ph / 2 + 40)], fill='#F3E3CC')
    # text lines
    for k in range(6):
        y = cy - ph / 2 + 150 + k * 95
        d.line((cx - pw + 90, y - 18, cx - 90, y + 2), fill='#C9B29A', width=26)
    for k in range(6):
        y = cy - ph / 2 + 150 + k * 95
        d.line((cx + 90, y + 2, cx + pw - 90, y - 18), fill='#DCC7AE', width=26)
    # turning page: lifted from bottom-right corner
    fold_top = (cx + pw * 0.30, cy + ph / 2 + 28)
    fold_side = (cx + pw, cy + ph / 2 - ph * 0.42)
    tip = (cx + pw * 0.08, cy - ph * 0.05)
    # shadow under curl
    sh = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon([fold_top, fold_side, (tip[0] - 20, tip[1] + 40)], fill=(60, 30, 20, 140))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(40)))
    d = ImageDraw.Draw(im)
    # flap with gradient
    flap = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    g = gradient(s, s, (255, 255, 255), (232, 214, 190)).convert('RGBA')
    m = Image.new('L', (s, s), 0)
    ImageDraw.Draw(m).polygon([fold_top, fold_side, tip], fill=255)
    flap.paste(g, (0, 0), m)
    im.alpha_composite(flap)
    # cut the lifted corner off the right page (background shows under: page beneath)
    d.polygon([fold_top, fold_side, (cx + pw, cy + ph / 2)], fill='#FFF8EC')
    d.line([fold_top, fold_side], fill='#D8C3A8', width=10)
    # spine
    d.line((cx, cy - ph / 2 + 40, cx, cy + ph / 2 + 40), fill='#BFA88E', width=14)
    return im.convert('RGB')

if LANG == 'th':
  ic = icon()
  ic.resize((512, 512), Image.LANCZOS).save(OUT + 'icon_512.png')
  for name, px in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
      p = f'/home/claude/pdf_flip_reader/android/app/src/main/res/mipmap-{name}/ic_launcher.png'
      rounded(ic.resize((px, px), Image.LANCZOS), px // 5).save(p)
  ic.resize((1024, 1024), Image.LANCZOS).save('/home/claude/storekit/icon_1024.png')

# ------------------------------------------------------ feature graphic ---
fg = gradient(1024, 500, BROWN_T, BROWN_B).convert('RGBA')
shot = Image.open(RAW + 'shot1_two_page_flip.png').convert('RGB')
book = shot.crop((440, 10, 1960, 1070)).resize((500, 349), Image.LANCZOS)
drop(fg, rounded(book, 12), (494, 76), r=12, blur=18, alpha=170)
d = ImageDraw.Draw(fg)
d.text((40, 120), 'PDF Flip Reader', font=font('Kanit-Bold.ttf', 46), fill='#FFF3E0')
d.text((42, 205), C[5][0], font=fit(C[5][0], BOLD, 40, 430), fill='#FFCC80')
d.text((42, 260), C[5][1], font=fit(C[5][1], BOLD, 36, 430), fill='#FFCC80')
d.text((42, 340), C[5][2], font=fit(C[5][2], REG, 22, 430), fill='#D7CCC8')
fg.convert('RGB').save(OUT + 'feature_graphic_1024x500.png')

# --------------------------------------------------------- screenshots ---
def portrait(name, title, sub, out):
    W, H = 1080, 1920
    c = gradient(W, H, BROWN_T, BROWN_B).convert('RGBA')
    d = ImageDraw.Draw(c)
    d.text((W / 2, 150), title, font=fit(title, BOLD, 66, W - 80), fill='#FFF3E0', anchor='mm')
    d.text((W / 2, 245), sub, font=fit(sub, REG, 40, W - 80), fill='#FFCC80', anchor='mm')
    sc = Image.open(RAW + name).convert('RGB')
    h = 1520; w = int(sc.width * h / sc.height)
    drop(c, rounded(sc.resize((w, h), Image.LANCZOS), 48), ((W - w) // 2, 340), r=48)
    c.convert('RGB').save(OUT + out)

def landscape(name, title, sub, out):
    W, H = 1920, 1080
    c = gradient(W, H, BROWN_T, BROWN_B).convert('RGBA')
    d = ImageDraw.Draw(c)
    d.text((W / 2, 95), title, font=fit(title, BOLD, 62, W - 120), fill='#FFF3E0', anchor='mm')
    d.text((W / 2, 175), sub, font=fit(sub, REG, 38, W - 120), fill='#FFCC80', anchor='mm')
    sc = Image.open(RAW + name).convert('RGB')
    w = 1640; h = int(sc.height * w / sc.width)
    drop(c, rounded(sc.resize((w, h), Image.LANCZOS), 36), ((W - w) // 2, 250), r=36)
    c.convert('RGB').save(OUT + out)

landscape('shot1_two_page_flip.png', *C[0], 'screenshot_1.png')
portrait('shot2_single_page_flip.png', *C[1], 'screenshot_2.png')
landscape('shot3_goto_page.png', *C[2], 'screenshot_3.png')
portrait('shot4_file_chooser.png', *C[3], 'screenshot_4.png')
portrait('shot5_sounds.png', *C[4], 'screenshot_5.png')
print('done', LANG)
