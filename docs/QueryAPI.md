---
title: Query API
nav_order: 5
layout : default
---

# Riak KV - Query API
{: .d-inline-block }

Available from Riak 3.4.0
{: .label .label-purple }

Secondary indexes may be added to Riak objects, and Riak provides a Query API for those indexes.  The API supports range queries, to be run across the sorted terms on an index, but the terms may also contain projected attributes appended to the sort key.  The Query API can be passed evaluation and filter expressions: to first evaluate the term to extract the attributes, and then filter the terms by testing the attribute values against query conditions.

Through this combination of querying ranges and filtering on projected attributes, the API can support conjunction queries.  The capability and efficiency of these conjunction queries is dependent on work in the application to map the object schema to a set of index terms with a suitable combination of sort keys and attributes.  The queries are distributed across the cluster, running in parallel across different partitions of the data (the vnodes); and through that parallelism offer low-latency responses to relatively complex queries, even where significant numbers of index entries are covered by the range of the query.

The result sets for queries are not limited to returning lists of object keys, there is also support in the Query API for different accumulation options.  As well as returning object keys, accumulation options can be used to efficiently count results, and group both results and counts by specific projected attributes.

As well as single queries the API can also handle combination queries.  In combination queries, multiple queries are run as part of the same request and the results of each query are combined using a set operation before results are accumulated to construct the response.  Those set operations are also distributed across the cluster for efficiency; the application of a set operation happens at the scale of the vnode, not the scale of the cluster.  All combination queries are run on a single snapshot per vnode; so the results should always be consistent from the perspective of each potential key in the result set.

For further detail on the Query API:

