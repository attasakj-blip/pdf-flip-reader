"""Sample book pages (original text) for store screenshots. Usage: make_pages.py [th|en]"""
import sys
from PIL import Image, ImageDraw, ImageFont
LANG = sys.argv[1] if len(sys.argv) > 1 else 'th'
F = '/home/claude/fonts/'
W, H = 900, 1270
OUT = '/home/claude/storekit/pages/' if LANG == 'th' else f'/home/claude/storekit/pages_{LANG}/'
import os; os.makedirs(OUT, exist_ok=True)
title_f = ImageFont.truetype(F + 'Kanit-SemiBold.ttf', 54, layout_engine=ImageFont.Layout.RAQM)
head_f = ImageFont.truetype(F + 'Kanit-SemiBold.ttf', 40, layout_engine=ImageFont.Layout.RAQM)
body_f = ImageFont.truetype(F + ('Sarabun-Regular.ttf' if LANG == 'th' else 'NotoSans-Regular.ttf'), 38 if LANG == 'th' else 33, layout_engine=ImageFont.Layout.RAQM)
small_f = ImageFont.truetype(F + 'Sarabun-Regular.ttf', 24, layout_engine=ImageFont.Layout.RAQM)

CHAPTERS = [
    ('บทที่ 1  เช้าวันอาทิตย์',
     'แสงแดดอ่อนๆ ส่องผ่าน หน้าต่างบานไม้ เข้ามา ในห้องสมุดเล็กๆ ท้ายหมู่บ้าน กลิ่นกระดาษเก่า ผสมกับกลิ่นกาแฟ ลอยอบอวล ไปทั่วห้อง|'
     'ยายจันทร์ นั่งอยู่ที่ โต๊ะตัวเดิม ริมหน้าต่าง หนังสือเล่มหนา วางอยู่ตรงหน้า นิ้วมือที่เหี่ยวย่น ค่อยๆ จับมุมกระดาษ แล้วพลิกไป อย่างช้าๆ|'
     'เสียงกระดาษ ที่ถูกพลิก ดังแผ่วเบา เหมือนเสียงลม ที่พัดผ่าน ทุ่งข้าว ยามเย็น เป็นเสียง ที่ยายฟัง มาตลอดชีวิต และไม่เคย เบื่อเลย สักครั้ง|'
     'วันนี้ หลานชาย มานั่งข้างๆ พร้อมกับ โทรศัพท์มือถือ เครื่องใหม่ เขาบอกยายว่า หนังสือทุกเล่ม ในห้องนี้ อยู่ในเครื่องเล็กๆ นี้ ได้หมด'),
    ('บทที่ 2  หนังสือในมือถือ',
     'ยายหัวเราะ แล้วถามว่า แล้วเสียง พลิกกระดาษล่ะ อยู่ในนั้น ด้วยหรือเปล่า หลานยิ้ม แล้วยื่น โทรศัพท์ ให้ยาย ลองใช้นิ้ว ปัดหน้าจอ ไปทางซ้าย|'
     'หน้ากระดาษ บนจอ ค่อยๆ ม้วนขึ้น ตามนิ้วของยาย เห็นเงา ทอดลงบน หน้าถัดไป แล้วพลิก ไปอย่างนุ่มนวล พร้อมเสียงกระดาษ ที่คุ้นหู|'
     'ยายลองปัด ไปทางขวา หน้ากระดาษ ก็พลิกกลับ มาหน้าเดิม ยายเคาะจอ สองครั้ง มีหน้าต่างเล็กๆ ถามว่า จะไปหน้าที่เท่าไหร่ ยายพิมพ์ เลขหน้า ที่อ่านค้างไว้|'
     'คืนนั้น ทั้งบ้าน นั่งดู หนังสือภาพ เล่มโปรด ของยาย บนผนังห้อง ผ่านโปรเจกเตอร์ เป็นหน้าคู่ เหมือนเปิด หนังสือจริง ขนาดใหญ่'),
    ('บทที่ 3  ห้องสมุดของทุกคน',
     'ตั้งแต่วันนั้น เด็กๆ ในหมู่บ้าน ก็มารวมตัวกัน ที่ห้องสมุด ทุกเย็นวันศุกร์ เพื่อฟังยาย อ่านนิทาน จากภาพ บนผนัง|'
     'ยายเลือก หนังสือเล่มใหม่ ทุกสัปดาห์ บางเล่ม เป็นนิทานพื้นบ้าน บางเล่ม เป็นเรื่อง ดวงดาว และท้องฟ้า เด็กๆ ตั้งใจฟัง ไม่ละสายตา|'
     'เมื่ออ่านจบ ยายจะถามว่า ชอบตอนไหน มากที่สุด แล้วเคาะจอ สองครั้ง พาทุกคน ย้อนกลับไป ดูหน้านั้น อีกครั้ง|'
     'หนังสือ ไม่เคยหายไปไหน มันแค่ เปลี่ยนที่อยู่ จากชั้นไม้ มาอยู่ ในมือของเรา และยังคง พลิกได้ ด้วยปลายนิ้ว เหมือนเดิม'),
]

