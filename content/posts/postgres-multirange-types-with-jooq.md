---
title: "Using Postgres multirange types with jOOQ"
date: 2022-03-19T17:54:23+09:00
author: Peter Evans
description: "Custom jOOQ binding and converter for Postgres multirange types"
keywords: ["postgres", "postgresql", "multirange", "types", "jooq", "binding", "converter", "kotlin"]
---

PostgreSQL 14 introduces built-in [multirange types](https://www.postgresql.org/docs/14/rangetypes.html).
The existing range types store the beginning and end value of a single range, but the new multirange types can store a list of non-contiguous ranges.

By default Postgres outputs the built-in range types in a canonical form, where the lower bound is inclusive (`[`) and the upper bound is exclusive (`)`).
```
SELECT id_ranges FROM example_table;
 id_ranges
----------------
 {[1,21),[25,41),[45,51),[55,81)}
(1 row)
```

When adding a range contiguous with an existing range, the ranges are automatically merged so that it always outputs non-contiguous ranges.
```
UPDATE example_table SET id_ranges = id_ranges + '{[21, 24]}' RETURNING *;
 id_ranges
----------------
 {[1,41),[45,51),[55,81)}
(1 row)
```

### Using with jOOQ

As of writing, support for multirange types is [not yet available in jOOQ](https://github.com/jOOQ/jOOQ/issues/13172).
The good news is that jOOQ has support for defining custom bindings and converters to work with these types.

For my use case I needed a binding for the `int8multirange` type, but this example could easily be modified to apply to other range types.

The first step is to define a data class for the type. The secondary constructor is optional for convenience.

```kotlin
data class Int8MultiRange(
    val value: List<LongRange> = emptyList()
) {
    constructor(vararg ranges: LongRange) : this(ranges.toList())
}
```

Then create a `Converter` which handles conversion between the string form of the `int8multirange` type and our `Int8MultiRange` class.

```kotlin
class Int8MultiRangeConverter : Converter<String, Int8MultiRange> {
    private val regex = "\\[(.*?),(.*?)\\)".toRegex()

    override fun from(databaseObject: String?): Int8MultiRange? {
        return databaseObject?.let {
            val matches = regex.findAll(databaseObject.toString())
            Int8MultiRange(
                matches.map {
                    val (start, end) = it.destructured
                    LongRange(
                        start.toLong(),
                        end.toLong() - 1
                    )
                }.toList()
            )
        }
    }

    override fun to(userObject: Int8MultiRange?): String? {
        return userObject?.let { ranges ->
            ranges.value.joinToString(separator = ",", prefix = "{", postfix = "}") {
                "[${it.first},${it.last + 1})"
            }
        }
    }

    override fun fromType(): Class<String> {
        return String::class.java
    }

    override fun toType(): Class<Int8MultiRange> {
        return Int8MultiRange::class.java
    }
}
```

Next, create a jOOQ `Binding` to make use of our converter.

```kotlin
class Int8MultiRangeBinding : Binding<String, Int8MultiRange> {
    override fun converter(): Converter<String, Int8MultiRange> {
        return Int8MultiRangeConverter()
    }

    override fun sql(ctx: BindingSQLContext<Int8MultiRange>) {
        ctx.render()
            .visit(DSL.`val`(ctx.convert(converter()).value()))
            .sql("::int8multirange")
    }

    ...
}
```

Finally, we can create a jOOQ `field`, setting the `DataType` with our binding.

```kotlin
    private val rangesField = field(
        name("example_table", "id_ranges"),
        SQLDataType.VARCHAR.asConvertedDataType(Int8MultiRangeBinding())
    )
```

See repository [jOOQ-pg-int8multirange](https://github.com/peter-evans/jOOQ-pg-int8multirange) for a complete example with tests.
