CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE book (
    id serial PRIMARY KEY,
    title text,
    price bigint,
    available boolean
);

-- Mocking dataset
INSERT INTO book (title, price, available)
    SELECT
        left(md5(random()::text), 3+(17*random())::integer),
        (random() * 100)::bigint,
        (random() > 0.8)
    FROM generate_series(1, 2000000);

-- Initial indexes
CREATE INDEX book_price_idx
    ON book (price);

CREATE INDEX book_available_title_idx
    ON book USING gin (title gin_trgm_ops);

CREATE INDEX book_available_idx
    ON book (available);

-- Candidate indexes
CREATE INDEX book_price_available_partial
    ON book (price) where available IS true;

CREATE INDEX book_price_available_is_expr_idx
    ON book (price, available);

CREATE INDEX book_available_is_expr_price_idx
    ON book (available, price);

CREATE INDEX book_title_idx
    ON book (title);

ANALYZE book;

ALTER user postgres SET max_parallel_workers_per_gather = 0;