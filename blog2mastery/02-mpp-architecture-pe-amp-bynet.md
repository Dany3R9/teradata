# Article 2 — Shared-Nothing MPP: Parsing Engine, AMPs, BYNET & Vdisk
*Part I: Foundations · The Road to Teradata Mastery (2 of 20)*

> **Where we are in the journey.** Article 1 gave us the map — the ecosystem and the RIA. Now we open
> the engine. This article introduces the four components that make Teradata massively parallel and
> traces a single query through them end to end. If you understand this flow, the rest of the journey —
> distribution, joins, spool, the optimizer — becomes a series of refinements on one mental model
> rather than a pile of disconnected facts.

---

## The one idea: shared-nothing

Teradata is a **shared-nothing, massively parallel processing (MPP)** database. That phrase is doing a
lot of work, so let's unpack it with an analogy before the precision.

Imagine you must count every book in a national library. **Shared-everything** is one super-fast
librarian with sole access to every shelf — add more librarians and they just queue for the same
shelves. **Shared-disk** is many librarians who all reach into the same central stockroom — they stop
queuing for *people* but start queuing for the *stockroom door*. **Shared-nothing** is different: you
divide the building into hundreds of rooms, give each librarian *their own* rooms that nobody else can
touch, and have them all count simultaneously. To get the national total, each reports their subtotal
and you sum the reports. No shared shelves, no shared stockroom, no contention. Add librarians *and*
rooms together and you scale almost linearly.

Teradata is the third model. Each "librarian with their own rooms" is an **AMP**. The architecture's
entire performance story — and its entire failure story — follows from this: **work is divided once,
done in parallel with no sharing, and the result is merged.** The system is only as fast as its
slowest, busiest worker, which is why how you *divide the rooms* (Article 3) matters so much.

## The four components

### 1. The Parsing Engine (PE)

The PE is the brain of a request. It is a virtual processor (vproc) that handles **session control,
parsing, optimisation, and dispatch**:

- **Session control** — authenticates the user and manages the session (a PE manages up to ~120 sessions).
- **Parser** — checks syntax, resolves objects against the data dictionary, and checks access rights.
- **Optimizer** — the cost-based optimizer turns the SQL into the cheapest parallel *execution plan* it
  can find, deciding access paths, join order, join strategies, and where data must move. This is the
  single most important component for performance, and Articles 5–9 are essentially about helping it.
- **Dispatcher** — breaks the plan into steps and sends them, over the BYNET, to the AMPs.

Crucially, **the PE does no data crunching.** It plans and coordinates; the AMPs do the labour.

### 2. The Access Module Processors (AMPs)

The AMP is the worker. Each AMP is a vproc that **owns a portion of every table's rows** and is the only
process allowed to touch them. An AMP:

- reads and writes its rows on its **own Vdisk** (no other AMP can read it),
- performs **scans, joins, aggregation, sorting, and space accounting** locally,
- manages its slice of **permanent**, **spool** (intermediate results) and **temp** space.

If you have 144 AMPs, a full-table scan is 144 scans happening at once, each over ~1/144th of the data.
That is the parallelism. It is also why an AMP that owns *more than its share* of rows (skew) drags the
whole query: 143 AMPs finish and wait on the one that was handed too much work.

### 3. The BYNET

The BYNET is the **interconnect** — the messaging fabric between PEs and AMPs, and between AMPs. It is
dual and redundant (BYNET 0 and BYNET 1) for both throughput and fault tolerance. It does two jobs
worth remembering:

- **Communication** — point-to-point (one AMP to another) and broadcast (the PE to all AMPs; one AMP to
  all AMPs). Broadcast is how a small table gets *duplicated* to every AMP during a join (Article 5).
- **Merge** — the BYNET can merge the sorted sub-answers coming back from many AMPs into a single
  ordered stream, so a sorted result does not require one AMP to re-sort everything.

When you later read an EXPLAIN and see "rows are redistributed by hash" or "duplicated on all AMPs,"
that movement is BYNET traffic — and BYNET cost is something the optimizer actively tries to avoid.

### 4. The Vdisk (and vprocs)

PEs and AMPs are **virtual processors (vprocs)** running on physical nodes; an AMP's storage is a
**Vdisk**, a logical disk carved from the node's physical storage. The virtualisation matters because it
is what makes Teradata *scale by reconfiguration*: add nodes, add AMPs, redistribute the data, and the
parallel width grows. (On VantageCloud the same logical model is mapped onto cloud compute and object
storage — Article 19.)

## Tracing one query end to end

Let's run `SELECT customer_segment, COUNT(*) FROM sales GROUP BY customer_segment;` and watch it move:

1. **Session/parse** — the request hits a PE. It authenticates the session, parses the SQL, and checks
   that the user can read `sales`.
2. **Optimise** — the optimizer decides the access path (here, a full-table scan of `sales`), and that
   the aggregation can be done locally on each AMP first, then combined.
3. **Dispatch** — the PE sends the plan steps to all AMPs over the BYNET.
4. **Local work** — every AMP scans *its own* rows of `sales` and computes a *partial* count per segment
   on its slice. This is the parallel step.
5. **Redistribute/merge** — partial counts are combined (the per-segment subtotals are summed across
   AMPs over the BYNET).
