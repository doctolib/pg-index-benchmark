BEGIN;
CREATE TABLE book (
    id serial PRIMARY KEY,
    title text,
    price bigint,
    available boolean
);

INSERT INTO book (title, price, available)
    SELECT
        left(md5(random()::text), 3+(17*random())::integer),
        (random()*100)::bigint,
        (random() > 0.8)
    FROM generate_series(1, 2000000);

CREATE INDEX book_price_partial_idx
    ON book (price)
    WHERE available IS true;

CREATE INDEX book_price_idx
    ON book (price);

CREATE INDEX book_title_available_idx
    ON book (title, available);

CREATE INDEX book_available_is_expr_idx
    ON book (price, (available IS true));
COMMIT;
VACUUM ANALYZE book;
