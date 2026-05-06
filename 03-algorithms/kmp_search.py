# ============================================================
# IVRPMS — 03-algorithms/kmp_search.py
#
# Knuth-Morris-Pratt (KMP) String Matching Algorithm
# Applied to IVRPMS service number search
#
# TIME COMPLEXITY:  Θ(n + m)
#   n = length of text being searched
#   m = length of pattern being searched for
#   Preprocessing (failure function): Θ(m)
#   Search phase:                     Θ(n)
#
# WHY KMP OVER NAIVE SEARCH FOR IVRPMS:
#   Naive search: Θ(n × m) — re-scans characters on mismatch
#   KMP:          Θ(n + m) — never re-scans using failure table
#
#   For 10,000 service numbers of length ~10 each:
#   Naive worst case: 10,000 × 10 × 10 = 1,000,000 comparisons
#   KMP:              10,000 × (10+10) =   200,000 comparisons
#
# USE CASE:
#   A clerk types a partial service number like "IC-400"
#   KMP finds all matching veterans instantly from the full
#   concatenated service number registry string.
# ============================================================


# ============================================================
# PHASE 1: Build the Failure Function (LPS array)
#
# LPS = Longest Proper Prefix which is also a Suffix
#
# This is the preprocessing step that makes KMP efficient.
# It encodes "how far to jump back" on a mismatch so we
# never re-examine characters we already matched.
#
# Example for pattern "IC-400":
#   Index: 0  1  2  3  4  5
#   Char:  I  C  -  4  0  0
#   LPS:   0  0  0  0  0  0
#   (no prefix matches any suffix here)
#
# Example for pattern "ABAB":
#   Index: 0  1  2  3
#   Char:  A  B  A  B
#   LPS:   0  0  1  2
#   ("AB" is both a prefix and suffix of "ABAB")
# ============================================================

def build_failure_function(pattern):
    """
    Builds the LPS (failure function) array for the pattern.

    Parameters:
        pattern (str): the search pattern

    Returns:
        list: LPS array of length len(pattern)

    Time:  Θ(m) where m = len(pattern)
    Space: Θ(m)
    """
    m   = len(pattern)
    lps = [0] * m       # lps[0] is always 0

    length = 0          # length of previous longest prefix-suffix
    i      = 1          # start from index 1 (lps[0] always = 0)

    while i < m:
        if pattern[i] == pattern[length]:
            # Characters match — extend the prefix-suffix
            length += 1
            lps[i]  = length
            i       += 1
        else:
            if length != 0:
                # Fall back using previously computed lps value
                # This is the key insight — we don't reset to 0
                length = lps[length - 1]
                # Do NOT increment i here
            else:
                # No prefix-suffix possible — lps[i] = 0
                lps[i] = 0
                i      += 1

    return lps


# ============================================================
# PHASE 2: KMP Search
#
# Uses the LPS array to avoid redundant comparisons.
# On a mismatch after j matches, instead of restarting from
# scratch, we jump to lps[j-1] — the longest prefix of the
# pattern that is also a valid restart point.
# ============================================================

def kmp_search(text, pattern):
    """
    Finds all occurrences of pattern in text using KMP.

    Parameters:
        text    (str): the string to search in
        pattern (str): the string to search for

    Returns:
        list: starting indices where pattern is found in text

    Time:  Θ(n + m) where n=len(text), m=len(pattern)
    Space: Θ(m) for the LPS array
    """
    n   = len(text)
    m   = len(pattern)
    matches = []

    if m == 0:
        return matches

    # Preprocess — build failure function
    lps = build_failure_function(pattern)

    i = 0   # index into text
    j = 0   # index into pattern

    while i < n:
        if pattern[j] == text[i]:
            # Characters match — advance both pointers
            i += 1
            j += 1

        if j == m:
            # Full pattern matched — record position
            matches.append(i - j)
            # Use lps to find next possible match start
            j = lps[j - 1]

        elif i < n and pattern[j] != text[i]:
            # Mismatch after j matches
            if j != 0:
                # Jump back using failure function — key KMP step
                j = lps[j - 1]
            else:
                # No partial match — advance text pointer only
                i += 1

    return matches


