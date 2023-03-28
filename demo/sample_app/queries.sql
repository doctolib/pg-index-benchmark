SELECT * from books where id = 123;
SELECT count(*) from books where price > 75 and available = true;
SELECT count(*) FROM books WHERE price > 95 and available IS true;
SELECT count(*) FROM books where title = (select title from books limit 1) and available;
SELECT min(price), max(price), count(*) FROM books LIMIT 10;
