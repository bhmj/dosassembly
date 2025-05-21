CREATE TABLE if not exists public.examples (
    id serial8 not null primary key,
    txt_filename text,
    image_filename text,
    size_category text,
    asm_type text,
    descr text,
    link text, -- pouet.net or alike
    rating int -- 1..99
);
CREATE UNIQUE INDEX IF NOT EXISTS uix_examples_txt_filename on public.examples (txt_filename);