# ============================================================
# IVRPMS APPLICATION: Search veteran service numbers
#
# All service numbers are concatenated into a single searchable
# text string (simulating a flat file or index scan).
# KMP finds every veteran whose service number contains the
# search pattern — handles partial matches like "IC-400".
# ============================================================

def search_service_numbers(veterans, pattern):
    """
    Search all veteran service numbers for a pattern.

    Parameters:
        veterans (list): list of veteran dicts with 'service_number'
        pattern  (str) : pattern to search for (e.g. 'IC-400')

    Returns:
        list: matching veteran records
    """
    results = []
    for veteran in veterans:
        svc_no = veteran['service_number']
        # KMP search on each service number string
        matches = kmp_search(svc_no, pattern)
        if matches:
            results.append({
                'veteran': veteran,
                'match_position': matches[0]
            })
    return results


def build_registry_string(veterans):
    """
    Concatenates all service numbers with a separator.
    Used for bulk pattern search across the full registry.
    Format: 'JC-40001|JC-40002|IC-40003|...'
    """
    return '|'.join(v['service_number'] for v in veterans)


# ============================================================
# SAMPLE DATA
# ============================================================

sample_veterans = [
    {'veteran_id': 1001, 'service_number': 'JC-40001', 'name': 'Rajinder Singh',   'rank': 'Subedar'},
    {'veteran_id': 1002, 'service_number': 'JC-40002', 'name': 'Gurpreet Kumar',   'rank': 'Havildar'},
    {'veteran_id': 1003, 'service_number': 'IC-40003', 'name': 'Arun Sharma',      'rank': 'Colonel'},
    {'veteran_id': 1004, 'service_number': 'JC-40004', 'name': 'Vijay Yadav',      'rank': 'Naib Subedar'},
    {'veteran_id': 1005, 'service_number': 'IC-40005', 'name': 'Suresh Verma',     'rank': 'Brigadier'},
    {'veteran_id': 1006, 'service_number': 'JC-40006', 'name': 'Balwinder Singh',  'rank': 'Subedar Major'},
    {'veteran_id': 1007, 'service_number': 'IC-40007', 'name': 'Mahesh Tiwari',    'rank': 'Major'},
    {'veteran_id': 1008, 'service_number': 'JC-40008', 'name': 'Paramjit Singh',   'rank': 'Naik'},
    {'veteran_id': 1009, 'service_number': 'IC-40009', 'name': 'Rakesh Mishra',    'rank': 'Lt. Colonel'},
    {'veteran_id': 1010, 'service_number': 'JC-40010', 'name': 'Amarjit Thakur',   'rank': 'Subedar'},
    {'veteran_id': 1011, 'service_number': 'IC-40011', 'name': 'Dinesh Joshi',     'rank': 'Colonel'},
    {'veteran_id': 1012, 'service_number': 'JC-40012', 'name': 'Satinder Chauhan', 'rank': 'Havildar'},
    {'veteran_id': 1013, 'service_number': 'IC-40013', 'name': 'Naresh Reddy',     'rank': 'Major'},
    {'veteran_id': 1014, 'service_number': 'JC-40014', 'name': 'Kulwant Solanki',  'rank': 'Naib Subedar'},
    {'veteran_id': 1015, 'service_number': 'IC-40015', 'name': 'Girish Nair',      'rank': 'Brigadier'},
    {'veteran_id': 1016, 'service_number': 'JC-40016', 'name': 'Tejinder Rathore', 'rank': 'Subedar'},
    {'veteran_id': 1017, 'service_number': 'IC-40017', 'name': 'Ravinder Pillai',  'rank': 'Lt. Colonel'},
    {'veteran_id': 1018, 'service_number': 'JC-40018', 'name': 'Davinder Bose',    'rank': 'Havildar'},
    {'veteran_id': 1019, 'service_number': 'IC-40019', 'name': 'Harcharan Rao',    'rank': 'Colonel'},
    {'veteran_id': 1020, 'service_number': 'JC-40020', 'name': 'Dilbagh Patil',    'rank': 'Naik'},
]


