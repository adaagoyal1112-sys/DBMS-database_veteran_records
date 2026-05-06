# ============================================================
# IVRPMS — 03-algorithms/merge_sort.py
#
# Merge Sort implementation applied to IVRPMS veteran records
#
# RECURRENCE:  T(n) = 2T(n/2) + Θ(n)
# PROOF:       Master Theorem Case 2 → Θ(n log n)
# USE CASE:    Sorting pension disbursement lists before
#              batch processing and monthly report generation
#
# WHY MERGE SORT OVER QUICKSORT FOR IVRPMS:
#   - Guaranteed Θ(n log n) in ALL cases (best/avg/worst)
#   - Quicksort degrades to Θ(n²) on sorted/nearly-sorted input
#   - Pension batch files are often partially sorted from prior runs
#   - For 10,000 records: Merge Sort = ~133,000 ops (always)
#                         Quicksort  = up to 50,000,000 ops (worst)
# ============================================================

import time
import random


# ============================================================
# CORE ALGORITHM: Merge Sort
#
# DIVIDE phase:
#   Split the list into two halves — left and right
#   Each half is sorted recursively (same function called again)
#   Base case: a list of 0 or 1 element is already sorted
#
# CONQUER phase (merge):
#   Given two already-sorted halves, merge them into one
#   sorted list by comparing front elements one at a time
#   This merge step costs Θ(n) — linear in the input size
#
# RECURRENCE EXPLANATION:
#   T(n) = cost of two subproblems + cost of merging
#   T(n) = 2 · T(n/2)  +  Θ(n)
#            ↑                ↑
#       two halves       merge cost
# ============================================================

def merge_sort(records, key='monthly_pension'):
    """
    Sorts a list of veteran record dictionaries.

    Parameters:
        records (list): list of veteran dicts
        key     (str) : field to sort by (default: monthly_pension)

    Returns:
        list: sorted list of veteran dicts

    Complexity: Θ(n log n) — all cases
    Space:      Θ(n)       — auxiliary arrays during merge
    """

    # ── BASE CASE ─────────────────────────────────────────────
    # A single record (or empty list) is trivially sorted.
    # Every recursive call eventually reaches this point.
    if len(records) <= 1:
        return records

    # ── DIVIDE ────────────────────────────────────────────────
    # Find the midpoint and split into two halves.
    # This is the "2T(n/2)" part of the recurrence.
    mid   = len(records) // 2
    left  = merge_sort(records[:mid], key)   # sort left half
    right = merge_sort(records[mid:], key)   # sort right half

    # ── CONQUER (merge) ────────────────────────────────────────
    # Merge the two sorted halves — this is the "Θ(n)" part.
    return merge(left, right, key)


def merge(left, right, key):
    """
    Merges two sorted lists into one sorted list.
    Runs in Θ(n) time where n = len(left) + len(right).

    At each step, the smaller front element is appended.
    When one side is exhausted, the rest of the other is
    appended directly (already sorted).
    """
    result = []
    i = 0   # pointer for left half
    j = 0   # pointer for right half

    # Compare front elements of both halves, pick the smaller
    while i < len(left) and j < len(right):
        if left[i][key] <= right[j][key]:
            result.append(left[i])
            i += 1
        else:
            result.append(right[j])
            j += 1

    # Append remaining elements (at most one side has leftovers)
    result.extend(left[i:])
    result.extend(right[j:])

    return result


# ============================================================
# IVRPMS APPLICATION: Sort veteran records by pension amount
#
# This mirrors what sp_monthly_batch_report does in SQL —
# before disbursing, records are sorted so the highest pension
# recipients are processed first (priority processing rule).
# ============================================================

def sort_veterans_by_pension(veteran_records):
    """Sort veteran records by monthly_pension descending."""
    sorted_asc = merge_sort(veteran_records, key='monthly_pension')
    return sorted_asc[::-1]   # reverse for descending order


