create table users (
    id uuid primary key,
    player_name varchar(40) not null,
    gold integer not null default 0,
    rank_points integer not null default 0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table cards (
    id varchar(80) primary key,
    name varchar(80) not null,
    type varchar(20) not null,
    race varchar(20) not null,
    attr varchar(20) not null,
    cost integer not null,
    attack integer,
    health integer,
    art integer not null,
    text varchar(300) not null,
    rarity varchar(20) not null default '일반',
    enabled boolean not null default true
);

create table user_cards (
    user_id uuid not null references users(id) on delete cascade,
    card_id varchar(80) not null references cards(id),
    quantity integer not null check (quantity >= 0),
    primary key (user_id, card_id)
);

create table decks (
    id uuid primary key,
    user_id uuid not null references users(id) on delete cascade,
    name varchar(60) not null,
    is_selected boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table deck_cards (
    deck_id uuid not null references decks(id) on delete cascade,
    card_id varchar(80) not null references cards(id),
    quantity integer not null check (quantity > 0),
    primary key (deck_id, card_id)
);

create table matches (
    id uuid primary key,
    user_id uuid not null references users(id) on delete cascade,
    mode varchar(20) not null,
    opponent_type varchar(20) not null,
    result varchar(20) not null default 'pending',
    gold_delta integer not null default 0,
    rank_delta integer not null default 0,
    reward_card_id varchar(80) references cards(id),
    created_at timestamptz not null default now(),
    completed_at timestamptz
);

create index idx_decks_user_id on decks(user_id);
create index idx_matches_user_id_created_at on matches(user_id, created_at desc);