# ============================================================
# MAIN — demonstrations
# ============================================================

if __name__ == '__main__':

    print("=" * 60)
    print("IVRPMS — KMP String Matching Algorithm Demo")
    print("Time Complexity: Θ(n + m)")
    print("Preprocessing:   Θ(m)  — build failure function")
    print("Search:          Θ(n)  — single pass through text")
    print("=" * 60)

    # ── Demo 1: Search for officer prefix "IC-" ───────────────
    print("\n[1] Search pattern 'IC-' — find all officer veterans:\n")
    results = search_service_numbers(sample_veterans, 'IC-')
    print(f"  {'Service No':<12} {'Name':<22} {'Rank'}")
    print(f"  {'-'*12} {'-'*22} {'-'*16}")
    for r in results:
        v = r['veteran']
        print(f"  {v['service_number']:<12} {v['name']:<22} {v['rank']}")
    print(f"\n  Found {len(results)} officer veterans matching 'IC-'")

    # ── Demo 2: Partial service number search ─────────────────
    print("\n[2] Search pattern '40005' — partial number lookup:\n")
    results = search_service_numbers(sample_veterans, '40005')
    if results:
        for r in results:
            v = r['veteran']
            print(f"  Match: {v['service_number']} — {v['name']} ({v['rank']})")
    else:
        print("  No matches found.")

    # ── Demo 3: Show LPS failure function ─────────────────────
    print("\n[3] Failure function (LPS array) for pattern 'IC-400':\n")
    pattern = 'IC-400'
    lps     = build_failure_function(pattern)
    print(f"  Pattern : {' '.join(pattern)}")
    print(f"  Index   : {' '.join(str(i) for i in range(len(pattern)))}")
    print(f"  LPS     : {' '.join(str(x) for x in lps)}")
    print(f"\n  LPS[i]=0 means no prefix of 'IC-400' is also a suffix")
    print(f"  On mismatch at position i, jump back to LPS[i-1]")

    # ── Demo 4: Bulk registry search ─────────────────────────
    print("\n[4] Bulk registry search — KMP on concatenated string:\n")
    registry = build_registry_string(sample_veterans)
    print(f"  Registry string (first 60 chars): {registry[:60]}...")
    print(f"  Total registry length: {len(registry)} characters\n")

    search_pattern = 'JC-400'
    positions = kmp_search(registry, search_pattern)
    print(f"  Pattern '{search_pattern}' found at {len(positions)} positions")
    print(f"  Positions: {positions[:8]}{'...' if len(positions)>8 else ''}")

    # ── Demo 5: Complexity comparison ─────────────────────────
    import math
    print("\n[5] KMP vs Naive search — comparison count:\n")
    print(f"  {'n veterans':<12} {'Naive Θ(n×m)':<16} {'KMP Θ(n+m)':<14} {'Speedup'}")
    print(f"  {'-'*12} {'-'*16} {'-'*14} {'-'*10}")
    m = 6   # pattern length 'IC-400'
    for n_vets in [100, 500, 1000, 5000, 10000]:
        n        = n_vets * 10      # avg service number length = 8 chars
        naive    = n * m
        kmp      = n + m
        speedup  = round(naive / kmp, 1)
        print(f"  {n_vets:<12,} {naive:<16,} {kmp:<14,} {speedup}×")

    print("\n  KMP eliminates redundant comparisons via the LPS table")
    print("  On mismatch: naive restarts from 0, KMP jumps to LPS[j-1]")

    print("\n" + "=" * 60)
    print("KMP Search complete.")
    print("=" * 60)
