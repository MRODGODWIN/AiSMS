-- AiSMUS
-- Production-oriented Supabase schema.
-- IMPORTANT: authorization roles belong in auth.app_metadata, never user_metadata.

create extension if not exists pgcrypto;

create type public.account_role as enum (
  'customer','seller','service_provider','organization','partner','admin','developer'
);
create type public.review_status as enum ('pending','published','rejected');
create type public.listing_status as enum ('draft','pending','published','rejected','archived');
create type public.order_status as enum ('pending','confirmed','paid','processing','shipped','completed','cancelled','refunded');
create type public.payment_status as enum ('pending','initialized','paid','failed','refunded');
create type public.partner_status as enum ('pending','verified','rejected','suspended');
create type public.rental_status as enum ('draft','pending','published','rejected','booked','archived');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  email text,
  avatar_url text,
  referral_username text unique,
  phone text,
  account_type public.account_role not null default 'customer',
  bio text,
  location text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  category text not null,
  tier text not null check (tier in ('Affordable','Quality')),
  price numeric(14,2) not null check (price >= 0),
  currency text not null default 'NGN',
  stock integer not null default 0 check (stock >= 0),
  status public.listing_status not null default 'pending',
  location text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.product_media (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  storage_path text not null,
  public_url text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.services (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete set null,
  title text not null,
  category text not null,
  description text,
  price_from numeric(14,2) check (price_from >= 0),
  currency text not null default 'NGN',
  status public.listing_status not null default 'pending',
  location text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.service_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid references public.profiles(id) on delete set null,
  service_id uuid references public.services(id) on delete set null,
  provider_id uuid references public.profiles(id) on delete set null,
  subject text not null,
  message text,
  status text not null default 'pending' check (status in ('pending','accepted','declined','in_progress','completed','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  reviewer_id uuid references public.profiles(id) on delete set null,
  product_id uuid references public.products(id) on delete cascade,
  service_id uuid references public.services(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  body text,
  status public.review_status not null default 'pending',
  created_at timestamptz not null default now(),
  constraint review_target check (
    (product_id is not null and service_id is null) or
    (product_id is null and service_id is not null)
  )
);

create table public.votes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  service_id uuid references public.services(id) on delete cascade,
  product_id uuid references public.products(id) on delete cascade,
  value integer not null check (value in (-1,1)),
  created_at timestamptz not null default now(),
  constraint vote_target check (
    (service_id is not null and product_id is null) or
    (service_id is null and product_id is not null)
  ),
  unique(user_id, service_id, product_id)
);

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  category text not null,
  title text not null,
  body text,
  media_type text,
  media_path text,
  media_url text,
  status public.listing_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.partners (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  business_name text not null,
  registration_number text,
  services_products text,
  years_experience integer check (years_experience >= 0),
  platform text,
  proof_document_path text,
  status public.partner_status not null default 'pending',
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.rentals (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  category text not null,
  tier text not null check (tier in ('Affordable','Quality')),
  price numeric(14,2) not null check (price >= 0),
  currency text not null default 'NGN',
  period text not null,
  deposit numeric(14,2) not null default 0 check (deposit >= 0),
  location text not null,
  availability text,
  description text,
  status public.rental_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.rental_media (
  id uuid primary key default gen_random_uuid(),
  rental_id uuid not null references public.rentals(id) on delete cascade,
  storage_path text not null,
  public_url text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.carts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references public.carts(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  created_at timestamptz not null default now(),
  unique(cart_id, product_id)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique default ('ASM-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,12))),
  buyer_id uuid references public.profiles(id) on delete set null,
  referral_username text,
  subtotal numeric(14,2) not null default 0,
  delivery_fee numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  currency text not null default 'NGN',
  status public.order_status not null default 'pending',
  payment_status public.payment_status not null default 'pending',
  payment_reference text,
  delivery_address text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  seller_id uuid references public.profiles(id) on delete set null,
  title_snapshot text not null,
  unit_price numeric(14,2) not null,
  quantity integer not null check (quantity > 0),
  line_total numeric(14,2) not null,
  created_at timestamptz not null default now()
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  provider text not null,
  reference text unique,
  amount numeric(14,2) not null,
  currency text not null default 'NGN',
  status public.payment_status not null default 'pending',
  raw_response jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_id uuid references public.profiles(id) on delete set null,
  order_id uuid references public.orders(id) on delete set null,
  referral_username text,
  commission_rate numeric(5,4) not null default 0.20 check (commission_rate >= 0 and commission_rate <= 1),
  commission_amount numeric(14,2) not null default 0,
  status text not null default 'pending' check (status in ('pending','approved','paid','reversed')),
  created_at timestamptz not null default now(),
  paid_at timestamptz
);

create table public.activity (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete cascade,
  type text not null,
  icon text,
  title text not null,
  detail text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  title text not null,
  body text,
  kind text not null default 'info',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.registration_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  full_name text not null,
  email text not null,
  account_type public.account_role not null default 'customer',
  terms_accepted_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);

create index products_status_idx on public.products(status);
create index products_owner_idx on public.products(owner_id);
create index services_status_idx on public.services(status);
create index posts_status_created_idx on public.posts(status, created_at desc);
create index rentals_status_created_idx on public.rentals(status, created_at desc);
create index activity_user_created_idx on public.activity(user_id, created_at desc);
create index notifications_user_created_idx on public.notifications(user_id, created_at desc);
create index orders_buyer_created_idx on public.orders(buyer_id, created_at desc);

create or replace function public.is_admin()
returns boolean language sql stable as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') in ('admin','developer'), false);
$$;

create or replace function public.is_developer()
returns boolean language sql stable as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') = 'developer', false);
$$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles','products','services','service_requests','posts','partners',
    'rentals','carts','orders','payments','notifications','registration_requests'
  ] loop
    execute format('drop trigger if exists %I_touch on public.%I', t, t);
    execute format('create trigger %I_touch before update on public.%I for each row execute function public.touch_updated_at()', t, t);
  end loop;
end $$;

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.product_media enable row level security;
alter table public.services enable row level security;
alter table public.service_requests enable row level security;
alter table public.reviews enable row level security;
alter table public.votes enable row level security;
alter table public.posts enable row level security;
alter table public.partners enable row level security;
alter table public.rentals enable row level security;
alter table public.rental_media enable row level security;
alter table public.carts enable row level security;
alter table public.cart_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.referrals enable row level security;
alter table public.activity enable row level security;
alter table public.notifications enable row level security;
alter table public.registration_requests enable row level security;

-- Public discovery
create policy "published products readable" on public.products for select to anon, authenticated using (status='published');
create policy "published product media readable" on public.product_media for select to anon, authenticated
  using (exists(select 1 from public.products p where p.id=product_id and p.status='published'));
create policy "published services readable" on public.services for select to anon, authenticated using (status='published');
create policy "published posts readable" on public.posts for select to anon, authenticated using (status='published');
create policy "published rentals readable" on public.rentals for select to anon, authenticated using (status='published');
create policy "published rental media readable" on public.rental_media for select to anon, authenticated
  using (exists(select 1 from public.rentals r where r.id=rental_id and r.status='published'));
create policy "published reviews readable" on public.reviews for select to anon, authenticated using (status='published');

-- Profiles
create policy "own profile readable" on public.profiles for select to authenticated using (id=(select auth.uid()) or public.is_admin());
create policy "own profile insert" on public.profiles for insert to authenticated with check (id=(select auth.uid()));
create policy "own profile update" on public.profiles for update to authenticated using (id=(select auth.uid()) or public.is_admin())
  with check (id=(select auth.uid()) or public.is_admin());

-- Owners may manage their own listings; admins/developer can moderate.
create policy "owners manage products" on public.products for all to authenticated
  using (owner_id=(select auth.uid()) or public.is_admin())
  with check (owner_id=(select auth.uid()) or public.is_admin());
create policy "owners manage services" on public.services for all to authenticated
  using (owner_id=(select auth.uid()) or public.is_admin())
  with check (owner_id=(select auth.uid()) or public.is_admin());
create policy "authors manage posts" on public.posts for all to authenticated
  using (author_id=(select auth.uid()) or public.is_admin())
  with check (author_id=(select auth.uid()) or public.is_admin());
create policy "owners manage partners" on public.partners for all to authenticated
  using (owner_id=(select auth.uid()) or public.is_admin())
  with check (owner_id=(select auth.uid()) or public.is_admin());
create policy "owners manage rentals" on public.rentals for all to authenticated
  using (owner_id=(select auth.uid()) or public.is_admin())
  with check (owner_id=(select auth.uid()) or public.is_admin());

create policy "owners manage product media" on public.product_media for all to authenticated
  using (exists(select 1 from public.products p where p.id=product_id and (p.owner_id=(select auth.uid()) or public.is_admin())))
  with check (exists(select 1 from public.products p where p.id=product_id and (p.owner_id=(select auth.uid()) or public.is_admin())));
create policy "owners manage rental media" on public.rental_media for all to authenticated
  using (exists(select 1 from public.rentals r where r.id=rental_id and (r.owner_id=(select auth.uid()) or public.is_admin())))
  with check (exists(select 1 from public.rentals r where r.id=rental_id and (r.owner_id=(select auth.uid()) or public.is_admin())));

-- Reviews and votes
create policy "users manage own reviews" on public.reviews for all to authenticated
  using (reviewer_id=(select auth.uid()) or public.is_admin())
  with check (reviewer_id=(select auth.uid()) or public.is_admin());
create policy "users manage own votes" on public.votes for all to authenticated
  using (user_id=(select auth.uid()) or public.is_admin())
  with check (user_id=(select auth.uid()) or public.is_admin());

-- Service requests
create policy "requesters/providers/admin manage requests" on public.service_requests for all to authenticated
  using (requester_id=(select auth.uid()) or provider_id=(select auth.uid()) or public.is_admin())
  with check (requester_id=(select auth.uid()) or provider_id=(select auth.uid()) or public.is_admin());

-- Cart
create policy "own cart" on public.carts for all to authenticated
  using (user_id=(select auth.uid()) or public.is_admin())
  with check (user_id=(select auth.uid()) or public.is_admin());
create policy "own cart items" on public.cart_items for all to authenticated
  using (exists(select 1 from public.carts c where c.id=cart_id and (c.user_id=(select auth.uid()) or public.is_admin())))
  with check (exists(select 1 from public.carts c where c.id=cart_id and (c.user_id=(select auth.uid()) or public.is_admin())));

-- Orders/payments/referrals
create policy "buyers read own orders" on public.orders for select to authenticated
  using (buyer_id=(select auth.uid()) or public.is_admin());
create policy "buyers read own order items" on public.order_items for select to authenticated
  using (exists(select 1 from public.orders o where o.id=order_id and (o.buyer_id=(select auth.uid()) or public.is_admin())));
create policy "buyers read own payments" on public.payments for select to authenticated
  using (exists(select 1 from public.orders o where o.id=order_id and (o.buyer_id=(select auth.uid()) or public.is_admin())));
create policy "admins manage orders" on public.orders for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admins manage order items" on public.order_items for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admins manage payments" on public.payments for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "owners/admin read referrals" on public.referrals for select to authenticated
  using (referrer_id=(select auth.uid()) or public.is_admin());
create policy "admins manage referrals" on public.referrals for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Activity/notifications
create policy "own activity" on public.activity for select to authenticated using (user_id=(select auth.uid()) or public.is_admin());
create policy "own activity insert" on public.activity for insert to authenticated with check (user_id=(select auth.uid()));
create policy "own notifications" on public.notifications for select to authenticated using (user_id=(select auth.uid()) or public.is_admin());
create policy "own notification update" on public.notifications for update to authenticated
  using (user_id=(select auth.uid()) or public.is_admin())
  with check (user_id=(select auth.uid()) or public.is_admin());

-- Registration requests
create policy "own registration request" on public.registration_requests for select to authenticated
  using (user_id=(select auth.uid()) or public.is_admin());
create policy "create own registration request" on public.registration_requests for insert to authenticated
  with check (user_id=(select auth.uid()));
create policy "admins manage registrations" on public.registration_requests for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Admin/developer full moderation policies where needed
create policy "admins manage reviews" on public.reviews for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admins manage notifications" on public.notifications for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Helper RPC for safe order creation: server calculates price from current products.
create or replace function public.create_order_from_cart(
  p_delivery_address text default null,
  p_notes text default null,
  p_referral_username text default null
)
returns uuid
language plpgsql
security invoker
as $$
declare
  v_uid uuid := auth.uid();
  v_cart uuid;
  v_order uuid;
  v_subtotal numeric(14,2);
begin
  if v_uid is null then raise exception 'Authentication required'; end if;

  select id into v_cart from public.carts where user_id=v_uid;
  if v_cart is null then raise exception 'Cart not found'; end if;

  if not exists (
    select 1 from public.cart_items ci join public.products p on p.id=ci.product_id
    where ci.cart_id=v_cart and p.status='published'
  ) then
    raise exception 'Cart is empty';
  end if;

  insert into public.orders(buyer_id, referral_username, delivery_address, notes)
  values(v_uid, nullif(trim(p_referral_username),''), p_delivery_address, p_notes)
  returning id into v_order;

  insert into public.order_items(order_id, product_id, seller_id, title_snapshot, unit_price, quantity, line_total)
  select v_order, p.id, p.owner_id, p.title, p.price, ci.quantity, p.price*ci.quantity
  from public.cart_items ci join public.products p on p.id=ci.product_id
  where ci.cart_id=v_cart and p.status='published';

  select coalesce(sum(line_total),0) into v_subtotal from public.order_items where order_id=v_order;
  update public.orders set subtotal=v_subtotal, total=v_subtotal where id=v_order;

  delete from public.cart_items where cart_id=v_cart;
  return v_order;
end $$;

grant execute on function public.create_order_from_cart(text,text,text) to authenticated;

-- Keep Data API exposure explicit because Supabase changed defaults for new tables in 2026.
grant select on public.products, public.product_media, public.services, public.posts, public.rentals, public.rental_media, public.reviews to anon, authenticated;
grant select, insert, update, delete on public.profiles, public.products, public.product_media, public.services,
  public.service_requests, public.reviews, public.votes, public.posts, public.partners, public.rentals,
  public.rental_media, public.carts, public.cart_items, public.orders, public.order_items, public.payments,
  public.referrals, public.activity, public.notifications, public.registration_requests to authenticated;

-- Storage buckets. Keep private evidence/doc buckets; public media can be public.
insert into storage.buckets(id,name,public) values
('avatars','avatars',true),
('product-media','product-media',true),
('post-media','post-media',true),
('rental-media','rental-media',true),
('partner-docs','partner-docs',false)
on conflict (id) do nothing;

-- Storage RLS
create policy "users upload own avatar" on storage.objects for insert to authenticated
with check (bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "users update own avatar" on storage.objects for update to authenticated
using (bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check (bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "public read avatars" on storage.objects for select to anon, authenticated using (bucket_id='avatars');

create policy "users upload media" on storage.objects for insert to authenticated
with check (
  bucket_id in ('product-media','post-media','rental-media')
  and (storage.foldername(name))[1]=(select auth.uid())::text
);
create policy "users manage media" on storage.objects for update to authenticated
using (bucket_id in ('product-media','post-media','rental-media') and (storage.foldername(name))[1]=(select auth.uid())::text)
with check (bucket_id in ('product-media','post-media','rental-media') and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "public read marketplace media" on storage.objects for select to anon, authenticated
using (bucket_id in ('product-media','post-media','rental-media'));

create policy "partners upload proof" on storage.objects for insert to authenticated
with check (bucket_id='partner-docs' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "partners read own proof" on storage.objects for select to authenticated
using (bucket_id='partner-docs' and (storage.foldername(name))[1]=(select auth.uid())::text or public.is_admin());