- [Adding Index Entries to Objects](#secondary-indexes---adding-index-entries-to-an-object)
- [Overview of querying those index entries](#secondary-indexes---querying-index-entries-overview)
- [An example people search](#example-1---a-simple-people-search-index)
- [An alternative example for people search](#example-2---an-alternative-people-search)
- [An example using the API for reporting](#example-3---reporting-index)
- [Setting performance expectations for queries](#performance-and-efficiency)
- [A more formal description of the Query API](#query---definition)
- [An overview of the expected performance of queries in Riak](#performance-and-efficiency)
- [Some notes on the underlying implementation](#notes-on-implementation)

## Secondary Indexes - Adding Index Entries to an Object

Querying in Riak is based around secondary indexes.  A Riak secondary index entry is a combination of a field, a term and an object key: where a field is a name for an index within a bucket, and a term is a sortable binary string that represents a value for a given key on that index, and the object key is the standard result of the query.  All indexes and queries are limited to the scope of a single Bucket.

Indexes are added using [the Object API](./ObjectAPI.md#index-entries).

- When an object is PUT into Riak, the PUT should include ALL the index entries for that object - the entirety of the current expected state.  Internally Riak will calculate the delta from the previously stored index entries, and only make the necessary key changes.
- An individual object can have an unlimited number of index entries in total, and an unlimited number of terms on any given field.
- When an object is fetched from Riak using the Object API, it will be returned with all its current Index values.

There is no direct support for schema management within Riak, as Riak is designed to act independently of the format and the content of the application-provided object body.  It is expected that for an application to make use of secondary indexes within Riak, the object-handling logic within the application will require an extension; where that extension will examine the object body, and calculate the required index entries before completing a PUT.  As the schema is managed externally to Riak, schema changes are also required to be managed within the application.  Consideration of how to make such schema changes is the responsibility of the application designer e.g. versioning, rolling updates, querying-planning during transition etc.

The design of secondary indexes in Riak make them best suited to environments where the query demands are relatively predictable in advance, and also the approximate cardinality of the data elements.  The [expected performance of queries is governed by the factors highlighted in the performance section](#performance-and-efficiency), and consideration of those factors is required when defining the indexes and planning the queries to be used.  Riak contains no query planning logic; the optimal path to resolve a query needs to be determined by the application.

Index entries can be made up of simple sort keys:

e.g. `surname_bin: SMITH`

Index terms can be extended by projecting additional attributes onto the sort key, appended to the sort key, e.g. in this case by appending the date of birth to the sort key, separating the two parts using `|` as a delimiter:

e.g. `surnamedob_bin: SMITH|19790613`

There is no pre-defined way to map project attributes onto an index term in Riak; the definition, formatting and appending of projected attributes is the responsibility of the application.  Projected attributes are extracted from index terms at query time, normally using an `evaluation_expression` within the Query API; and so index entries should be added so that the extraction is supported by the [expression language](#evaluation-expression---definition).

Different extraction functions within the Query API `evaluation_expression` have different costs at query time, but also have differing impacts with regards to flexibility in support of schema change.  For example, using an `index` evaluation function is more efficient than a `kvsplit` function at query time, but when changing the schema the use of `kvsplit` may simplify the management of that change.

## Secondary Indexes - Querying Index Entries Overview

The Query API is intended to provide flexible and performant functionality in the context of a Key-Value store:

{: .highlight }
> The aim of Riak development is to provide a database that performs efficient, scalable and predictable CRUD operations, and is just-queryable-enough to avoid the need of third party database integration in most use cases.

Riak does support via [an external replication API](./ReplicationGuide.md#replication-api), the ability to manage replication and reconciliation to third party query engines (e.g. OpenSearch), should more complex query support be required.  The automation of such integration is outside of the current functional scope of Riak.

### Querying - Functional Summary

A query consists of the [following components](#query_list-required):

- An index field (required).
- A query range (required).
- An `evaluation_expression` (optional); used to decode projected attributes to provide a map of those attributes to be processed via a filter expression.
- A `filter_expression` (optional); used to filter results in/out of queries by applying checks to a map of projected attributes discovered on the index entry (i.e. the map being the output of an evaluation expression).
- A `regular_expression` (optional); a potentially less flexible, but sometimes more performant alternative to evaluation and filter expressions - where a regular expression is used to match against a whole term, including the unevaluated projected attributes, in order to filter the entry into the query results.
  - The regular expression is primarily provided for backwards compatibility with the [legacy index-query feature used prior to Riak 3.4](./OtherAPI.md#legacy-query-api).  The use of evaluation and filter expressions is preferred to the use of regular expressions, and are often at least as performant as regular expressions.
  - Regular expressions are [PCRE-style regular expressions](https://www.pcre.org/), but are not compiled prior to being used.
  - Escaping regular expressions correctly, so that they can be passed via the JSON-based Query API, may add significant complexity to the development process.

Queries can be sent individually, but it is also possible to send multiple queries along with an aggregation expression to define how the query results will be combined (e.g. using `INTERSECT`, `UNION`, `NOT`) - where Riak will provide a single set of results as a response based on the aggregation expression.

Queries, both single and aggregated, also support an optional accumulation method; a mechanism for describing the type of results required, and how those results should be sorted (e.g. returning just object keys, keys by term, keys by specific projected attribute, counts, counts by attribute value etc).

The JSON query object can contain `substitutions`, a JSON array mapping keys with any string-based tag to values.  Substitutions are useful when a single query template is to be used within the application client (i.e. to substitute into a standard query the user input), or to avoid difficulty with escaping special characters embedded within query elements.  Within the API, a prefix of `:` to a reference indicates that the reference should be replaced using an entry in the `substitutions` map.

In the filter and evaluation expressions, projected attribute keys are identified through use of a `$` prefix.  All evaluations start with two default attributes: the whole term (`$term`) and the object key (`$key`).

The API also supports options to govern pagination of results, and timeout of queries.

Query requests are made by posting [a JSON object which defines the query](#query-json---definition) to a HTTP URI on Riak of `types/<BucketType>/buckets/<Bucket>/query`.  The results are returned as a JSON object, the format of those results is determined by the `accumulation_option` requested.

### Querying - Non-functional Summary

The distributed nature of querying in Riak means that large numbers of results can be processed and filtered with relatively low latency.  The processing of queries is naturally parallel within Riak, and is performant as a result.

However, in the development of Riak it is assumed that in most production Riak systems less than 1% of all transactions are secondary index queries, and this is reflected in the transaction mix of pre-release non-functional testing.  A secondary index query will normally be between 1 order and 2 orders of magnitude more expensive in terms of CPU cost, spread across the cluster, than a standard GET.  To complete a query it is necessary to complete an operation in at least `RingSize div n_val` vnodes, rather than `n_val` vnodes for a GET.

{: .note }
> It is possible to drive up the volume of 2i queries, with real-world production examples of more than 10K queries per second being achieved - but such relatively high query volumes are not core to the Riak use case.

There is a relatively fixed cost per query, even where 0 results are returned; there is a marginal difference in the cost of scanning 10K index entries and scanning 10.

Queries that cover large sets of results are possible in a single round trip.  The query process will be greedy for available CPU cores to complete the query, there is no constraint on how many cores a query can use - up to a maximum of `RingSize div n_val` across the cluster.  The Erlang scheduler will balance use between queries and other user requests; there is no specific ring-fencing of resources for the purpose of querying.

Understanding the [detailed guidance about query performance](#performance-and-efficiency) is important, but in summary:

- Try to minimise the number of index terms within the range of the query;
- Use a more efficient `accumulation_option` where possible (i.e. prefer a `raw` option);
- To support conjunction queries, prefer the use single queries with filtering of projected attributes over combination queries.

## Example (1) - A Simple People Search Index

In this example, the database contains people whose records are stored under a unique individual identifier (the primary Key used in Riak).  There is also a requirement to search for people to find potential matches where the unique identifier is not known, and in these searches the following criteria can be provided to the query:

- Date Of birth (required).
- Current family name (optional).
- All known given names (optional).
- Current home [postal code](https://en.wikipedia.org/wiki/Postal_code) (optional).

For all queryable attributes approximate entries are allowed.  The Date of Birth can be a range rather than a specific date, the names and post codes require a minimal prefix (the first two characters), but wildcards may be provided for unknown parts.

For this example, a single index per record is constructed to support these queries, whereby the Date Of Birth would be the sort key, the current family name, given names and current home postcode could be added as projected attributes - with `|` used as a delimiter between the types of attributes and `.` used as a delimiter between the individual attributes of a given type (which in this case is only for given names).

So a sample person:

- born on 1st May 1965;
- with current family name of SMITH;
- known by given names of ANNE, MARIE & ANNE-MARIE;
- and has registered a home Postal Code (LS9 0TW).

They would then be represented by the following index entry:

`peoplefinder_bin: 19650501|SMITH|ANNE.MARIE.ANNE-MARIE|LS9_0TW`

### Example (1) - Simple Range Query

To find all the people with a given date of birth, a simple range query could be used:

```json
    {
        "query_list" :
            [
                {
                    "index_name" : "peoplefinder_bin",
                    "start_term" : "19650501",
                    "end_term"   : "19650502"
                }
            ]
    }
```

This is the equivalent to finding all those born on "19650501" in "YYYYMMDD" format.  As all index entries have additional information appended, the `end_term` "19650502" is lexicographically before any of the index entries for those born on "19650502" e.g. `"19650502" < "19650502|...."`.  As no `accumulation_option` has been set, this will return a list of keys for those people born on that day.

### Example (1) - Finding an Exact Match

To find an exact match on a subset of the provided data (e.g. Date Of Birth = 19650501, FamilyName = SMITH, GivenName = ANNE), the following query could be used:

```json
    {
        "substitutions" : {"dl1" : "|", "dl2" : ".", "qfn" : "SMITH", "qgn" : "ANNE"},
        "query_list" :
            [
                {
                    "index_name" : "peoplefinder_bin",
                    "start_term" : "19650501",
                    "end_term"   : "19650501~",
                    "evaluation_expression" : "delim($term, :dl1, ($dob, $fn, $gn, $pc)) | split($gn, :dl2, $gn)",
                    "filter_expression" : "($fn = :qfn ) AND (:qgn IN $gn)"
                }
            ]
    }
```

This query defines some `substitutions`, of the delimiters (to simplify escaping required when passing text into the expressions), and of the actual terms to be queried (which can make it easier within the application to transpose user input into standard query templates).  The substitutions are referred to within expressions by prefixing the substitution name with `:`.

e.g. the substitution of `{"qfn", : "SMITH", "qgn", "ANNE"}` will translate the `filter_expression` `"($fn = :qfn ) AND (:qgn IN $gn)"` into `"($fn = SMITH ) AND (ANNE IN $gn)"`.

The query list in this case contains only one query, and that identifies the index field (`index_name`), and the start and end terms (`start_term` snd `end_term`).  Note that as the projected attributes are appended the sort key, although the query is for an exact sort key it must be range query which covers all possible projected attributes (in this case by appending to the end_term a character `~` that has a value higher than the delimiter `|` in the ascii table).

The evaluation expression is a pipeline of evaluation functions to be applied to each index term.  The first evaluation function `delim($term, :dl1, ($dob, $fn, $gn, $pc))` instructs the query to split the query term using the delimiter identified by the substitution `dl1` (i.e. `|`) and then up to four elements will be placed in the projected attributes maps as `$dob`, `$fn`, `$gn` and `$pc` respectively.  The second evaluation function `split($gn, :dl2, $gn)` is used to take the value of the attribute `$gn` and create a new attribute `$gn` which is a list obtained by splitting the attribute value on the delimiter identified by the substitution `dl2` (i.e. `.`).

So in this term there are two delimiters, one `|` which splits up a fixed number of attributes, and this is evaluated with the `delim` function which outputs elements directly into the map of attributes.  There is then a second delimiter `.` which splits one of those attributes, the given name attribute, into individual given names.  As there is a variable number of given names supported, the `split` function is used to output an attribute whose value is a list.  In this case the output name of the attribute `$gn` is the same as the input, so this alters the value in the attribute map rather than creating a new one.

After applying the `evaluation_expression`, the `filter_expression` will receive a map of projected attributes like this (for this specific index entry):

```erlang
    #{
        <<"$dob">> => "19650501",
        <<"$fn">> => "SMITH",
        <<"$gn">> => ["ANNE", "MARIE", "ANNE-MARIE"],
        <<"$pc">> => "LS9_0TW"
    }
```

The filter does not need to qualify the date of birth, as this is already qualified by the range.  However, it needs to check that the current Family Name is as expected `($fn = :qfn)` and that the query given name is in the list of given names produced `(:gqn IN $gn)`.

Note that, in this particular case, there would be a significant performance improvement by rewriting the query as:

```json
    {
        "substitutions" : {"dl1" : "|", "dl2" : ".", "qgn" : "ANNE"},
        "query_list" :
            [
                {
                    "index_name" : "peoplefinder_bin",
                    "start_term" : "19650501|SMITH|",
                    "end_term"   : "19650501|SMITH|~",
                    "evaluation_expression" : "delim($term, :dl1, ($dob, $fn, $gn, $pc)) | split($gn, :dl2, $gn)",
                    "filter_expression" : "(:qgn IN $gn)"
                }
            ]
    }
```

The optimisation will reduce the number of results that need to be scanned and processed, by requesting a more specific range.  To exploit such optimisations, there is a need for design effort to correctly order the projected attributes in the index term.

{: .note }
> The potential for such optimisations is a key driver to using an append-then-evaluate approach to adding projected attributes to index entries; rather than keeping projected attributes in an unordered array separate to the sort key.

The query _may_ be further optimised using a regular expression.  Some functionality may be harder to implement in regular expressions - in this case it will also hit a match on a given name that includes the letters ANNE rather than match only on a given name that is entirely ANNE.  Regular expressions make handling range checks on projected attributes much more difficult:

```json
    {
        "query_list" :
            [
                {
                    "index_name" : "peoplefinder_bin",
                    "start_term" : "19650501|SMITH|",
                    "end_term"   : "19650501|SMITH|~",
                    "regular_expression" : "[^\\|]*\\|[^\\|]*\\|[^\\|]*ANNE"
                }
            ]
    }
```

This regular expression based query is not guaranteed to be quicker than using the filter and evaluation expressions in the previous example.  Further, even if it does improve performance, building such optimisations into queries can add significant complications to application code, and add to the complexity of testing that application code.

### Example (1) - Inexact Match

If for the same query it is required to have an inexact match (e.g. Born between between 1965 and 1970, birthday of 1st May, Family name of SM*, Given name of ANNE), the following query could be used:

```json
    {
        "substitutions" : {"dl1" : "|", "dl2" : ".", "qfn_begins" : "SM", "qgn" : "ANNE", "qbd" : "0501"},
        "query_list" :
            [
                {
                    "index_name" : "peoplefinder_bin",
                    "start_term" : "19650101",
                    "end_term"   : "19691231~",
                    "evaluation_expression" : "delim($term, :dl1, ($dob, $fn, $gn, $pc)) | split($gn, :dl2, $gn) | index($dob, 4, 4, $birthday)",
                    "filter_expression" : "begins_with($fn, :qfn_begins ) AND (:qgn IN $gn) AND ($birthday = :qbd)"
                }
            ]
    }
```

The evaluation expression is extended to output the birthday by taking the last 4 characters of the date of birth.  The filter expression checks an inexact match by looking only at the start of the family name.

Alternative approaches would be possible:

- `ends_with($dob, :qbd)` could be used for the birthday check avoiding the additional pipeline function in the evaluation expression.
- `index($fn, 0, 2, $fn)` could be used in the evaluation expression to slim the $fn to the first two characters for equality checking.
- Also, because of the birthday check, the range start and end terms could also be tighter, and reduce the number of index terms to be processed by about 20%.

### Example (1) - Inexact Match of Given Name

The evaluation expression language supports flexible comparisons on exact terms; but when a term has been broken into a sub-list (as with the Given Names in the above example), it is only possible to look for an exact match within the sub-list.

There are three possible alternatives should a more complex match be required on such a sub-list:

- Use the alternative `accumulation_option` of `terms` to the default (which is `keys`), and this will return a list of term/key tuples to filter in the application (rather than just a list of object keys).  By default the whole term will be returned, but a specific projected attribute can be returned using the `accumulation_term` option, as long as the value of that attribute is a string.
  - Filtering in the database is generally quicker than filtering in the application though - due to the increased parallelism of the database filter, and the reduced serialisation and sorting costs.
- Use an alternative representation and the `contains` evaluation function - e.g. storing given names with a preceding and succeeding delimiter `.ANNE.MARIE.ANNE-MARIE.`, would allow for: `contains($gn, "ANNE")` to find any mention of ANNE in any part of any given name; `contains($gn, ".ANNE.")` to find only where the whole given name is ANNE; `contains($gn, ".ANNE") OR contains($gn, "ANNE.")` to find where the given name either begins or ends with ANNE.
- Use a regular expression filter rather than an evaluation and filter expression, which may in this case be considered a more natural approach to wildcard matching on strings.

### Example (1) - Wildcards within terms

Wildcard style queries against individual string attributes are only supported directly using the regular expression filter type.

When using evaluation and filter expressions, the `filter_expression` functions `begins_with`, `ends_with` and `between` are to be used to support internal wildcards within terms.  For example to match on family names of `SM*KOWSKI` where `*` represents one or more characters - a `filter_expression` of `begins_with($fn, "SM") AND ends_with($fn, "KOWSKI") NOT ($fn = "SMKOWSKI)` would be required.

There exists a regex based evaluation function that can be used as a pseudo filter function, where the power of regular expressions is required in a specific part of the query.  The regex evaluation function extracts matches, but only when the expected number of matches is found - so non-matching regular expressions will result in attributes not existing in the projected attribute map.

This query should filter family names based on a "fn_regex" provided in the substitutions. 

```json
    {
        "substitutions" : {"dl1" : "|", "dl2" : ".", "qgn" : "ANNE", "fn_regex" : "(?P<fn_match>SM[A-Z]+KOWSKI)"},
        "query_list" :
            [
                {
                    "index_name" : "peoplefinder_bin",
                    "start_term" : "19650501",
                    "end_term"   : "19650501~",
                    "evaluation_expression" : "delim($term, :dl1, ($dob, $fn, $gn, $pc)) | regex($fn, :fn_regex, ($fn_match)) | split($gn, :dl2, $gn)",
                    "filter_expression" : "attribute_exists($fn_match) AND (:qgn IN $gn)"
                }
            ]
    }
```

### Example (1) - More Extensible Index Schema

It is possible to reduce the pre-defined structure in an index entry by using KV pairs in the index entry.

For example, the above index entry could be stored in a Key=Value form, and note that we here differentiate for extra clarity between the primary given name (`pgn`), and the secondary given names (`sgn`):

`peoplefinder_bin: 19650501|fn=SMITH#pgn=ANNE#sgn=MARIE.ANNE-MARIE#pc=LS9_0TW`

This evaluation expression can then be used: `delim($term, :dl1, ($dob, $kvs)) | kvsplit($kvs, "#", "=") | split($sgn, :dl2, $sgn)`

To produce this set of projected attributes to be passed to the filter:

```erlang
    #{
        <<"$dob">> => "19650501",
        <<"$fn">> => "SMITH",
        <<"$pgn">> => "ANNE",
        <<"$sgn">> => ["MARIE", "ANNE-MARIE"],
        <<"$pc">> => "LS9_0TW"
    }
```

## Example (2) - An Alternative People Search

An alternative strategy to option (1), would be to use multiple indexes, with the Date Of Birth as a projected attribute.  Further, in this example the concept of effective dates is introduced, where certain attributes (in particular Postal Code) are relevant only to certain timeframes.  Appending effective date ranges as projected attributes then supports a search for records based on both the present information, or potentially the information at a given date in the past.

In this example there will be three indexes:

- `familyname_bin : <FAMILYNAME>|<DOB>|<EFFECTIVE_STARTDATE><EFFECTIVE_ENDDATE>`
- `givenname_bin : <GIVENNAME>|<DOB>|<EFFECTIVE_STARTDATE><EFFECTIVE_ENDDATE>`
- `postalcode_bin : <POSTCODE>|<DOB>|<EFFECTIVE_STARTDATE><EFFECTIVE_ENDDATE>`

The start date and end dates will be of fixed YYYYMMDD format, with current information being given an artificial end date of `99999999`.

So for a sample person, the index entries could be:

- `familyname_bin: SMITH|19650501|19895060499999999, JONES|19650501|19650501198950604`
- `givenname_bin: ANNE|19650501|1965050199999999, MARIE|19650501|1965050199999999, ANNE-MARIE|19650501|1965050199999999`
- `postcode_bin: LS9_0TW|19650501|1990080199999999, LS9_1GH|19650501|1965050119900801`

This strategy requires more index entries, but potentially simpler and more powerful querying.

```json
    {
        "substitutions" : {"dl1" : "|", "low_dob" : "19650101", "high_dob" : "19650531"},
        "query_list" :
            [
                {
                    "index_name" : "familyname_bin",
                    "start_term" : "SMITH|",
                    "end_term"   : "SMITH~",
                    "evaluation_expression" : "delim($term, :dl1, ($fn, $dob, $edates))",
                    "filter_expression" : "$dob BETWEEN :low_dob AND :high_dob"
                }
            ]
    }
```

The query definition above will search for every SMITH born in the first 6 months of 1964.  Note that the delimiter chosen (`|`) is after all the standard text characters in the ASCII table (char 124), so that this will match on only the complete name SMITH, whereas `"start_term" : "SMITH"` would also match on any surname starting SMITH.

```json
    {
        "substitutions" : {"dl1" : "|", "low_dob" : "19650101", "high_dob" : "19650531", "effective_date" : "19800101"},
        "query_list" :
            [
                {
                    "index_name" : "postcode_bin",
                    "start_term" : "LS9_",
                    "end_term"   : "LS9_~",
                    "evaluation_expression" : "delim($term, :dl1, ($pc, $dob, $edates)) | index($edates, 0, 8, $start_date) | index($edates, 8, 8, $end_date)",
                    "filter_expression" : "($dob BETWEEN :low_dob AND :high_dob) AND (:effective_date BETWEEN $start_date AND $end_date)"
                }
            ]
    }
```

The query definition above will search for anyone who was born in the first 6 months of 1964, and was living in the LS9 postal area on 1st January 1980.

To query across both indexes, a combination query is required.  The following query could be managed on a single query with the [previous strategy](#example-1---a-simple-people-search-index), however, in this strategy the family name and address information is split across different indexes. Multiple queries combined through an aggregation expression are now required to search for only the SMITHs that meet the address criteria.

```json
    {
        "aggregation_expression" : "$1 INTERSECT $2",
        "substitutions" : {"dl1" : "|", "low_dob" : "19650101", "high_dob" : "19650531", "effective_date" : "19800101"},
        "query_list" :
            [
                {
                    "aggregation_tag" : 1,
                    "index_name" : "postcode_bin",
                    "start_term" : "LS9_",
                    "end_term"   : "LS9_~",
                    "evaluation_expression" : "delim($term, :dl1, ($pc, $dob, $edates)) | index($edates, 0, 8, $start_date) | index($edates, 8, 8, $end_date)",
                    "filter_expression" : "($dob BETWEEN :low_dob AND :high_dob) AND (:effective_date BETWEEN $start_date AND $end_date)"
                },
                {
                    "aggregation_tag" : 2,
                    "index_name" : "familyname_bin",
                    "start_term" : "SMITH|",
                    "end_term"   : "SMITH~",
                    "evaluation_expression" : "delim($term, :dl1, ($fn, $dob, $edates))",
                    "filter_expression" : "$dob BETWEEN :low_dob AND :high_dob"
                }
            ]
    }
```

### Example (2) - Simple Variations and Limitations

It is possible to combine strategies (1) and (2) by using separate indices and overloading each term with all additional information.  The application would then need a query planning strategy to determine which index to use based on the information provided - i.e. the strategy would need to determine based on the query details which index would likely lead to the fewest number of index entries being scanned, and use that index and sort key combination.  Designing such a strategy would require up-front knowledge of how the data is distributed.

## Example (3) - Reporting index

As well as returning keys, and term/key tuples; when using single queries it is also possible to return counts, and counts by term.  These alternative accumulators are commonly used to support report-style queries.

For this example it is assumed all the people in the store exist in a hierarchy.  Each person is assigned to a GP Provider, and every GP Provider belongs to a Strategic Health Authority (and these are represented by fixed-width codes).  People have a Date of Birth (from which we can calculate age), but also a series of characteristics which can be expressed in single character flags (e.g. administrative gender code, smoking status, death status, alcohol dependency etc).  This information is then required to do organisation, and population level reporting.

For this a single index is used:

- `healthreport_bin : <SHA><GP><DOB><STATUS_FLAGS>`

So a test record may have an entry like:

- `healthreport_bin: SHA0001GP00000119650501FYNNY`

So if today's date is 30 May 2025, to count all the female smokers over the age of 60 registered in SHA001

```json
    {
        "accumulation_option" : "raw_count",
        "query_list" :
            [
                {
                    "index_name" : "healthreport_bin",
                    "start_term" : "SHA0001",
                    "end_term"   : "SHA0001~",
                    "evaluation_expression" : "index($term, 15, 8, $dob) | index($term, 23, 1, $agc) | index($term, 24, 1, $smoker)",
                    "filter_expression" : "($dob <= \"19650530\") AND ($agc = \"F\") AND ($smoker = \"Y\")"
                }
            ]
    }
```

If the same results are required, but this time a count by age at today's date (30th May 2025):

```json
    {
        "substitutions" : {"current_date" : "0530"},
        "accumulation_option" : "term_with_rawcount",
        "accumulation_term" : "$age",
        "query_list" :
            [
                {
                    "index_name" : "healthreport_bin",
                    "start_term" : "SHA0001",
                    "end_term"   : "SHA0001~",
                    "evaluation_expression" : "index($term, 15, 8, $dob) | index($term, 23, 1, $agc) | index($term, 24, 1, $smoker) | index($dob, 0, 4, $yob) | to_integer($yob, $yob) | index($dob, 4, 4, $birthday) | map($birthday, <=, ((:current_date, 2025)), 2024, $yoc) | subtract($yoc, $yob, $age) | to_string($age, $age)",
                    "filter_expression" : "($dob <= \"19650530\") AND ($agc = \"F\") AND ($smoker = \"Y\")"
                }
            ]
    }
```

### Example (3) - Simple Variations and Limitations

In using report-style queries, counting results or grouping counts by a projected attribute - the type of `accumulation_option` used is important.  There is support for both `raw` and non-`raw` forms of each `accumulation_option`.  The `raw` form of each accumulator [will be significantly more efficient when covering large result sets](#performance-and-efficiency), but it will not deduplicate the result set by object key before counting.

## Query - Definition

### Query JSON - Definition

The query should be posted as the HTTP body, to the query API for the relevant bucket, where there are the following JSON keys at the root of the document

#### `aggregation_expression` (optional)

- If multiple queries are to be run, the aggregation expression is used to inform the database how those results should be combined, using $1, $2 etc to refer to the numeric `aggregation_tag` for each query - with the key words `UNION`, `INTERSECT` and `SUBTRACT` to show how the sets of results are to be combined.  Parenthesis may be used for clarity. e.g. `($1 INTERSECT $2) UNION ($3 SUBTRACT $1)`

#### `accumulation_option` (optional - default = keys)

- There are multiple options for accumulating the results from a single query:
  - `keys`; return a list of keys that matched in the query, where the keys have been deduplicated and sorted.
  - `raw_keys`; return a list of keys that matched in the query, but in no specific order and where multiple matches for the same key will result in that key appearing multiple times within the results.
  - `terms`; return a list of term/key pairs, ordered by term.
  - `raw_terms`; return a list of term/key pairs, unsorted.
  - `count`; return a count of unique keys that matched the query.
  - `raw_count`; return a count of matches against the query (i.e. unlike `count` if an object key appears against multiple terms matched within the query, with `raw_count` that key will be counted multiple times).
  - `term_with_count`; return a count of unique key matches by term (where term is specified by the `accumulation_term`) in no specific order.
  - `term_with_rawcount`; return a count of key matches by term (where term is specified by the `accumulation_term`) in no specific order, where a key which appears multiple times under that term will be counted multiple times.

In some circumstances, there are constraints on the `accumulation_option` which can be used:

- If an `aggregation_expression` is added to the query (i.e. it is a combination query), only `raw_keys` and `raw_count` are valid accumulation options.
- If a `max_results` setting is added to the query, then only `terms` and `raw_keys` are valid accumulation options.

#### `accumulation_term` (optional - default = $term)

When using an accumulation option of `terms`, `raw_terms`, `term_with_rawcount` or `term_with_count`; the `accumulation_term` is the projected attribute returned from the evaluation function to be used as the term in the accumulator. The default is $term - the whole term.

#### `max_results` (optional)

The potential to limit the number of results returned by the query, to the first N results.  The query will terminate once sufficient results have been returned, and a `continuation` term will be returned along with the results, which can be passed into a subsequent query to return the next set of results after this point.  This allows for pagination of results.

- The Max results option is only supported with an `accumulation_option` of `terms` or `raw_keys`.
  - Only the `terms` accumulator is able to make a reliable continuation point.
  - Internally if using `raw_keys` with `max_results`, then the query will run as a `terms` query, with the terms being stripped immediately prior to returning a response.

Note that as the query is distributed, and there is minimal difference for the performance of fetching 1 or 10K results, then pagination will not be efficient for user-facing page sizes (e.g. small batches of o(10)).

> For pagination to the end user, it is normally better to fetch larger result sets to be cached and paginated within the application.

#### `continuation` (optional)

A string returned from a previous query constrained by `max_results`, used to indicate the starting point for the next page of results.

#### `substitutions` (optional)

An array of key/value pairs that are referred to in filter or evaluation expressions.  Where a substitution key is present in an expression (prefixed by `:`), the substitution value will be used to replace those keys before the query process parses the expression.  For example, `{"low_dob" : "19550301", "high_dob" : "19560630"}` can be passed as substitutions to populate an evaluation of `"$dob" BETWEEN ":low_dob" AND ":high_dob"`.  The values of substitutions should all be strings.

#### `timeout` (optional)

The timeout in seconds to wait for the query to complete, before a timeout error is returned.

- This is the timeout used by the server, other HTTP timeouts may exist on the path to Riak, in particular in the Riak client.

#### `query_list` (required)

A list of one or more queries.  This should be a list of just one query unless an `aggregation_expression` has been included in the main query block.

Each query has the following parts:

- `aggregation_tag` (optional)
  - required if an only if an `aggregation_expression` is used
- `index_name` (required - should be a binary index)
- `start_term` (required)
- `end_term` (required)
- `evaluation_expression` (optional)
  - an expression to extract projected attributes from the term.
- `filter_expression` (optional)
  - an expression to filter results based on those projected attributes.
  - Must be included if an `evaluation_expression` is included in the query, but can simply test `attribute_exists($key)` if no filter is required.
- `regular expression` (optional)
  - alternative to using evaluation or filter expressions, which can potentially be used to improve the performance of queries.
  - must not be included if filter/evaluation expressions form part of the query.

### Query Json - Expressions

There are two parts to using expressions in a Riak query: an evaluation expression (to convert the term into projected attributes), and a filter expression (to filter the results in or out by matching on the values of projected attributes).

#### Evaluation Expression - Definition

The evaluation pipeline receives a map of projected attributes containing two Identifier/Value pairs - $term, $key.  The $term is the index term that has been matched (as it is within the sorted key range for the given index field and bucket), and the $key is the value of the Key.  Both $term and $key will be strings.  

The `evaluation_expression` is a pipeline of individual functions, joined using the `|` operator.  All pipeline functions will update the map, potentially adding new projected attributes, or adjusting the value for existing attributes - and the map will be forwarded onto the next stage for processing.

Values of the projected attributes in the map always start as strings in the pipeline, but may be explicitly converted to lists of strings, or to an integer - and in the case of an integer can also be converted back to a string.  Functions in the pipeline that receive inputs of the wrong type are skipped.

The functions that can be used in a pipeline are:

`delim ( IN_ID identifier , DELIM string , OUT_ID_LIST identifier_list )`

- take a value associated with IN_ID and split it using the delimiter DELIM.  The parts are matched to the identifiers in OUT_ID_LIST.  If there are only N values following the application of the delimiter where N is less than the length of the OUT_ID_LIST, then only then only the first N identifiers in OUT_ID_LIST are assigned a value.  Any overhanging elements (i.e. where N is greater than the length of the OUT_ID_LIST) are ignored.

`join ( IN_ID_LIST identifier_list , DELIM string , OUT_ID identifier )`

- a concatenation function that takes each value associated with an identifier in IN_ID_LIST in turn, and concatenates them together using the DELIM as a separator.  The output is given as the value of OUT_ID.  In effect `join` is the reverse of the `delim` function.
- this is generally used with term-based aggregators in queries (e.g. to create a combined term to count by).

`split ( IN_ID identifier , DELIM string , OUT_ID identifier )`

- works as with the `delim` function, but the output (a list of strings) is assigned to a single OUT_ID identifier.

`slice ( IN_ID identifier , LENGTH pos_integer , OUT_ID identifier )`

- slice a string into a list of multiple strings assuming each sub-string is of fixed length e.g. if the value of IN_ID is a string containing 2-character values, slicing with a length 2 will assign a list of 2-character strings to OUT_ID. 

`index ( IN_ID identifier , POSITION non_neg_integer , LENGTH pos_integer , OUT_ID identifier )`

- take a single slice from a string mapped to the IN_ID identifier, from character position POSITION of length LENGTH and assign the output to OUT_ID.  If there are insufficient characters in the string value of IN_ID to take a string of that position and length, then the function will be skipped.

`kvsplit ( IN_ID identifier , PAIR_DELIM string , KV_DELIM string )`

- take a string value associated with IN_ID, where the string contains a delimited (by PAIR_DELIM) list of Key/Value pairs - where the Key and Value and separated by KV_DELIM.  The output will add each Key/Value pair to the map of projected attributes.

`regex ( IN_ID identifier , REGEX string , OUT_ID_LIST identifier_list )`

- use a regular expression to extract new projected attributes as Key/Value pairs, where the REGEX must match the value of IN_ID and extract named capture groups that align with the attribute keys in the OUT_ID_LIST.  All expected captures must exist in the input value for the projected attributes to be updated, otherwise the function will pass on the map of projected attributes unchanged.

`map ( IN_ID identifier , COMP comparator , MAP_LIST mappings_list , DEFAULT operand , OUT_ID identifier )`

- to classify the value of a projected attribute the map function is used.  The MAP_LIST is a list of pairs, where the first element of the pair is a value to compare with, and the second element is a classification for a match against this  pair (the output value).  The comparison between the value and the first element is done using the comparator COMP.  If no element of the MAP_LIST returns a match against the input value, then the DEFAULT classification is used as the output value.  The output value is added to the projected attributes using the OUT_ID identifier as the key.
- this is generally used with term-based aggregators in queries (e.g. to create a combined term to count by).

`to_integer ( IN_ID identifier , OUT_ID identifier )`

- convert a string to an integer where IN_ID has a string value, and is mapped after integer-conversion to the projected attribute with an OUT_ID identifier.  The pipeline stage is skipped when the value does not convert to an integer.
- note that if IN_ID and OUT_ID are the same identifier, the type of the value of OUT_ID is dependent on the success of the conversion.

`to_string ( IN_ID identifier , OUT_ID identifier )`

- convert an integer back to a string where IN_ID has an integer value, and is mapped after string-conversion to the projected attribute with an OUT_ID identifier.  If the input value is already a string, the mapping will still occur without the conversion.

`subtract ( X math_operand , Y math_operand , OUT_ID identifier )`

- subtract Y from X and map the output to the OUT_ID identifier of the map of projected attributes.  X and Y can either be an integer provided as an input, or an identifier of an existing projected attribute which has been converted to an integer.  If either X or Y are not integers, then the function will be skipped.  

`add ( X math_operand , Y math_operand , OUT_ID identifier )`

- add X to Y and map the output to the OUT_ID identifier of the map of projected attributes.  X and Y can either be an integer provided as an input, or an identifier of an existing projected attribute which has been converted to an integer.  If either X or Y are not integers, then the function will be skipped.

The final map of projected attributes will be passed as the input to the Filter Expression.

#### Filter Expression - Definition

The Filter expression takes the projected attributes as an input, and the output is either `true` (the term is a match) or `false`.

In the definition an `operand` can either be a `key` of a projected attribute (where the value of that attribute will be used when applying the expression), or a fixed value provided within the expression.

```
condition-expression ::=
      operand comparator operand
    | operand BETWEEN operand AND operand
    | operand IN operand 
    | operand IN (',' operand )
    | function
    | condition AND condition
    | condition OR condition
    | NOT condition
    | ( condition )

comparator ::=
    =
    | <>
    | <
    | <=
    | >
    | >=

function ::=
    attribute_exists (key)
    | attribute_not_exists (key)
    | attribute_empty (key)
    | begins_with (key, substr)
    | ends_with (key, substr)
    | contains (key, substr)
```

## Performance and Efficiency

There are multiple stages to producing a query result:

- Setup and distribute the query;
  - parse the API request, validate the request, start a query server, find a coverage plan, initiate snapshots of all vnodes required for the query.
- Scan the index entries (concurrently across vnode backends);
  - read, deserialise and merge blocks of index entries at each level so that index entries within the range can be passed in key order to be evaluated and filtered.
- The filtering of each potential result within the range;
- The buffering and potential deduplication of results at the vnode level.
- the combination of query results using an aggregation expression.
- The collation, aggregation, deduplication and sorting of results at a cluster level.
- The transformation of results (into JSON) and transmission back as the API response.

As queries depend on all these parts, and all these parts are impacted differently by different factors it is not possible to precisely predict query response times.

{: .highlight }
> In general though, when scanning less than 10K entries and filtering to less than 1K results, most Riak clusters on modern hardware should be able to support **query latency of o(10) ms**.

### Setup and Distribute the Query

The first stage, setup, is largely a fixed overhead regardless of query type.  The cost of the stage is primarily driven by the Ring Size of the cluster, which determines the number of snapshots that need to be taken in parallel.  A lower Ring Size will reduce the cost of this overhead, but in general a reduced Ring Size has a negative impact on performance - so reducing Ring Size with the intention to reduce query response times is not recommended.

{: .note }
> The latency introduced in the setup phase is generally **less than o(1) ms** for small and mid-sized clusters.  

Note though, that requests for snapshots are added to the vnode queue on each vnode.

{: .note }
> On a busy cluster that query latency will be increased the delay of the longest vnode queue in the query coverage plan.

The query coverage plan will distribute the query to at least `RingSize div n_val` vnodes, and the size of the vnode queue is not a factor in the calculation of the plan.  Once the snapshot is taken, all other phases of the query are independent of the vnode queue.

{: .note }
> If there is significant network latency between nodes within a cluster, then that latency will impact the setup phase.  It is recommended to only use the Query API when network latency between cluster members is not significantly greater than 1 ms.

### Scanning

The scanning stage of the query is in parallel with the filtering, buffering and collation of results.  As results are scanned they are passed into the query pipeline for continuous processing.

{: .highlight }
> In general a query should be able to scan, merge and select index entries at between **500K and 1M entries per CPU-core per second**.

Assuming there are multiple vnodes per CPU core in the cluster, all CPU cores may be potentially used in the fulfilment of the query.  Fair use of CPU cores is controlled by the Erlang scheduler not through the use of queues within the database.  In most mid-size clusters, 10M to 100M index entries can be scanned per second - however frequent use of queries which scan more than 1M index entries per second may have an impact on overall cluster performance.

Index entries are stored in blocks of around 30 entries, so there is minimal difference between scanning 1 entry per vnode, and scanning 100.  Each block must be decompressed and deserialised every time the block is scanned, there is no caching of deserialised index entries.  The only caching between queries is of a small amount of block metadata and natural promotion of blocks to the file system page cache.

{: .note }
> Spare memory will improve query performance by reducing disk wait times, but no database memory is ring-fenced for caching scanned index entries.

### Filtering

The filtering stage requires the application of an optional filter, to validate projected attributes overloaded on the index entry to filter the result in or out of the query.  The standard way of filtering projected attributes is through the combination of an `evaluation_expression` (to extract the attributes) and a `filter_expression` (to test the attributes against query conditions).

{: .note }
> The overhead of combining an `evaluation_expression` and a `filter_expression` is normally between 20% and 60% depending on the complexity of the expressions.  Queries with a filter will generally only be able to process between **200K and 500K entries per CPU-core per second**.

Filtering results will reduce the cost of downstream processes significantly, especially deduplication, sorting and deserialisation.  These costs though are dependent on the `accumulation_option`, but only the `raw_count` option has minimal downstream costs.

{: .note }
> When using any `accumulation_option` other than `raw_count`, being more specific in the evaluation and filter of index entries will probably improve performance - regardless of the complexity of the required expressions.

### Buffering

Once a result has been filtered it is added to the local per-vnode buffer for that query.  The buffer will aggregate results, and then for large queries periodically (based on the count of results added to the buffer) send interim result sets back to the query server - the process collating results across the cluster.  The query buffer will wait to receive a reply from the server before proceeding.

{: .highlight }
> The number of concurrent CPU cores that may be used by a query will be constrained by the delay awaiting an acknowledgement from the query server.  This delay will depend on network latency within the cluster and the work required in the collation phase for the chosen `accumulation_option`.  Lower latency clusters returning `raw_count` should normally scale to make use of **o(100) CPU cores per query**.  Higher latency clusters using `keys`, `count` or `term_with_keys` may not scale beyond **o(10) CPU cores per query**.

If `keys`, or `count` or `term_with_count` are used as the `accumulation_option` there is a need to deduplicate the results.  For `keys` this deduplication will occur centrally at the query_server; but this will have a significant impact on query performance as the number of filtered results grows.

For `count` and `term_with_count`, there is an optimisation to deduplicate results at the vnode level. However, even with this optimisation, for large numbers of post-filter results the overhead of deduplication may become a dominant factor in overall query cost and latency.

{: .note }
> At 10K filtered results per vnode, the deduplication overhead will typically be 10%, at 100K filtered results per vnode it will be around 50%, and at over 1M results per vnode the overhead may be an order of magnitude.

For each `accumulation_option` option there is a `raw` option that does not deduplicate the results.  Always use the `raw` option for large result sets if deduplication is not necessary.  For instance; if the application enforces cardinality rules so that each object may only have one entry on the index, or duplicate results can be handled by the application.

{: .highlight }
> A mid-size cluster should be able to `raw_count` **100M unfiltered index entries in less than 10 seconds**; however the `count` of such a result set could take o(100) seconds.

If using the `raw` option is not possible and a large result set is expected, then dividing the query into multiple sub-queries by range and accepting the increased per-query overhead is generally a better option than using the non-`raw` option.  The need for a `raw` option is unnecessary if combined result set sizes are less than 100K keys.

Partitioning of results is best done by breaking up the sort key range; the `max_results` option cannot be used on `count`-like queries.

The `max_results` (and then `continuation`) option may be used to partition results into multiple queries, but this is [only supported with the `terms` and `raw_keys` accumulation option](#max_results-optional).

{: .note }
> When setting `max_results` with a `raw_keys` query, a `terms` query will be run internally, and the terms stripped before sending the keys in the response.  Setting `max_results` on a `raw_keys` query will therefore lead to the performance overheads of a `terms` query i.e. extra data transmitted within the cluster, and a sorting overhead at the query server.

### Aggregation of Combination Queries

For combination queries, each query is run in-turn, and is always run.  Once all queries have been run the `aggregation_expression` is applied to the result set at the vnode level.

{: .note }
> In most scenarios, the distributed running of the `aggregation_expression` means that latency of that aggregation is not significant in overall query latency, as the set operations are performed on vnode-sized sets not cluster-sized sets.

If the `aggregation_expression` is based on `INTERSECT` there may be situations where the result set of latter queries are going to be intersected with an empty set, and therefore running the latter query is unnecessary:

{: .note }
> There is presently no optimisation that would not run queries based on partial completion of the `aggregation_expression`.

Aggregation queries, which use set expressions to combine results across multiple queries, do not use the query buffer until all queries are complete and the `aggregation_expression` has been applied on that vnode's results.

{: .warning }
> As the query buffer is bypassed a cancelled query will not terminate early for combination queries.

Support for `aggregation_expression`s in Riak 3.4 is a work in progress and may [be optimised in future releases](#further-improvements).

### Central Collation of Query Results

The query server which prompted the setup of the query, will also be responsible for collation of results.  This server will always reside on the node which received the query request.

{: .note }
> It is important to distribute query requests evenly across a cluster due to the overheads of collation, and if necessary mark down nodes with specific temporary overheads within the load-balancer's active configuration.

The query server will acknowledge results received in batches, but for `count`, `term_with_count` and `term_with_rawcount` queries only a `ping` will be sent for acknowledgement.  For these queries partial result sets are not collated, just the final result for the vnode.

The `keys` and `term_with_keys` result set both require sorting on the query server.  The sorting takes place in parallel to vnode querying and batches of results arrive, but may delay the query server in acknowledging results.  The vnode queries cannot outrun the centralised sorting process.

### Transformation of Results

The final stage of handling the request is the formation of the response into a JSON message.  The cost of this stage is directly linked to the size of the final result set, although this is normally a minority of the overall cost.

There is no protection against overloading memory with the results of an individual query.

{: .warning }
> The node handling the request must have enough memory to hold all the results in memory, and during transformation the memory overhead may be doubled.  Consideration of this is required, especially when running non-`count` queries that return o(10m) results or greater.

## Notes on Implementation

### Siblings

Riak supports the `allow_mult = true` state, whereby the history of changes to an object is retained when concurrent updates are made to the same object.  In the sibling state, all index entries on all versions of the object are active from a query perspective.

### Unicode support

Testing is only undertaken on ascii-based index terms in Riak 3.4, although filter and evaluation expressions have been designed to support unicode.

{: .note }
There are potential issues with unicode support, not least with support for unicode in HTTP headers, so significant additional work may be required to provide a comprehensive and well-tested solution with Unicode support in a future Riak release.

### Consistency

Index changes are not deferred to an async process, at a vnode level all index changes are made as a transaction with the object change.  Outside of failure scenarios, secondary index queries will almost always immediately reflect the results of any changes in the object (with caveats related to unreliable latency across intra-cluster networking communication).

In failure and recovery scenarios, false negatives are possible (i.e. results may be missing until anti-entropy mechanisms correct) but results will be eventually consistent.  The query uses a coverage plan which will check only one (of N) potential copies of the data, and so should a vnode be temporarily incorrect, the entropy is not detected as part of the query.  The `participate_in_coverage` configuration option (which can be applied at run-time) is used to mitigate this - this can be used to prevent a node with a known entropy issue from being involved in queries. 

### Further Improvements

Improving the functionality of the Query API is an active goal of the OpenRiak community.  Notifications on planned improvements will be added to the [OpenRiak discussions board](https://github.com/orgs/OpenRiak/discussions).
