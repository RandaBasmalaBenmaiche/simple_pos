create extension if not exists pgcrypto;

create table if not exists public.stores (
  sync_id uuid primary key,
  local_id bigint not null,
  device_id uuid,
  updated_at timestamptz not null,
  name text not null,
  location text,
  is_active integer not null default 1
);

create table if not exists public.stock (
  sync_id uuid primary key,
  local_id bigint not null,
  device_id uuid,
  updated_at timestamptz not null,
  store_id bigint not null,
  productName text not null,
  productPrice text,
  productBuyingPrice text,
  productCodeBar text,
  productQuantity text
);

create table if not exists public.customers (
  sync_id uuid primary key,
  local_id bigint not null,
  device_id uuid,
  updated_at timestamptz not null,
  store_id bigint not null,
  name text not null,
  phone text,
  debt double precision not null default 0
);

create table if not exists public.debt_payments (
  sync_id uuid primary key,
  local_id bigint not null,
  device_id uuid,
  updated_at timestamptz not null,
  store_id bigint not null,
  customer_id bigint not null,
  customer_sync_id uuid,
  customer_name text not null,
  customer_phone text,
  amount_paid double precision not null,
  payment_date timestamptz not null
);

create table if not exists public.invoices (
  sync_id uuid primary key,
  local_id bigint not null,
  device_id uuid,
  updated_at timestamptz not null,
  store_id bigint not null,
  date timestamptz not null,
  total text not null,
  customer_name text,
  customer_id bigint,
  customer_sync_id uuid,
  total_debt_customer text not null default '0',
  profit text not null default '0'
);

create table if not exists public.invoice_items (
  sync_id uuid primary key,
  local_id bigint not null,
  device_id uuid,
  updated_at timestamptz not null,
  invoice_id bigint not null,
  invoice_sync_id uuid,
  productCodeBar text not null default '',
  productName text not null,
  quantity text not null default '0',
  price text not null default '0',
  profit text not null default '0',
  totalPrice text not null default '0'
);

alter table public.debt_payments
  add column if not exists customer_sync_id uuid;

alter table public.invoices
  add column if not exists customer_sync_id uuid;

alter table public.invoice_items
  add column if not exists invoice_sync_id uuid;

create index if not exists idx_stock_store_id on public.stock (store_id);
create index if not exists idx_customers_store_id on public.customers (store_id);
create index if not exists idx_debt_payments_store_id on public.debt_payments (store_id);
create index if not exists idx_invoices_store_id on public.invoices (store_id);
create index if not exists idx_invoice_items_invoice_id on public.invoice_items (invoice_id);

alter table public.stores enable row level security;
alter table public.stock enable row level security;
alter table public.customers enable row level security;
alter table public.debt_payments enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;

drop policy if exists stores_authenticated_access on public.stores;
create policy stores_authenticated_access
on public.stores
for all
to authenticated
using (true)
with check (true);

drop policy if exists stock_authenticated_access on public.stock;
create policy stock_authenticated_access
on public.stock
for all
to authenticated
using (true)
with check (true);

drop policy if exists customers_authenticated_access on public.customers;
create policy customers_authenticated_access
on public.customers
for all
to authenticated
using (true)
with check (true);

drop policy if exists debt_payments_authenticated_access on public.debt_payments;
create policy debt_payments_authenticated_access
on public.debt_payments
for all
to authenticated
using (true)
with check (true);

drop policy if exists invoices_authenticated_access on public.invoices;
create policy invoices_authenticated_access
on public.invoices
for all
to authenticated
using (true)
with check (true);

drop policy if exists invoice_items_authenticated_access on public.invoice_items;
create policy invoice_items_authenticated_access
on public.invoice_items
for all
to authenticated
using (true)
with check (true);

grant usage on schema public to authenticated;
grant all on public.stores to authenticated;
grant all on public.stock to authenticated;
grant all on public.customers to authenticated;
grant all on public.debt_payments to authenticated;
grant all on public.invoices to authenticated;
grant all on public.invoice_items to authenticated;
