#!/bin/bash
echo "Checking if db is ready..."
psql postgres://postgres:demo_pwd@localhost:5432/postgres -XAwtc 'SELECT count(*) from book;'
[[ "2000000" == $(psql postgres://postgres:demo_pwd@localhost:5432/postgres -XAwtc 'SELECT count(*) from book;') ]]
