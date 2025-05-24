CREATE TABLE if not exists public.examples (
    id serial8 not null primary key,
    txt_filename text not null,
    image_filename text not null,
    size_category text not null,
    asm_type text CHECK (asm_type in ('TASM','MASM','NASM','FASM')),
    descr text not null,
    link text, -- pouet.net or alike
    rating int -- 0..100
);

CREATE UNIQUE INDEX IF NOT EXISTS uix_examples_txt_size_filename on public.examples (txt_filename, size_category);
