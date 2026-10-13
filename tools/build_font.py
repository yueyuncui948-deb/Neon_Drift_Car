"""Subset the installed OFL Noto Sans CJK TC font to game text (fonttools required)."""
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont
root = Path(__file__).resolve().parents[1]
source = Path('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
font = TTFont(source, fontNumber=3)
text = ''.join(p.read_text() for p in (root/'scripts').glob('*.gd'))
text += ''.join(chr(i) for i in range(32,127))+'0123456789◀▶→Ⅱ—·％：'
options = subset.Options()
options.name_IDs = ['*']
subsetter = subset.Subsetter(options=options)
subsetter.populate(text=text)
subsetter.subset(font)
# Give the modified font an explicit derivative family name.
for record in font['name'].names:
    if record.nameID in [1,3,4,6,16]:
        record.string = ('NeonUI-Regular' if record.nameID==6 else 'Neon UI').encode(record.getEncoding())
out = root/'assets/ui/neon-ui.otf'
out.parent.mkdir(parents=True,exist_ok=True)
font.save(out)
print('Saved',out,len(set(text)),'characters')
