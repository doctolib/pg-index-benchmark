#!/usr/bin/env bash
set -e
echo "Checking if db is ready..."
[[ -e '/var/lib/postgresql/db_scripts_done' ]]
pg_isready -U postgres
