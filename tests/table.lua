local a = {1, 2, 3, 4}
assert(table.remove(a, 1) == 1)
assert(table.remove(a, 2) == 3)
assert(table.remove(a) == 4)
assert(#a == 1)
assert(a[1] == 2)
