-- AiSMS+BACKEND hardening: users must not be able to self-promote by editing profiles.account_type.
create or replace function public.prevent_role_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_admin() and new.account_type is distinct from old.account_type then
    raise exception 'Account role changes require administrator approval';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_prevent_role_escalation on public.profiles;
create trigger profiles_prevent_role_escalation
before update on public.profiles
for each row execute function public.prevent_role_escalation();

-- Make the authenticated frontend unable to insert/update/delete payment records directly.
revoke insert, update, delete on public.payments from authenticated;
