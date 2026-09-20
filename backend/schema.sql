-- ============================================================
-- Esquema compartido para la colección "Juegos"
-- Sin login: cada navegador genera un id aleatorio (crypto.randomUUID())
-- guardado en localStorage, igual que Wordle guarda tus stats en el
-- dispositivo. Ese id es el "player_id" que viaja al backend solo para
-- poder agregar streak y leaderboard entre partidas — no hay cuentas,
-- ni email, ni pantalla de login en ningún momento.
--
-- Las tablas NO son accesibles directamente desde el cliente (RLS sin
-- políticas = acceso cero por API REST). Todo pasa por las dos funciones
-- de abajo, que validan la entrada. Es más seguro que RLS "por dueño"
-- basado en un id que el propio cliente podría falsificar de todas formas
-- al no haber autenticación real.
-- ============================================================

create table if not exists games (
  id text primary key,          -- slug, ej. 'cuanto-dura'
  name text not null,
  created_at timestamptz not null default now()
);

insert into games (id, name) values ('cuanto-dura', '¿Cuánto Dura?')
  on conflict (id) do nothing;

create table if not exists plays (
  id bigint generated always as identity primary key,
  player_id uuid not null,            -- generado en el navegador, sin auth
  game_id text not null references games(id),
  mode text not null check (mode in ('daily','unlimited')),
  category text,
  day_key date,                       -- solo en modo diario
  scores int[] not null,
  avg_score int not null check (avg_score between 0 and 100),
  created_at timestamptz not null default now()
);

create index if not exists plays_daily_idx
  on plays (game_id, day_key) where mode = 'daily';

create table if not exists streaks (
  player_id uuid not null,
  game_id text not null references games(id),
  current int not null default 0,
  best int not null default 0,
  last_day_key date,
  primary key (player_id, game_id)
);

-- RLS activado sin políticas: nadie puede leer/escribir estas tablas
-- directamente desde el cliente, ni con la anon key. Solo las funciones
-- de abajo (security definer) pueden tocarlas.
alter table plays enable row level security;
alter table streaks enable row level security;

-- ============================================================
-- submit_play: registra una partida. Si es modo diario, actualiza
-- la racha y devuelve racha + percentil del día en la misma llamada.
-- ============================================================
create or replace function submit_play(
  p_player_id uuid,
  p_game_id text,
  p_mode text,
  p_category text,
  p_day_key date,
  p_scores int[]
) returns table (current_streak int, best_streak int, percentile int, total_players int)
language plpgsql security definer as $$
declare
  v_avg int;
  v_current int := 0;
  v_best int := 0;
  v_prev streaks;
  v_yesterday date;
begin
  if p_mode not in ('daily', 'unlimited') then
    raise exception 'invalid mode';
  end if;
  if p_scores is null or array_length(p_scores, 1) is null or array_length(p_scores, 1) > 20 then
    raise exception 'invalid scores';
  end if;

  v_avg := (select round(avg(x))::int from unnest(p_scores) as x);

  insert into plays (player_id, game_id, mode, category, day_key, scores, avg_score)
  values (p_player_id, p_game_id, p_mode, p_category, p_day_key, p_scores, v_avg);

  if p_mode = 'daily' and p_day_key is not null then
    select * into v_prev from streaks where player_id = p_player_id and game_id = p_game_id;

    if not found then
      v_current := 1; v_best := 1;
      insert into streaks (player_id, game_id, current, best, last_day_key)
      values (p_player_id, p_game_id, v_current, v_best, p_day_key);
    elsif v_prev.last_day_key = p_day_key then
      v_current := v_prev.current; v_best := v_prev.best; -- ya jugado hoy
    else
      v_yesterday := p_day_key - 1;
      v_current := case when v_prev.last_day_key = v_yesterday then v_prev.current + 1 else 1 end;
      v_best := greatest(v_prev.best, v_current);
      update streaks set current = v_current, best = v_best, last_day_key = p_day_key
      where player_id = p_player_id and game_id = p_game_id;
    end if;
  end if;

  return query
  select
    v_current, v_best,
    case when p_mode <> 'daily' then null else (
      select case when count(*) = 0 then 100
        else round(100.0 * count(*) filter (where avg_score <= v_avg) / count(*))::int end
      from plays where game_id = p_game_id and mode = 'daily' and day_key = p_day_key
    ) end,
    case when p_mode <> 'daily' then null else (
      select count(*)::int from plays where game_id = p_game_id and mode = 'daily' and day_key = p_day_key
    ) end;
end;
$$;

grant execute on function submit_play(uuid, text, text, text, date, int[]) to anon;

-- ============================================================
-- get_streak: leer la racha actual al abrir el juego (sin registrar nada).
-- ============================================================
create or replace function get_streak(p_player_id uuid, p_game_id text)
returns table (current_streak int, best_streak int)
language plpgsql stable security definer as $$
begin
  return query select s.current, s.best from streaks s
    where s.player_id = p_player_id and s.game_id = p_game_id;
  if not found then
    return query select 0, 0;
  end if;
end;
$$;

grant execute on function get_streak(uuid, text) to anon;
