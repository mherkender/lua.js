
local s, r, r2, r3, r4, r5

-- string.byte( s[, start, end])
assert(string.byte("ABCDE") == 65)
assert(string.byte("ABCDE", 1) == 65)
assert(string.byte("ABCDE",0) == nil)   -- we're not using C
assert(string.byte("ABCDE",100) == nil)  -- index out of range, no value returned
local r, r2 = string.byte("ABCDE",3,4)
assert(r == 67 and r2 == 68)
local b, c, d, e = string.byte("ABCDE",2,10)
assert(b == 66 and c == 67 and d == 68 and e == 69)


-- string.gsub(s, pattern, replacement[, limit])
s = "Hello banana"
assert(string.gsub(s, "banana", "Lua user") == "Hello Lua user")
assert(string.gsub(s, "a", "A", 2) == "Hello bAnAna")
assert(string.gsub(s, "a(n)", "a(%1)") == "Hello ba(n)a(n)a")

r, r2 = string.gsub(s, "(a)(n)", "%2%1")
assert(r == "Hello bnanaa" and r2 == 2)

r, r2 = string.gsub(s, "(a)(n)", "%2%1", 1)
assert(r == "Hello bnaana" and r2 == 1)

r = {}
r2, r3 = string.gsub(s, "(%w+)", function(a) table.insert(r, a) end)
assert(r2 == s and r3 == #r and r[1] == "Hello" and r[2] == "banana")

r2, r3 = string.gsub(s, "(%w+)", function(w) return string.len(w) end, 1) -- replace with length
assert(r2 == "5 banana" and r3 == 1)

r, r2 = string.gsub(s, "(a)", string.upper, 10) -- make all "a"s found uppercase
assert(r == "Hello bAnAnA" and r2 == 3)

--r, r2 = string.gsub(s, "(a)(n)", function(a,b) return b..a end) -- reverse any "an"s
--assert(r == "Hello bnanaa" and r2 == 2)
-- function with two parameters are not supported
-- actually the capturing parenthesis are not supported with gsub, the whole matched expression is passed to the function


-- string.find(s, pattern[, index, plain])
r, r2 = string.find("Hello Lua user", "Lua")
assert(r == 7 and r2 == 9)

r, r2 = string.find("Hello Lua user", "banana")
assert(r == nil and r2 == nil)

r, r2 = string.find("Hello Lua user", "Lua", 1) -- start at first character
assert(r == 7 and r2 == 9)

r, r2 = string.find("Hello Lua user", "Lua", 8) -- "Lua" not found again after character 8
assert(r == nil and r2 == nil)

r, r2 = string.find("Hello Lua user", "e", -5) -- first "e" 5 characters from the end
assert(r == 13 and r2 == 13)

r, r2 = string.find("Hello Lua user", "%su") -- find a space character followed by "u"
assert(r == 10 and r2 == 11)

r, r2 = string.find("Hello Lua user", "%su", 1, true) -- turn on plain searches, now not found
assert(r == nil and r2 == nil)


r, r2, r3 = string.find("11 12 13", "(1%d)")
assert(r == 1 and r2 == 2 and r3 == "11")

r, r2, r3 = string.find("11 12 13", "(1%d)", 3)
assert(r == 4 and r2 == 5 and r3 == "12")

r, r2, r3, r4, r5 = string.find("11 12 13", "(1%d) (1%d) (1%d)")
assert(r == 1 and r2 == 8 and r3 == "11" and r4 == "12" and r5 == "13")

r, r2, r3 = string.find("123456789", "2(34)5") -- turn on plain searches, now not found
assert(r == 2 and r2 == 5 and r3 == "34")

r = string.find("123456789", "45678", 7) -- turn on plain searches, now not found
assert(r == nil)

r, r2 = string.find("one.two.three.for", ".") -- turn on plain searches, now not found
assert(r == 1 and r2 == 1)

r, r2 = string.find("one.two.three.for", ".", 5) -- turn on plain searches, now not found
assert(r == 5 and r2 == 5)

r, r2 = string.find("one.two.three.for", ".", 5, true) -- turn on plain searches, now not found
assert(r == 8 and r2 == 8)


-- string.match(s, pattern[, index])
assert(string.match("I have 2 questions for you.", "%d+ %a+") == "2 questions")
assert(string.match("I have 2 questions for you.", "%D+", 3) == "have ")
assert(string.match("I have 2 questions for you.", "foobar") == nil)
assert(string.match("I have 2 questions for you.", "2 (%w+)") == "questions")
assert(string.match("I have 2 questions for you.", "%bso") == "stio") -- %dxy
assert(string.match("I have 2 questins for you.", "%bso") == "stins for yo") -- %dxy


-- string.gmatch(pattern)
r = {}
for word in string.gmatch("Hello Lua user", "%a+") do 
    table.insert(r, word)
end
r2 = { "Hello", "Lua", "user"}
for i, word in ipairs(r) do
    assert(word == r2[i])
end

r = {}
for word in string.gmatch('axbycxdye', 'x([^x]+)') do 
    table.insert(r, word)
end
r2 = {"byc", "dye"}
for i, word in ipairs(r) do
    assert(word == r2[i])
end

r = {}
for word in string.gmatch('a(b)c(d)e', '%b()') do 
    table.insert(r, word)
end
r2 = {"(b)", "(d)"}
for i, word in ipairs(r) do
    assert(word == r2[i])
end


-- string.format(s, e1[, e2, ...])
assert(string.format("%s %q", "Hello", "Lua user!") == 'Hello "Lua user!"') -- string and quoted string
assert(string.format("%c%c%c", 76,117,97) == "Lua") -- char
assert(string.format("%e, %E", math.pi,math.pi) == "3.141593e+000, 3.141593E+000") -- exponent
assert(string.format("%f, %g", math.pi,math.pi) == "3.141593, 3.14159") -- float and compact float
assert(string.format("%d, %i, %u", -100,-100,-100) == "-100, -100, 4294967196") -- signed, signed, unsigned integer
assert(string.format("%o, %x, %X", -100,-100,-100) == "37777777634, ffffff9c, FFFFFF9C") -- octal, hex, hex
