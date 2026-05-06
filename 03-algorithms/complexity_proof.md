# IVRPMS — Complexity Analysis & Algorithm Proofs

## Overview

This document formally proves the time complexity of the two
core algorithms used in IVRPMS for sorting and searching
veteran records. Both proofs use the **Master Theorem** from
the Design and Analysis of Algorithms (DAA) framework.

---

## Algorithm 1 — Merge Sort

### Problem
Sort 10,000+ veteran pension records by monthly amount before
batch disbursement processing in `sp_monthly_batch_report()`.

### Recurrence Relation

```
T(n) = 2T(n/2) + Θ(n)
```

| Term | Meaning |
|---|---|
| `T(n)` | Total time to sort n records |
| `2T(n/2)` | Two recursive calls, each sorting n/2 records |
| `Θ(n)` | Cost of the merge step — linear scan of both halves |

### Recursion Tree

```
Level 0:  [n records]                          cost: cn
           /          \
Level 1:  [n/2]      [n/2]                    cost: cn/2 + cn/2 = cn
           / \         / \
Level 2: [n/4][n/4] [n/4][n/4]                cost: 4 × cn/4 = cn
          ...
Level k:  n subproblems of size 1              cost: cn
```

- Every level contributes exactly **cn** work (Θ(n) total)
- Number of levels = **log₂ n** (each call halves the problem)
- Total cost = cn × log₂ n = **Θ(n log n)**

### Master Theorem Proof

The Master Theorem applies to recurrences of the form:
```
T(n) = aT(n/b) + f(n)
```

**Step 1 — Identify parameters:**
```
a = 2       (two subproblems)
b = 2       (each of size n/2)
f(n) = Θ(n) (merge cost)
```

**Step 2 — Compute the critical exponent:**
```
n^(log_b a) = n^(log₂ 2) = n^1 = n
```

**Step 3 — Compare f(n) with n^(log_b a):**
```
f(n)         = Θ(n)
n^(log_b a)  = n

f(n) = Θ(n^(log_b a))  →  they are asymptotically equal
```

**Step 4 — Apply Case 2 of the Master Theorem:**

> When `f(n) = Θ(n^(log_b a))`, the solution is:
> `T(n) = Θ(n^(log_b a) · log n)`

**Result:**
```
T(n) = Θ(n · log n) = Θ(n log n)
```

### Complexity Summary

| Case | Complexity | Reason |
|---|---|---|
| Best case | Θ(n log n) | Always divides evenly |
| Average case | Θ(n log n) | Same recurrence |
| Worst case | Θ(n log n) | Never degrades — guaranteed |
| Space | Θ(n) | Auxiliary arrays during merge |

### Why This Matters for IVRPMS

For n = 10,000 veteran records:

| Algorithm | Operations (worst case) | Risk |
|---|---|---|
| Merge Sort | ~133,000 | None — always Θ(n log n) |
| Quicksort (naive pivot) | ~50,000,000 | Degrades on sorted input |
| Bubble Sort | ~100,000,000 | Never suitable at this scale |

Pension batch files are often partially sorted from prior runs.
Merge Sort's worst-case guarantee makes it the correct choice
for a system where latency and correctness are critical.

---

## Algorithm 2 — KMP String Matching

### Problem
Search 10,000 veteran service numbers for a pattern
(e.g. partial number `IC-400`) entered by a pension clerk.

### Why Not Naive Search?

Naive search compares pattern against text at every position:

```
Text:    J C - 4 0 0 0 1 | J C - 4 0 0 0 2 | I C - 4 0 0 0 3
Pattern: I C - 4 0 0
         ✗ (mismatch at position 0 — restart from scratch)
           ✗ (mismatch — restart again)
             ✗ (restart again)  ...
```

Worst case: every position requires a full pattern scan.
**Naive complexity: Θ(n × m)** where n = text length, m = pattern length.

### KMP Key Insight — The Failure Function

KMP preprocesses the pattern to build an LPS (Longest Proper
Prefix which is also a Suffix) array. On a mismatch, instead
of restarting from position 0, KMP jumps to `lps[j-1]` —
the next valid restart point.

**Example — pattern `IC-400`:**

```
Index:   0   1   2   3   4   5
Char:    I   C   -   4   0   0
LPS:     0   0   0   0   0   0
```

No prefix of `IC-400` is also a suffix, so all LPS values are 0.
On any mismatch, j resets to 0 — but i never goes backward.

**Example — pattern `ABCAB` (shows non-trivial LPS):**

```
Index:   0   1   2   3   4
Char:    A   B   C   A   B
LPS:     0   0   0   1   2
```

`AB` is both a prefix and suffix of `ABCAB`, so `lps[4] = 2`.
A mismatch after matching `ABCAB` jumps back to position 2,
not 0 — saving 2 comparisons.

### Complexity Analysis

**Preprocessing (build LPS):**
```
T_pre(m) = Θ(m)
```
The pointer `i` never decreases and `length` never exceeds `i`,
so the while loop runs at most 2m iterations → Θ(m).

**Search phase:**
```
T_search(n) = Θ(n)
```
Pointer `i` (text index) only ever moves forward.
Pointer `j` (pattern index) moves forward on match and backward
on mismatch — but backward moves are bounded by forward moves.
Total moves of `i` + `j` ≤ 2n → Θ(n).

**Total KMP complexity:**
```
T(n, m) = Θ(m) + Θ(n) = Θ(n + m)
```

### Comparison: Naive vs KMP

| n veterans | m (pattern len) | Naive Θ(n×m) | KMP Θ(n+m) | Speedup |
|---|---|---|---|---|
| 100 | 6 | 6,000 | 1,006 | 6× |
| 1,000 | 6 | 60,000 | 10,006 | 6× |
| 10,000 | 6 | 600,000 | 100,006 | 6× |

For IVRPMS with 10,000 service numbers (avg length 8):
- Text length n = 10,000 × 8 = 80,000 characters
- Naive: 80,000 × 6 = **480,000 comparisons**
- KMP:   80,000 + 6 = **80,006 comparisons**
- **KMP is 6× faster and never re-scans a character**

---

## Master Theorem — Three Cases Reference

For `T(n) = aT(n/b) + f(n)` where a ≥ 1, b > 1:

| Case | Condition | Solution | Example |
|---|---|---|---|
| Case 1 | f(n) = O(n^(log_b a − ε)) | T(n) = Θ(n^(log_b a)) | Binary search tree |
| **Case 2** | **f(n) = Θ(n^(log_b a))** | **T(n) = Θ(n^(log_b a) · log n)** | **Merge Sort ← IVRPMS** |
| Case 3 | f(n) = Ω(n^(log_b a + ε)) | T(n) = Θ(f(n)) | Matrix multiply |

Merge Sort falls under **Case 2** because the merge cost `f(n) = Θ(n)`
exactly matches the subproblem growth `n^(log₂ 2) = n`.

---

## Summary

| Algorithm | Use in IVRPMS | Complexity | Proof method |
|---|---|---|---|
| Merge Sort | Sort pension records for batch processing | Θ(n log n) | Master Theorem Case 2 |
| KMP Search | Find veterans by service number pattern | Θ(n + m) | Amortized analysis |
