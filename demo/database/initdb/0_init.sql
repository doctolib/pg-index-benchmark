CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE books (
    id serial PRIMARY KEY,
    title text,
    price bigint,
    available boolean
);

-- Mocking dataset
INSERT INTO books (title, price, available)
    SELECT
        left(md5(random()::text), 3+(17*random())::integer),
        (random() * 100)::bigint,
        (random() > 0.8)
    FROM generate_series(1, 2000000);

-- Initial indexes
CREATE INDEX books_price_idx
    ON books (price);

CREATE INDEX books_available_title_idx
    ON books USING gin (title gin_trgm_ops);

CREATE INDEX books_available_idx
    ON books (available);

-- Candidate indexes
CREATE INDEX books_price_available_partial
    ON books (price) where available IS true;

CREATE INDEX books_price_available_idx
    ON books (price, available);

CREATE INDEX books_available_price_idx
    ON books (available, price);

CREATE INDEX books_title_idx
    ON books (title);

ANALYZE books;

ALTER user postgres SET max_parallel_workers_per_gather = 0;