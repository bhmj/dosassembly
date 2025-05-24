drop function if exists api.save_source(_data json);

create or replace function api.save_source(_data json)
    RETURNS jsonb
    LANGUAGE plpgsql
    VOLATILE
AS $$
declare
    _txt text;
    _asm_type text;
    _token text;
    _alphabet bytea;
begin
    _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYabcdefghijkmnopqrstuvwxyz3456789'::bytea;
    _txt = trim(_data->>'txt');
    _asm_type = _data->>'asm_type';
    
    if trim(coalesce(_txt, '')) = '' then
        return jsonb_build_object('error', 'Source not specified');
    end if;
    if trim(coalesce(_asm_type, '')) NOT IN ('TASM','MASM','FASM','NASM') then
        return jsonb_build_object('error', 'Asm type not specified');
    end if;

    select token into _token
    from public.sources
    where txt = _txt;

    if _token is not null then
        return jsonb_build_object('token', _token);
    end if;

	loop
        select string_agg(b,'') into _token
        from (
            select chr(get_byte(_alphabet, get_byte(gen_random_bytes(1),0)%length(_alphabet))) b
            from generate_series(1,6)
        ) m;
		begin
			execute 'insert into public.sources (token, txt, asm_type) values ($1, $2, $3)' using _token, _txt, _asm_type;
			exit;
		exception when unique_violation then raise notice 'token: unique violation with "%"', _token;
		end;
	end loop;

    return jsonb_build_object('token', _token);
end;
$$;

grant execute on function api.save_source(json) to postgres;
