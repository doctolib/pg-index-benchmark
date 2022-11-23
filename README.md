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

## How to use it?

### Choose a table

Choose one table to focus on. This tool will only check the impact on queries using this table.

### Prepare a clone in Aurora

Clone your production instance
If you want to try indexes that are not currently in production, create all of them now. This is the longest part of the process.

### Extract a representative set of queries

Extract queries from your production that could cover most of the cases. Note that queries will be ignored if they are not using the table defined in `table_name` in your configuration file. This file should be provided as an argument of the command.

To extract these queries, you could for example enable logs in your PG server and tune these config variables:
- `log_statement` to enable all logs
- `log_statement_sample_rate` to introduce some sampling and avoid too many queries
And then extract queries by downloading logs.

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

### How to run it
First run it in your local environment to understand how it works.
Don't believe the results when using a database that does not have the appropriate dataset.
Don't run it in production as it would block other DDL.
#### Without docker
First install ruby 3.1.2, then:

```shell
bundle install
POSTGRES_DATABASE=mydb POSTGRES_USER=$USER -c /host_files/index_benchmark.yml /host_files/queries.txt
```

#### With docker

```shell
docker build -t benchmark_tool .
docker run -v $PWD:/host_files --rm -e POSTGRES_DATABASE=mydb -e POSTGRES_USER=$USER -e POSTGRES_HOST=myhost benchmark_tool -c /host_files/config.yml /host_files/queries.txt
```

Note:
If you need to access a pg in a docker, you can use these options:
```shell
--link docker_container_name --network docker_network_name
```

## Examples

Standard execution:
```text
- Playing scenario: reference
  - Adding indexes to reference: foo_value_idx
  - Dropping 1 indexes: foo_value_idx1

- Playing scenario: other_index
  - Adding indexes to reference: foo_value_idx1
  - Dropping 1 indexes: foo_value_idx

----------------------------------------------------
Query 23a71521e8c118fdb9e9f7c5259dff7c79e5c54e:
select * from foo where value between 100 and 150;

Actual Total Time:
  reference    7.234
  other_index  0.013 ✅

Total Cost:
  reference    2041.0
  other_index  11.97 ✅

Shared Hit Blocks:
  reference    541
  other_index  10 ✅

Shared Read Blocks:
  reference    0
  other_index  0 ✅

Actual Rows:
  reference    5
  other_index  5 ✅

Used indexes:
  reference    
  other_index  foo_value_idx1

For these queries each scenario was using the same indexes: cf4073b3fd4ad51cf1b486b575412d63002e44fc 8b5a89bad53abe39bbc4a4fbeff2b1970d1adcee
```

Detailed view for a specific query:
```text
Full details for query 23a71521e8c118fdb9e9f7c5259dff7c79e5c54e
- Playing scenario: reference
  - Adding indexes to reference: foo_value_idx
  - Dropping 1 indexes: foo_value_idx1
select * from foo where value between 100 and 150;

- Playing scenario: other_index
  - Adding indexes to reference: foo_value_idx1
  - Dropping 1 indexes: foo_value_idx
select * from foo where value between 100 and 150;

---- Plan for reference ----
Seq Scan on public.foo  (cost=0.00..2041.00 rows=2 width=12) (actual time=1.451..7.254 rows=5 loops=1)
        Output: id, value
        Filter: ((foo.value >= 100) AND (foo.value <= 150))
        Rows Removed by Filter: 99995
        Buffers: shared hit=541
      Planning Time: 0.113 ms
      Execution Time: 7.259 ms

---- Plan for other_index ----
Bitmap Heap Scan on public.foo  (cost=4.31..11.97 rows=2 width=12) (actual time=0.010..0.014 rows=5 loops=1)
        Output: id, value
        Recheck Cond: ((foo.value >= 100) AND (foo.value <= 150))
        Heap Blocks: exact=5
        Buffers: shared hit=10
        ->  Bitmap Index Scan on foo_value_idx1  (cost=0.00..4.30 rows=2 width=0) (actual time=0.008..0.008 rows=5 loops=1)
              Index Cond: ((foo.value >= 100) AND (foo.value <= 150))
              Buffers: shared hit=5
      Planning Time: 0.095 ms
      Execution Time: 0.020 ms
```

## How it works?

`DROP INDEX` instructions are transactional. Thanks to that, we can drop some indexes, get the execution plan of a list of queries, revert, and try again the same queries with other indexes.

In other words, for each scenario:
- it opens a transaction
- it drops all indexes that are not eligible for the scenario
- it extracts the execution plan for all the select queries
- it rollbacks

