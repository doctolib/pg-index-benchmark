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

Extract queries from your production that could cover most of the cases. Note that queries will be ignored if they are not using the table defined in `table_name` in your configuration file.

### Define scenarios

One scenario will define a list of indexes to use.
All these scenarios will be described on the configuration file.
The reference scenario is the first scenario to be executed. It represents the index set that you currently have in your production.

All other scenarios will be compared to this reference scenario.

```yml
- table_name: name_of_the_table_containing_the_indexes
- common_indexes:
    - index1_that_should_be_present_on_each_scenario
    - index2_that_should_be_present_on_each_scenario
- scenarios:
    - reference:
        - production_index_that_seems_useless
        - another_production_index_that_seems_useless
    - scenario_removing_both:
    - some_scenario:
        - one_candidate
    - other_scenario:
        - other_candidate
```

### How to run it
First run it in your local environment to understand how it works.
Don't believe the results when using a database that does not have the appropriate dataset.
Don't run it in production as it would block other DDL.
#### Without docker

```shell
bundle install
POSTGRES_DATABASE=mydb POSTGRES_USER=$USER ./index_benchmark.rb -c /host_files/index_benchmark.yml /host_files/queries.txt
```

#### With docker

```shell
docker build -t benchmark_tool
docker run -v $PWD:/host_files --rm -e POSTGRES_DATABASE=mydb -e POSTGRES_USER=$USER -e POSTGRES_HOST=myhost benchmark_tool ./index_benchmark.rb -c /host_files/config.yml /host_files/queries.txt
```

Note:
If you need to access a pg in a docker, you can use these options:
```shell
--link docker_container_name --network docker_network_name
```

## How it works?

`DROP INDEX` instructions are transactional. Thanks to that, we can drop some indexes, get the execution plan of a list of queries, revert, and try again the same queries with other indexes.

In other words, for each scenario:
- it opens a transaction
- it drops all indexes that are not eligible for the scenario
- it extracts the execution plan for all the select queries
- it rollbacks