CREATE TABLE if not exists public.sources (
    id serial8 not null primary key,
    token text,
    txt text,
    asm_type text check (asm_type in ('TASM','MASM','NASM','FASM'))
);
CREATE UNIQUE INDEX IF NOT EXISTS uix_sources_txt on public.sources (txt);
CREATE UNIQUE INDEX IF NOT EXISTS uix_sources_token on public.sources (token);
