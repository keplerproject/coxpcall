#!/usr/bin/env lua

package.path = "../src/?.lua;./src/?.lua"
local M = require("coxpcall")

local count, errortable = 0, {}

-- test helper functions
local function assert(ok, ...)
  if not ok then
    local msg = ...
    error(msg == nil and "assertion failed" or msg, 0)
  else
    return ok, ...
  end
end

local function error_is(f, xmsg)
  local ok, msg = pcall(f)
  assert(ok == false, "function did not raise an error")
  assert(msg == xmsg,
         "error message not as expected:\n\t"..tostring(msg))
  count = count + 1
end

local function error_matches(f, pat)
  local ok, msg = pcall(f)
  assert(ok == false, "function did not raise an error")
  assert(type(msg) == "string",
         "error message is not a string:\n\t"..type(msg))
  assert(msg:match(pat),
         "error message didn't match pattern:\n\t"..pat.."\n\t"..msg)
  count = count + 1
end

local function succeeds(f)
  local ok, msg = pcall(f)
  assert(ok, "function raised an error\n\t:"..tostring(msg))
  count = count + 1
end

local function succeeds_with(f, xrets)
  local function packrets(ok, ...)
    return ok, { n=select("#", ...), ... }
  end
  local ok, rets = packrets(pcall(f))
  assert(ok, "function raised an error\n\t:"..tostring(rets[1]))
  assert(rets.n == xrets.n or #xrets,
         "unexpected number of return values: "..rets.n..
         " (expected: "..(xrets.n or #xrets)..")")
  for i = 1, rets.n do
    assert(rets[i] == xrets[i],
           "unexpected return value no. "..i.." ("..
           tostring(rets[i])..", expected: "..tostring(xrets[i])..")")
  end
  count = count + 1
end

local function traceback()
  return "XXX"
end



-- the tests:

-- co(x)pcall from main thread
succeeds_with(function()
  return M.pcall(function(...)
    return ...
  end, 1, 2, 3)
end, { true, 1, 2, 3 })

succeeds_with(function()
  return M.xpcall(function()
    return 1, 2, 3
  end, debug.traceback)
end, { true, 1, 2, 3 })

error_matches(function()
  return assert(M.pcall(function(...)
    error("ARGH", 0)
  end, 1, 2, 3))
end, "ARGH")

error_is(function()
  return assert(M.pcall(function(...)
    error(errortable, 0)
  end, 1, 2, 3))
end, errortable)

error_matches(function()
  return assert(M.xpcall(function()
    error("ARGH", 0)
  end, debug.traceback))
end, "ARGH")

error_is(function()
  return assert(M.xpcall(function()
    error(errortable, 0)
  end, debug.traceback))
end, errortable)

error_matches(function()
  return assert(M.xpcall(function()
    error("ARGH", 0)
  end, traceback))
end, "XXX")

error_matches(function()
  return assert(M.pcall(rawset))
end, "bad argument")


-- co(x)pcall from within coroutine (without yielding)
succeeds_with(coroutine.wrap(function()
  return M.pcall(function(...)
    return ...
  end, 1, 2, 3)
end), { true, 1, 2, 3 })

succeeds_with(coroutine.wrap(function()
  return M.xpcall(function()
    return 1, 2, 3
  end, debug.traceback)
end), { true, 1, 2, 3 })

error_matches(coroutine.wrap(function()
  return assert(M.pcall(function(...)
    error("ARGH", 0)
  end, 1, 2, 3))
end), "ARGH")

error_is(coroutine.wrap(function()
  return assert(M.pcall(function(...)
    error(errortable, 0)
  end, 1, 2, 3))
end), errortable)

error_matches(coroutine.wrap(function()
  return assert(M.xpcall(function()
    error("ARGH", 0)
  end, debug.traceback))
end), "ARGH")

error_is(coroutine.wrap(function()
  return assert(M.xpcall(function()
    error(errortable, 0)
  end, debug.traceback))
end), errortable)

error_matches(coroutine.wrap(function()
  return assert(M.xpcall(function()
    error("ARGH", 0)
  end, traceback))
end), "XXX")

error_matches(coroutine.wrap(function()
  return assert(M.pcall(rawset))
end), "bad argument")


-- co(x)pcall from within coroutine (with yielding)
succeeds_with(function()
  local f = coroutine.wrap(function(...)
    return M.pcall(function(...)
      coroutine.yield()
      return ...
    end, ...)
  end)
  f(1, 2, 3)
  return f()
end, { true, 1, 2, 3 })

succeeds_with(function()
  local f = coroutine.wrap(function()
    return M.xpcall(function()
      coroutine.yield()
      return 1, 2, 3
    end, debug.traceback)
  end)
  f()
  return f()
end, { true, 1, 2, 3 })

error_matches(function()
  local f = coroutine.wrap(function(...)
    return assert(M.pcall(function(...)
      coroutine.yield()
      error("ARGH", 0)
    end, ...))
  end)
  f( 1, 2, 3)
  return f()
end, "ARGH")

error_is(function()
  local f = coroutine.wrap(function(...)
    return assert(M.pcall(function(...)
      coroutine.yield()
      error(errortable, 0)
    end, ...))
  end)
  f( 1, 2, 3)
  return f()
end, errortable)

error_matches(function()
  local f = coroutine.wrap(function()
    return assert(M.xpcall(function()
      coroutine.yield()
      error("ARGH", 0)
    end, debug.traceback))
  end)
  f()
  return f()
end, "ARGH")

error_is(function()
  local f = coroutine.wrap(function()
    return assert(M.xpcall(function()
      coroutine.yield()
      error(errortable, 0)
    end, debug.traceback))
  end)
  f()
  return f()
end, errortable)

error_matches(function()
  local f = coroutine.wrap(function()
    return assert(M.xpcall(function()
      coroutine.yield()
      error("ARGH", 0)
    end, traceback))
  end)
  f()
  return f()
end, "XXX")


-- running
succeeds(function()
  local co = coroutine.create(function()
    local _,c2 = M.pcall(M.running)
    local _,c3 = M.xpcall(M.running, debug.traceback)
    return c2, c3
  end)
  local _, r1, r2 = assert(coroutine.resume(co))
  assert(r1 == co, "running returned wrong thread")
  assert(r2 == co, "running returned wrong thread")
end)


print("OK", count)

