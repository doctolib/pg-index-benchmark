SELECT * from book where id = 123;
SELECT count(*) from book where price > 75 and available = true;
SELECT count(*) FROM book WHERE price > 95 and available IS true;
SELECT count(*) FROM book where title = (select title from book limit 1) and available;
SELECT min(price), max(price), count(*) FROM book LIMIT 10;
