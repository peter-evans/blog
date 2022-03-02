---
title: "Gaps and islands: Merging contiguous ranges"
date: 2022-03-02T22:16:23+09:00
author: Peter Evans
description: "Merging rows of contiguous ranges in PostgreSQL using a solution to the gaps and islands problem"
keywords: ["gaps", "islands", "merging", "contiguous", "ranges", "postgres", "postgresql"]
---

I recently needed a solution to merge rows of contiguous ranges in a PostgreSQL table.
The approach I took was based on solutions to the [gaps and islands](https://www.red-gate.com/simple-talk/databases/sql-server/t-sql-programming-sql-server/gaps-islands-sql-server-data/) problem.

Note that you can avoid needing a solution like this if you are able to upgrade to PostgreSQL 14 and take advantage of [multirange](https://www.postgresql.org/docs/14/rangetypes.html) types. If not, read on!

Requirements for my particular use case:
- Find gaps and islands between rows containing a numerical range, expressed as two columns, `from_id` and `to_id`.
- Merge the islands (rows of contiguous ranges) into a single row.
- Perform the merge and update the table in a single SQL transaction to avoid race conditions with concurrent processes.

### Solution

This is the table we'll use for the following examples.
`set_id` is a set of ranges, and the merge operation targets a specific set.
The `EXCLUDE` constraint is added to prevent overlapping ranges from being inserted into the table.

```sql
CREATE TABLE ranges (
  set_id integer NOT NULL,
  from_id bigint NOT NULL,
  to_id bigint NOT NULL,
  EXCLUDE USING GIST (
    set_id WITH =,
    int8range(from_id, to_id, '[]') WITH &&
  )
);
```

#### Identify islands

Identifying islands is done in two steps.
The first step adds the column `island_start`, marking the start of an island.

```sql
SELECT
  *,
  CASE from_id - LAG(ranges.to_id)
      OVER (ORDER BY ranges.from_id ASC)
    WHEN NULL THEN 1
    WHEN 1 THEN 0
    ELSE 1
  END AS island_start
FROM ranges
WHERE set_id = 1;
```

The query uses the `LAG` [window function](https://www.postgresql.org/docs/current/functions-window.html) to evaluate the previous row, and determine if the current row is the start of an island or not. Since the first row has no previous row, we must check for `NULL` to handle that case.

Here is an example result, showing the start of four islands have been marked.

| set_id | from_id | to_id | island_start |
| ------ | ------- | ----- | ------------ |
|      1 |       1 |    10 |            1 |
|      1 |      11 |    15 |            0 |
|      1 |      16 |    20 |            0 |
|      1 |      25 |    30 |            1 |
|      1 |      31 |    40 |            0 |
|      1 |      45 |    50 |            1 |
|      1 |      55 |    60 |            1 |
|      1 |      61 |    80 |            0 |

The next step is to give each island a unique ID, so that we can identify which island each row belongs to.

```sql
WITH range_islands AS (
  SELECT
    *,
    CASE from_id - LAG(ranges.to_id)
        OVER (ORDER BY ranges.from_id ASC)
      WHEN NULL THEN 1
      WHEN 1 THEN 0
      ELSE 1
    END AS island_start
  FROM ranges
  WHERE set_id = 1
)
SELECT
  *,
  SUM(range_islands.island_start)
    OVER (ORDER BY range_islands.from_id ASC) AS island_id
FROM range_islands;
```

The query uses `SUM` as a windowed function over the `island_start` column in the result of our previous query.
This creates a rolling sum, where each island start row increases the sum by one, giving us a unique ID.

Here is an example result, showing four islands with their unique IDs.

| set_id | from_id | to_id | island_start | island_id |
| ------ | ------- | ----- | ------------ | --------- |
|      1 |       1 |    10 |            1 |         1 |
|      1 |      11 |    15 |            0 |         1 |
|      1 |      16 |    20 |            0 |         1 |
|      1 |      25 |    30 |            1 |         2 |
|      1 |      31 |    40 |            0 |         2 |
|      1 |      45 |    50 |            1 |         3 |
|      1 |      55 |    60 |            1 |         4 |
|      1 |      61 |    80 |            0 |         4 |

#### Merge islands

Once each row has an ID, identifying what island it belongs to, the next step is straightforward.
We group by `island_id` and find the `MIN` and `MAX` of the contiguous ranges.

```sql
WITH range_islands AS (
  SELECT
    *,
    CASE from_id - LAG(ranges.to_id)
        OVER (ORDER BY ranges.from_id ASC)
      WHEN NULL THEN 1
      WHEN 1 THEN 0
      ELSE 1
    END AS island_start
  FROM ranges
  WHERE set_id = 1
),
range_island_ids AS (
  SELECT
    *,
    SUM(range_islands.island_start)
      OVER (ORDER BY range_islands.from_id ASC) AS island_id
  FROM range_islands
)
SELECT
  set_id,
  MIN(from_id) AS from_id,
  MAX(to_id) AS to_id
FROM range_island_ids
GROUP BY set_id, island_id;
```

Here is the result, showing the four merged islands.

| set_id | from_id | to_id |
| ------ | ------- | ----- |
|      1 |       1 |    20 |
|      1 |      25 |    40 |
|      1 |      45 |    50 |
|      1 |      55 |    80 |

#### Update islands

Updating the table with the merged rows takes place in two steps.
Firstly, any rows that were identified as not being the start of an island can be deleted.

```sql
DELETE FROM ranges
USING range_islands
WHERE
  ranges.set_id = range_islands.set_id AND
  ranges.from_id = range_islands.from_id AND
  range_islands.island_start = 0
```

Secondly, the remaining rows representing the islands are updated with the `to_id` of the merged ranges.

```sql
UPDATE ranges SET
  to_id = merged_ranges.to_id
FROM merged_ranges
WHERE
  ranges.set_id = merged_ranges.set_id AND
  ranges.from_id = merged_ranges.from_id
```

That completes all the steps necessary to execute a merge of contiguous ranges in a single PostgreSQL transaction.
See [gaps-and-islands](https://github.com/peter-evans/gaps-and-islands) for a complete example.
You can also check out the example in [dbfiddle](https://dbfiddle.uk/?rdbms=postgres_12&fiddle=cd6bae615d8caa90eff0fd275e292cb5).