def sort_veterans_by_service(veteran_records):
    """Sort veteran records by years_of_service descending."""
    sorted_asc = merge_sort(veteran_records, key='years_of_service')
    return sorted_asc[::-1]


# ============================================================
# COMPLEXITY DEMONSTRATION
# Shows T(n) = 2T(n/2) + Θ(n) in action by counting
# the number of comparisons made during a sort.
# ============================================================

comparison_count = 0

def merge_sort_counted(records, key='monthly_pension'):
    """Merge sort that counts comparisons — proves Θ(n log n)."""
    global comparison_count

    if len(records) <= 1:
        return records

    mid   = len(records) // 2
    left  = merge_sort_counted(records[:mid], key)
    right = merge_sort_counted(records[mid:], key)
    return merge_counted(left, right, key)


def merge_counted(left, right, key):
    global comparison_count
    result = []
    i, j = 0, 0

    while i < len(left) and j < len(right):
        comparison_count += 1          # count every comparison
        if left[i][key] <= right[j][key]:
            result.append(left[i])
            i += 1
        else:
            result.append(right[j])
            j += 1

    result.extend(left[i:])
    result.extend(right[j:])
    return result


# ============================================================
# SAMPLE DATA — 20 synthetic IVRPMS veteran records
# ============================================================

sample_veterans = [
    {'veteran_id': 1001, 'name': 'Rajinder Singh',   'rank': 'Subedar',       'monthly_pension': 19550, 'years_of_service': 30},
    {'veteran_id': 1002, 'name': 'Gurpreet Kumar',   'rank': 'Havildar',      'monthly_pension': 14600, 'years_of_service': 30},
    {'veteran_id': 1003, 'name': 'Arun Sharma',      'rank': 'Colonel',       'monthly_pension': 65300, 'years_of_service': 36},
    {'veteran_id': 1004, 'name': 'Vijay Yadav',      'rank': 'Naib Subedar', 'monthly_pension': 17700, 'years_of_service': 30},
    {'veteran_id': 1005, 'name': 'Suresh Verma',     'rank': 'Brigadier',     'monthly_pension': 69800, 'years_of_service': 36},
    {'veteran_id': 1006, 'name': 'Balwinder Singh',  'rank': 'Subedar Major', 'monthly_pension': 21800, 'years_of_service': 30},
    {'veteran_id': 1007, 'name': 'Mahesh Tiwari',    'rank': 'Major',         'monthly_pension': 34700, 'years_of_service': 30},
    {'veteran_id': 1008, 'name': 'Paramjit Singh',   'rank': 'Naik',          'monthly_pension': 12600, 'years_of_service': 30},
    {'veteran_id': 1009, 'name': 'Rakesh Mishra',    'rank': 'Lt. Colonel',   'monthly_pension': 60600, 'years_of_service': 35},
    {'veteran_id': 1010, 'name': 'Amarjit Thakur',   'rank': 'Subedar',       'monthly_pension': 19550, 'years_of_service': 30},
    {'veteran_id': 1011, 'name': 'Dinesh Joshi',     'rank': 'Colonel',       'monthly_pension': 65300, 'years_of_service': 36},
    {'veteran_id': 1012, 'name': 'Satinder Chauhan', 'rank': 'Havildar',      'monthly_pension': 14600, 'years_of_service': 30},
    {'veteran_id': 1013, 'name': 'Naresh Reddy',     'rank': 'Major',         'monthly_pension': 34700, 'years_of_service': 30},
    {'veteran_id': 1014, 'name': 'Kulwant Solanki',  'rank': 'Naib Subedar', 'monthly_pension': 17700, 'years_of_service': 30},
    {'veteran_id': 1015, 'name': 'Girish Nair',      'rank': 'Brigadier',     'monthly_pension': 69800, 'years_of_service': 36},
    {'veteran_id': 1016, 'name': 'Tejinder Rathore', 'rank': 'Subedar',       'monthly_pension': 19550, 'years_of_service': 30},
    {'veteran_id': 1017, 'name': 'Ravinder Pillai',  'rank': 'Lt. Colonel',   'monthly_pension': 60600, 'years_of_service': 36},
    {'veteran_id': 1018, 'name': 'Davinder Bose',    'rank': 'Havildar',      'monthly_pension': 14600, 'years_of_service': 30},
    {'veteran_id': 1019, 'name': 'Harcharan Rao',    'rank': 'Colonel',       'monthly_pension': 65300, 'years_of_service': 37},
    {'veteran_id': 1020, 'name': 'Dilbagh Patil',    'rank': 'Naik',          'monthly_pension': 12600, 'years_of_service': 30},
]


