# Index benchmark tool

This tool helps you to benchmark the index changes you could do on Aurora PostgreSQL instances. 

## Why?

When the database is growing, we often add more and more indexes, causing some write amplification to keep each index up-to-date. At some point you may need to rationalize your indexes. But when removing an index, how can we reduce performance degradation risks?

### [pg_hint_plan](https://github.com/ossc-db/pg_hint_plan) alternative

This extension that could be used to force the execution plan of a query. However we need to provide the new execution plan for every query we test. When the db receives about 100+ different queries for the same table, it's not scalable.

### [HypoPG](https://github.com/HypoPG/hypopg)

This extension is not available on Aurora, so we can’t use it on our usual cluster.

- It seems over complicated to recreate a Vanilla Postgres instance with the preprod dataset to be able to use this extension.
- It would not representative if we use this extension locally, as we can’t have a representative dataset.


## Run the demo
A demo is included in this project. It creates a database with its dataset and compares some indexes.
To run the demo:
```bash
    docker compose up --abort-on-container-exit --build
```

## How to use it with your own schema?

### Choose a table

Choose one table to focus on. This tool will only check the impact on queries using this table.

### Prepare a clone in Aurora

Clone your production instance
If you want to try indexes that are not currently in production, create all of them now. This is the longest part of the process.

### Extract a representative set of queries

Extract queries from your production that could cover most of the cases. Note that queries will be ignored if they are not using the table defined in `table_name` in your configuration file. This file should be provided as an argument of the command.

In our example, we choose to extract queries in the file named `queries.sql`.

To extract these queries, you could for example enable logs in your PG server and tune these config variables:
- `log_statement` to enable all logs
- `log_statement_sample_rate` to introduce some sampling and avoid too many queries
And then extract queries by downloading logs.

Every queries must ends with a `;`.
We suggest that you put on SQL query on a single line, each query ending with `;`.

[Pgbadger](https://pgbadger.darold.net/) could also help you to extract queries from the raw logs.

### Define scenarios

One scenario will define a list of indexes to use.
All these scenarios will be described on the configuration file.
The reference scenario is the first scenario to be executed. It represents the index set that you currently have in your production.

All other scenarios will be compared to this reference scenario.

These scenarios should be define in your `config.yml` file (or use `-c` options to use an other file).
You can find an example in `config.sample.yml`

```yml
#config.yml example
table_name: name_of_the_table_containing_the_indexes
common_indexes:
    - index1_that_should_be_present_on_each_scenario
    - index2_that_should_be_present_on_each_scenario
scenarios:
    reference:
        - production_index_that_seems_useless
        - another_production_index_that_seems_useless
    scenario_removing_both:
    some_scenario:
        - one_candidate
    other_scenario:
        - other_candidate
```
### Install

Install ruby 3.2.1, then:

```bash
gem build pg_index_benchmark.gemspec && gem install ./pg_index_benchmark-0.0.0.gem
```

### Run
First run it in your local environment to understand how it works.
Don't believe the results when using a database that does not have the appropriate dataset.
Don't run it in production as it would block other DDL.

```shell
POSTGRES_DATABASE=mydb POSTGRES_USER=$USER pg-index-benchmark -c /host_files/index_benchmark.yml /host_files/queries.sql
```

## Examples

Standard execution:
```text
- Playing scenario: reference
Connecting to postgres@db:5432/postgres ...
  - Adding indexes to reference: book_price_idx book_available_title_idx book_available_idx
  - Dropping 4 indexes: book_price_available_partial book_price_available_idx book_available_price_idx book_title_idx
  - Running queries (2 times each)...
  - 5 queries run

- Playing scenario: scenario1
  - Adding indexes to reference: book_price_available_partial
  - Dropping 6 indexes: book_price_idx book_available_title_idx book_available_idx book_price_available_idx book_available_price_idx book_title_idx
  - Running queries (2 times each)...
  - 5 queries run
...
----------------------------------------------------
Query 9602a2c952652489ab7b813a3beabd058a0e0556:
SELECT count(*) from book where price > 75 and available = true;

Actual Total Time:
  reference  188.837
  scenario1  227.165 ❌️
  scenario2  79.717 ✅
  scenario3  86.325 ✅
  scenario4  423.53 ❌️
  scenario5  62.63 ✅

Total Cost:
  reference  29102.26
  scenario1  44399.16 ❌️
  scenario2  27665.02 ✅
  scenario3  22028.95 ✅
  scenario4  44399.16 ❌️
  scenario5  22028.95 ✅

Shared Hit Blocks:
  reference  19577
  scenario1  19159 ✅
  scenario2  19715 ❌️
  scenario3  19248 ✅
  scenario4  19159 ✅
  scenario5  19248 ✅

Used indexes:
  reference  book_available_idx
  scenario1  
  scenario2  book_price_available_idx
  scenario3  book_available_price_idx
  scenario4  
  scenario5  book_available_price_idx
...
```

Detailed view for a specific query:
```text
---- Plan for reference ----
Finalize Aggregate  (cost=31312.56..31312.57 rows=1 width=24) (actual time=85.961..86.542 rows=1 loops=1)
        Output: min(price), max(price), count(*)
        Buffers: shared hit=192 read=15537
        ->  Gather  (cost=31312.33..31312.54 rows=2 width=24) (actual time=85.862..86.537 rows=3 loops=1)
...

---- Plan for expr_available_is_true ----
Finalize Aggregate  (cost=31312.56..31312.57 rows=1 width=24) (actual time=91.614..92.226 rows=1 loops=1)
        Output: min(price), max(price), count(*)
        Buffers: shared hit=288 read=15441
        ->  Gather  (cost=31312.33..31312.54 rows=2 width=24) (actual time=91.547..92.220 rows=3 loops=1)
...

---- Plan for partial_idx ----
Finalize Aggregate  (cost=31312.56..31312.57 rows=1 width=24) (actual time=86.324..86.913 rows=1 loops=1)
        Output: min(price), max(price), count(*)
        Buffers: shared hit=480 read=15249
        ->  Gather  (cost=31312.33..31312.54 rows=2 width=24) (actual time=86.230..86.907 rows=3 loops=1)
...
```

## How it works?

`DROP INDEX` instructions are transactional. Thanks to that, we can drop some indexes, get the execution plan of a list of queries, revert, and try again the same queries with other indexes.

In other words, for each scenario:
- it opens a transaction
- it drops all indexes that are not eligible for the scenario
- it extracts the execution plan for all the select queries
- it rollbacks

**Scenarios without impact**: this means that the execution plan is the same for both the _scenario without impact_ and the _reference_ scenario.
## Run tests

```bash
bundle exec rake
```