CHAPTERS_EN = [
    ('Chapter 1  Sunday Morning',
     'Soft sunlight fell through the wooden window into the little library at the end of the village. The smell of old paper and coffee filled the room.|'
     'Grandma Jan sat at her usual table by the window with a thick book in front of her. Her wrinkled fingers took the corner of the page and turned it slowly.|'
     'The page whispered as it turned, like wind over the rice fields at dusk. She had loved that sound all her life and never grew tired of it.|'
     'Today her grandson sat beside her with a brand new phone. Every book in this room, he said, could fit inside this small thing.'),
    ('Chapter 2  A Book in a Phone',
     'Grandma laughed. And the sound of the pages, she asked, is that in there too? He smiled and handed her the phone. She swiped her finger to the left.|'
     'The page on the screen curled up under her finger, cast a soft shadow on the next page, and turned gently with the familiar rustle of paper.|'
     'She swiped right and the page came back. She tapped twice, and a little window asked which page she wanted. She typed the page where she had stopped.|'
     'That night the whole family watched her favourite picture book on the living room wall, two pages side by side, like a giant real book.'),
    ('Chapter 3  A Library for Everyone',
     'From then on the village children gathered at the library every Friday evening to hear Grandma read stories from the pictures on the wall.|'
     'She chose a new book each week. Some were folk tales, some were about the stars and the sky. The children listened without looking away.|'
     'When a story ended she asked which part they liked best, then tapped twice to take everyone back to that page once more.|'
     'Books never went away. They only moved from wooden shelves into our hands, and they still turn at the touch of a finger.'),
]
if LANG != 'th':
    CHAPTERS = CHAPTERS_EN

def wrap(text, font, width):
    lines, cur = [], ''
    for word in text.split(' '):
        t = word if not cur else cur + ('' if LANG == 'th' else ' ') + word
        if font.getlength(t) <= width:
            cur = t
        else:
            lines.append(cur); cur = word
    if cur: lines.append(cur)
    return lines

def illus(d, top, bottom):
    import random
    random.seed(top)
    l, r = 110, W - 110
    d.rounded_rectangle((l, top, r, bottom), 24, fill='#E3F2FD')
    h = bottom - top
    d.ellipse((r - 170, top + 40, r - 70, top + 140), fill='#FFCA28')
    d.polygon([(l, bottom - h*0.35), (l + 260, bottom - h*0.62), (l + 520, bottom - h*0.30), (r, bottom - h*0.5), (r, bottom), (l, bottom)], fill='#A5D6A7')
    d.polygon([(l, bottom - h*0.18), (l + 330, bottom - h*0.40), (r, bottom - h*0.15), (r, bottom), (l, bottom)], fill='#66BB6A')
    hx, hy = l + 140, bottom - h*0.30
    d.rectangle((hx, hy, hx + 150, hy + 110), fill='#FFF3E0')
    d.polygon([(hx - 20, hy), (hx + 75, hy - 70), (hx + 170, hy)], fill='#A1887F')
    d.rectangle((hx + 55, hy + 45, hx + 95, hy + 110), fill='#8D6E63')

def page(num, head, paras):
    im = Image.new('RGB', (W, H), '#FFFDF6')
    d = ImageDraw.Draw(im)
    y = 110
    if head:
        d.text((W / 2, y), head, font=head_f, fill='#5D4037', anchor='mt'); y += 90
        d.line((W / 2 - 60, y, W / 2 + 60, y), fill='#BCAAA4', width=3); y += 50
    for p in paras:
        for i, ln in enumerate(wrap(p, body_f, W - 170)):
            d.text((90 + (40 if i == 0 else 0) * 0, y), ln, font=body_f, fill='#33302C'); y += 64
        y += 34
    if y < H - 420:
        illus(d, y + 30, H - 140)
    d.text((W / 2, H - 70), str(num), font=small_f, fill='#8D8478', anchor='mm')
    im.save(f'{OUT}page_{num:02d}.png')

# Cover
im = Image.new('RGB', (W, H), '#6D4C41')
d = ImageDraw.Draw(im)
d.rectangle((40, 40, W - 40, H - 40), outline='#D7B98E', width=4)
d.ellipse((W/2-180, 290, W/2+180, 650), fill='#8D6E63')
cx, cy = W/2, 470
d.polygon([(cx, cy+90), (cx-150, cy+60), (cx-150, cy-80), (cx, cy-50)], fill='#FFF3E0')
d.polygon([(cx, cy+90), (cx+150, cy+60), (cx+150, cy-80), (cx, cy-50)], fill='#FFE0B2')
for k in range(4):
    d.line((cx-125, cy-40+k*28, cx-25, cy-22+k*28), fill='#BCAAA4', width=5)
    d.line((cx+25, cy-22+k*28, cx+125, cy-40+k*28), fill='#BCAAA4', width=5)
d.text((W/2, 760), 'ห้องสมุด' if LANG == 'th' else "Grandma's", font=ImageFont.truetype(F+'Kanit-Bold.ttf', 96, layout_engine=ImageFont.Layout.RAQM), fill='#FFF3E0', anchor='mm')
d.text((W/2, 880), 'ของยายจันทร์' if LANG == 'th' else 'Library', font=ImageFont.truetype(F+'Kanit-SemiBold.ttf', 70, layout_engine=ImageFont.Layout.RAQM), fill='#FFE0B2', anchor='mm')
d.text((W/2, H-150), 'เรื่องสั้นตัวอย่าง' if LANG == 'th' else 'A sample short story', font=small_f, fill='#D7B98E', anchor='mm')
im.save(OUT + 'page_00.png')

n = 1
for head, body in CHAPTERS:
    ps = body.split('|')
    page(n, head, ps[:2]); n += 1
    page(n, None, ps[2:]); n += 1
print('pages', n)
