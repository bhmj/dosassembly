INSERT INTO public.examples (txt_filename, image_filename, size_category, asm_type, descr, link, rating) 
VALUES
('evrbloom.asm', 'everbloom.png', '64b', 'NASM', '*Everbloom* by *Desire*, jun 2018, 1st at @party 2018', 'https://www.pouet.net/prod.php?which=76418', 93)
on conflict (txt_filename, size_category) do update set
    image_filename = excluded.image_filename,
    asm_type = excluded.asm_type,
    descr = excluded.descr,
    link = excluded.link,
    rating = excluded.rating
;
