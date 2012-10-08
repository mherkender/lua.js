-- function closures are powerful

-- traditional fixed-point operator from functional programming
Y = function (g)
      local a = function (f) return f(f) end
      return a(function (f)
                 return g(function (x)
                             local c=f(f)
                             return c(x)
                           end)
               end)
end


-- factorial without recursion
F = function (f)
      return function (n)
               if n == 0 then return 1
               else return n*f(n-1) end
             end
    end

factorial = Y(F)   -- factorial is the fixed point of F

-- now test it
assert(factorial(0) == 1)
assert(factorial(1) == 1)
assert(factorial(2) == 2)
assert(factorial(3) == 6)
assert(factorial(4) == 24)
assert(factorial(5) == 120)
assert(factorial(6) == 720)
assert(factorial(7) == 5040)
assert(factorial(8) == 40320)
assert(factorial(9) == 362880)
assert(factorial(10) == 3628800)
assert(factorial(11) == 39916800)
assert(factorial(12) == 479001600)
assert(factorial(13) == 6227020800)
assert(factorial(14) == 87178291200)
assert(factorial(15) == 1307674368000)
assert(factorial(16) == 20922789888000)
