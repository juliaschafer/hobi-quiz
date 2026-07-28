-- ============================================================
-- HOBI · Quiz "Qual hobby combina com você?"
-- Rode este script no SQL Editor do Supabase.
-- ============================================================

create table if not exists public.quiz_hobbies (
  id                 uuid primary key default gen_random_uuid(),
  criado_em          timestamptz not null default now(),
  atualizado_em      timestamptz not null default now(),

  -- captação
  instagram          text not null,
  nome               text,
  consentimento      boolean not null default false,

  -- respostas e resultado
  respostas          jsonb,
  pontuacoes         jsonb,
  percentuais        jsonb,
  perfil_principal   text,
  perfil_secundario  text,
  hobbies_sugeridos  text[],

  -- controle
  concluido          boolean not null default false,
  origem             text,
  user_agent         text,

  constraint instagram_valido check (
    instagram ~ '^[a-z0-9._]{1,30}$'
    and position('..' in instagram) = 0
    and left(instagram, 1) <> '.'
    and right(instagram, 1) <> '.'
  )
);

create index if not exists quiz_hobbies_instagram_idx on public.quiz_hobbies (instagram);
create index if not exists quiz_hobbies_perfil_idx    on public.quiz_hobbies (perfil_principal);
create index if not exists quiz_hobbies_criado_idx    on public.quiz_hobbies (criado_em desc);

-- atualiza o carimbo de tempo a cada update
create or replace function public.toca_atualizado_em()
returns trigger language plpgsql as $$
begin
  new.atualizado_em = now();
  return new;
end $$;

drop trigger if exists trg_quiz_hobbies_touch on public.quiz_hobbies;
create trigger trg_quiz_hobbies_touch
  before update on public.quiz_hobbies
  for each row execute function public.toca_atualizado_em();

-- ============================================================
-- RLS: o site público só pode inserir e completar o próprio
-- registro em aberto. Ninguém anônimo lê ou apaga nada.
-- ============================================================
alter table public.quiz_hobbies enable row level security;

drop policy if exists "publico pode responder"        on public.quiz_hobbies;
drop policy if exists "publico pode concluir"         on public.quiz_hobbies;

create policy "publico pode responder"
  on public.quiz_hobbies for insert
  to anon
  with check (true);

create policy "publico pode concluir"
  on public.quiz_hobbies for update
  to anon
  using (concluido = false)
  with check (concluido = true);

-- A leitura fica só para quem tem service_role (painel, n8n, backend).
-- Se quiser um painel autenticado depois:
-- create policy "equipe le tudo" on public.quiz_hobbies for select to authenticated using (true);

-- ============================================================
-- Consultas úteis para o time
-- ============================================================

-- distribuição dos perfis
-- select perfil_principal, count(*) from public.quiz_hobbies
-- where concluido group by 1 order by 2 desc;

-- leads do dia, com perfil, para abordagem no Instagram
-- select '@'||instagram as arroba, nome, perfil_principal, perfil_secundario, criado_em
-- from public.quiz_hobbies
-- where concluido and criado_em > now() - interval '1 day'
-- order by criado_em desc;

-- taxa de conclusão
-- select count(*) filter (where concluido)::float / nullif(count(*),0) as taxa
-- from public.quiz_hobbies;

-- combinação principal + secundário (ajuda a montar as turmas)
-- select perfil_principal, perfil_secundario, count(*)
-- from public.quiz_hobbies where concluido group by 1,2 order by 3 desc;