# ============================================================
# MAIN — runs all demonstrations
# ============================================================

if __name__ == '__main__':

    print("=" * 60)
    print("IVRPMS — Merge Sort Algorithm Demo")
    print("Recurrence: T(n) = 2T(n/2) + Θ(n)")
    print("Solution:   Θ(n log n)  [Master Theorem Case 2]")
    print("=" * 60)

    # ── Demo 1: Sort by pension amount (descending) ───────────
    print("\n[1] Veterans sorted by monthly pension (highest first):\n")
    sorted_by_pension = sort_veterans_by_pension(sample_veterans)
    print(f"  {'ID':<6} {'Name':<22} {'Rank':<16} {'Pension (₹)'}")
    print(f"  {'-'*6} {'-'*22} {'-'*16} {'-'*12}")
    for v in sorted_by_pension:
        print(f"  {v['veteran_id']:<6} {v['name']:<22} "
              f"{v['rank']:<16} ₹{v['monthly_pension']:>10,}")

    # ── Demo 2: Sort by years of service ─────────────────────
    print("\n[2] Veterans sorted by years of service (most first):\n")
    sorted_by_service = sort_veterans_by_service(sample_veterans)
    print(f"  {'ID':<6} {'Name':<22} {'Rank':<16} {'Years'}")
    print(f"  {'-'*6} {'-'*22} {'-'*16} {'-'*5}")
    for v in sorted_by_service:
        print(f"  {v['veteran_id']:<6} {v['name']:<22} "
              f"{v['rank']:<16} {v['years_of_service']} yrs")

    # ── Demo 3: Complexity proof with comparison count ────────
    print("\n[3] Complexity proof — comparison count vs n log n:\n")
    print(f"  {'n':>6}  {'Comparisons':>12}  {'n×log₂n':>12}  {'Ratio':>8}")
    print(f"  {'-'*6}  {'-'*12}  {'-'*12}  {'-'*8}")

    import math
    for n in [10, 50, 100, 500, 1000, 5000, 10000]:
        test_data = [
            {'monthly_pension': random.randint(10000, 100000),
             'years_of_service': random.randint(15, 35)}
            for _ in range(n)
        ]
        comparison_count = 0
        merge_sort_counted(test_data)
        nlogn = round(n * math.log2(n), 0)
        ratio = round(comparison_count / nlogn, 3)
        print(f"  {n:>6}  {comparison_count:>12,}  {nlogn:>12,.0f}  {ratio:>8}")

    print("\n  Ratio ≈ 1.0 confirms Θ(n log n) growth — Master Theorem Case 2")

    # ── Demo 4: Performance timing ────────────────────────────
    print("\n[4] Performance timing on large inputs:\n")
    for n in [1000, 5000, 10000]:
        data = [{'monthly_pension': random.randint(10000, 150000)}
                for _ in range(n)]
        start = time.perf_counter()
        merge_sort(data)
        elapsed = time.perf_counter() - start
        print(f"  n={n:>6,} records → {elapsed*1000:.3f} ms")

    print("\n" + "=" * 60)
    print("Merge Sort complete. All veteran records sorted.")
    print("Ready for sp_monthly_batch_report() disbursement run.")
    print("=" * 60)
