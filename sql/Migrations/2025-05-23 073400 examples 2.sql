INSERT INTO public.examples (txt_filename, image_filename, size_category, asm_type, descr, link, rating) 
VALUES
('cantorus.asm', 'cantorus.png', '512b', 'FASM', '*cantorus* by *Titan*, nov 2007, 3nd at Main 2007', 'https://www.pouet.net/prod.php?which=33169', 73),
('infinito.asm', 'infinito.png', '512b', 'FASM', '*Infinito, a little bit of.*, apr 2006', 'https://www.pouet.net/prod.php?which=24447', 76),
('wamma_drunk.asm', 'wamma_drunk.png', '512b', 'NASM', '*I''m afraid I was very, very drunk* by *wamma*, sep 2013', 'https://www.pouet.net/prod.php?which=61910', 94),
('tube.asm', 'tube.gif', '256b', 'NASM', '*tube* by *baze/3SC*, aug 2001, 1st at Syndeecate 2001', 'https://www.pouet.net/prod.php?which=3397', 88),
('lattice.asm', 'lattice.gif', '256b', 'NASM', '*lattice* by *baze/3SC*, dec 2001, 1st at Demobit 2001', 'https://www.pouet.net/prod.php?which=4659', 96),
('puls.asm', 'puls.png', '256b', 'NASM', '*puls* by *Řrřola*, sep 2009, 1st at Riverwash 2009', 'https://www.pouet.net/prod.php?which=53816', 99),
('megapole.asm', 'megapole.png', '256b', 'FASM', '*megapole* by *Red Sector Inc.*, sep 2015, 2nd at Function 2015', 'https://www.pouet.net/prod.php?which=66372', 97),
('difuze.asm', 'difuze.png', '256b', 'NASM', '*difúze* by *Řrřola*, sep 2010, 1st at Riverwash 2010', 'https://www.pouet.net/prod.php?which=55777', 96),
('searchlight.asm', 'searchlight.png', '256b', 'NASM', '*searchlight* by *wamma*, jan 2007', 'https://www.pouet.net/prod.php?which=29397', 93),
('centurio.asm', 'centurio.png', '256b', 'FASM', '*centurio* by *Red Sector Inc.*, aug 2015, 1st at Chaos Constructions 2015', 'https://www.pouet.net/prod.php?which=66283', 94)
on conflict (txt_filename, size_category) do nothing;