6. **Return** — the final result is handed back through the PE to the client.

Notice the shape: **plan centrally, work locally in parallel, merge the answer.** Almost every Teradata
performance question is a variation on "did step 4 stay balanced, and how expensive was the movement in
step 5?"

---

## 🔬 Teradata-Specific Deep Dive

**Parallel efficiency is the whole game, and it is governed by the slowest AMP.** Define *parallel
efficiency* loosely as (average AMP work) / (maximum AMP work). At 1.0, every AMP did equal work and the
system ran at full width. At 0.5, one AMP did twice the average — you are effectively running at half
your hardware. Skew is not an abstract worry; it is a direct multiplier on wall-clock time. This single
metric is why Article 3 (the Primary Index) is the most important article in Part I.

**Why "no shared disk" is a feature, not a limitation.** Because an AMP only ever touches its own Vdisk,
there is **no lock contention on storage** between AMPs and no cache-coherency traffic. Concurrency
scales because two heavy queries are two sets of AMP-local work, not two processes fighting over the same
blocks. The cost you pay for this is that **any operation needing rows from two different AMPs requires
data movement over the BYNET** — and that movement (redistribution or duplication) is the dominant cost
in large joins. The art of Teradata tuning is keeping the rows that need to meet *already on the same
AMP* (Articles 3 and 5).

**Where spool comes from.** Every intermediate result — the output of a scan that feeds a join, a
redistributed copy of a table, a sort — lands in **spool space**, which is itself distributed across
AMPs. Two consequences that trip people up:
- Spool is per-user-limited *and* per-AMP. A "no more spool space" error often means **one AMP** filled
  its share because an intermediate result was skewed — not that the cluster ran out of total space.
- A query that redistributes a billion-row table creates a billion-row *spool* copy. Big movement = big
  spool. The optimizer weighs this, which is why good statistics (Article 8) are what let it choose the
  cheaper of "redistribute both tables" vs "duplicate the small one."

**A realistic bottleneck.** A join between a large `transactions` table and a `customer` dimension is
slow. EXPLAIN shows `transactions` being *redistributed by hash* on `customer_id` into spool — a billion
rows shuffled across the BYNET — because its Primary Index is on `transaction_id`, not `customer_id`. The
fix is not "add hardware"; it is to recognise that the *join column and the distribution column
disagree*, forcing movement. Either align the physical design or accept the cost — but you cannot
diagnose it at all without the mental model of PE → AMP-local → BYNET-movement.

**How the components compare to other MPP systems:**

| Concept | Teradata | Azure Synapse (dedicated) | Snowflake | BigQuery |
|---|---|---|---|---|
| Coordinator | Parsing Engine | Control node | Cloud Services layer | Dremel root |
| Workers | AMPs (own Vdisk) | Compute nodes (60 distributions) | Virtual warehouse threads | Slots |
| Interconnect | BYNET | Data Movement Service (DMS) | Internal, over object store | Shuffle tier |
| Storage model | Shared-nothing local | Shared-nothing local | Shared (object store) | Shared (Colossus) |
| You manage skew? | **Yes** (Primary Index) | **Yes** (distribution key) | No (micro-partitions) | No (auto) |

Synapse is conceptually the same machine — control node + shared-nothing compute + an interconnect that
shuffles rows — so the skills transfer almost directly. Snowflake and BigQuery moved the storage to a
shared object store and hid the worker topology, which removes the skew problem and the control along
with it. **The thing that makes Teradata feel "old" — exposed distribution and movement — is exactly the
thing that makes a Teradata engineer good at reasoning about *any* MPP system.**

---

## 💡 Insight from Experience

> Engineers new to Teradata reach for "add more AMPs / nodes" the moment a query is slow. It almost never
> helps, and understanding *why* is a rite of passage. Doubling the AMPs doubles the parallel width — but
> if 70% of the work is sitting on one skewed AMP, you have just added idle workers next to the one that
> is actually busy. **Parallel hardware does not fix a serial bottleneck.** The first question on any slow
> Teradata query is never "how big is the system?" — it is "is the work *balanced*, and how much is moving
> over the BYNET?" Get those two right and a modest system outruns a huge, skewed one.

---

## Mastery check & what's next

You should now be able to:

1. Name the four components and state what each does — and which one does *no* data crunching.
2. Explain why a shared-nothing system runs at the speed of its busiest AMP.
3. Describe what BYNET "redistribution" and "duplication" physically are, and why they cost.

In **Article 3** we answer the question hanging over both articles so far: *how does Teradata decide which
AMP owns a given row?* The answer — the **Primary Index** and its hashing — is the foundation that
distribution, joins, and skew all stand on.

---

*Grounding: the four-component MPP model is established Teradata architecture; the source notes corroborate
the per-AMP design (e.g. DSMain operating per-AMP in the BAR notes). The deep-dive analysis, scenarios and
comparisons are authored from domain knowledge. Examples are generic and scrubbed.*

---

> **Disclaimer.** This article is part of a personal learning journey, written from my own experience and
> independent study. It is **not affiliated with, authored by, or endorsed by Teradata**, and uses
> **no confidential or proprietary information** — all examples are generic and illustrative.
