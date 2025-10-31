INSERT INTO public.examples (txt_filename, image_filename, size_category, asm_type, descr, link, rating) 
VALUES
('mandala.asm', 'mandala.png', '1k', 'TASM', '*Mandala* by *Mandula*, apr 1996, 5th at Scenest 1996', 'https://www.pouet.net/prod.php?which=15980', 83)
on conflict (txt_filename, size_category) do update set
    image_filename = excluded.image_filename,
    asm_type = excluded.asm_type,
    descr = excluded.descr,
    link = excluded.link,
    rating = excluded.rating
;
