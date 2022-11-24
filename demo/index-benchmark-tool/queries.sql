SELECT min(price), max(price), count(*) FROM book;
SELECT title FROM book WHERE price > 1000 AND available IS true order by price desc LIMIT 20;
SELECT title FROM book WHERE available IS true;
SELECT min(price) FROM book WHERE price > 2000 AND available IS true;
