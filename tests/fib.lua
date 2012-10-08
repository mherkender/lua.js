-- fibonacci function with cache

-- very inefficient fibonacci function
function fib(n)
	N=N+1
	if n<2 then
		return n
	else
		return fib(n-1)+fib(n-2)
	end
end

-- a general-purpose value cache
function cache(f)
	local c={}
	return function (x)
		local y=c[x]
		if not y then
			y=f(x)
			c[x]=y
		end
		return y
	end
end

cached_fib = cache(fib)


N=0
assert(fib(24) == 46368)

N=0
assert(cached_fib(24) == 46368)
