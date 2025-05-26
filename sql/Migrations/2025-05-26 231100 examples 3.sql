INSERT INTO public.examples (txt_filename, image_filename, size_category, asm_type, descr, link, rating) 
VALUES
('ts256b25.asm', 'reifing-tomeitoes.png', '256b', 'NASM', '*rEIfing tomEItoes - OWUMM!* by *T$*, apr 2025, 9th at Revision 2025', 'https://www.pouet.net/prod.php?which=104018', 100),
('lensical.asm', 'lensical.png', '32b', 'NASM', '*lensical* by *Plex/BionFX*, feb 2025, 3rd at Lovebyte 2025', 'https://files.scene.org/view/parties/2025/lovebyte25/32_byte_intro_highend/lensical_by_plex_of_bionfx.zip', 100),
('caves.asm', 'sirpinsky_caves.png', '32b', 'NASM', '*Sirpinsky Caves* by *Plex/BionFX*, feb 2025, 5th at Lovebyte 2025', 'https://files.scene.org/view/parties/2025/lovebyte25/32_byte_intro_highend/sirpinsky_caves_plex_of_bionfx.zip', 100),
('strings.asm', 'strings.png', '64b', 'NASM', '*Strings* by *Plex/BionFX*, feb 2025, 2nd at Lovebyte 2025', 'https://www.pouet.net/prod.php?which=103729', 100),
('subsurf.asm', 'subsurf.png', '64b', 'NASM', '*Subway Surfer* by *gopher/alcatraz*, feb 2025, 3rd at Lovebyte 2025', 'https://www.pouet.net/prod.php?which=103608', 100),
('holes.asm', 'holes.png', '64b', 'NASM', '*Holes* by *Plex/BinFX*, deb 2025, 4th at Lovebyte 2025', 'https://files.scene.org/view/parties/2025/lovebyte25/64_byte_intro_highend/holes_by_plex_of_bionfx.zip', 100),
('hollowhalls.asm', 'hollowhalls.png', '256b', 'NASM', '*Hollow Halls*, by *ADDiCT*, feb 2025, 6th at Lovebyte 2025', 'https://www.pouet.net/prod.php?which=103638', 100)
on conflict (txt_filename, size_category) do update set
    image_filename = excluded.image_filename,
    asm_type = excluded.asm_type,
    descr = excluded.descr,
    link = excluded.link,
    rating = excluded.rating
;
