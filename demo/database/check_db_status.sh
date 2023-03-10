#!/bin/bash
echo "Checking if db is ready..."
psql postgres://postgres:demo_pwd@localhost:5432/postgres -XAwtc 'SELECT 1 / count(*) from book;'