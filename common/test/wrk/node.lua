local counter = 1
local threads = {}
function setup(thread)
   thread:set("counter", counter)
   table.insert(threads, thread)
   counter = counter + 1
   addrs = wrk.lookup(wrk.host, wrk.port or "http")
   for i = #addrs, 1, -1 do
    if not wrk.connect(addrs[i]) then
      table.remove(addrs, i)
    end
   end
end

function init(args)
    nodeCache={}
    gwCache={}
    if #args >= 1 then
        domain = args[1]
    end
    if #args >= 2 then
        blockchain = args[2]
    end
    if #args >= 3 then
        id = args[3]
    end
    if #args >= 4 then
        token = args[4]
    end

    local msg = "thread addr:%s"
    print(msg:format(wrk.thread.addr))
end

function request()
    local randomId = math.random(10)
    local headers = {}
    headers["Content-Type"] = "application/json"
    local id = wrk.thread:get("id")
    local domain = wrk.thread:get("domain") or "massbitroute.dev"
    local blockchain = wrk.thread:get("blockchain")
    local token = wrk.thread:get("token")
    local body = _getBody(blockchain)
    if token then
        headers["X-Api-Key"] = token
    end
    headers["Host"] = id .. ".node.mbr." .. domain
    local body = _getBody(blockchain)
    if path == nill or path == '' then
      return wrk.format("POST", wrk.path, headers, body)
    else
      return wrk.format("POST", wrk.path .. "/" .. path, headers, body)
    end
end

function _getBody(blockchain)
  local randomId = math.random(10)
  if blockchain == 'eth' then
    return '{"id": "' .. randomId .. '", "jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": ["latest", false]}'
  end
  if blockchain == 'dot' then
    return '{"id": "' .. randomId .. '", "jsonrpc": "2.0", "method": "chain_getBlock", "params": []}'
  end
end
function response(status, headers, body)
    --wrk.headers["Cookie"] = ''
    local msg = "Response header: %s => %s\n"
    --print("-----------\n")
    for key, value in pairs(headers) do
        if key == "X-Mbr-Node-Cached" then
            -- print(key ..":" .. value)
            --print(nodeCache[value])
            --table.insert(nodeCache, )
            --nodeCache[value] = nodeCache[value] and (nodeCache[value] + 1) or 1
            nodeCache[value] = (nodeCache[value] or 0) + 1
        end
        if key == "X-Mbr-Cached" then
            -- print(key ..":" .. value)
            gwCache[value] = (gwCache[value] or 0) + 1
        end
        -- if key:find("X-Mbr", 1, true) == 1 then
        --    print(msg:format(key, value))
        -- end
        --io.write(string.format("%s,%s%\n", key, value))
        --if string.starts(key, "Set-Cookie") then
            -- wrk.headers["Cookie"] = wrk.headers["Cookie"] .. string.sub(value, 0, string.find(value, ";") - 1) .. ';'
        --end
    end
    --print("-----------\n")
end

function done(summary, latency, requests)
   io.write("------------------------------\n")
   for _, p in pairs({ 80, 90, 95, 99, 99.9 }) do
      n = latency:percentile(p)
      io.write(string.format("%g%%,%d\n", p, n))
   end
   --io.write("Node cache status\n")
   for _, thread in ipairs(threads) do
         local counter        = thread:get("counter")
         local nodeCache  = thread:get("nodeCache")
         local gwCache = thread:get("gwCache")
         local msg = "Cache counter in thread %s: %s => %s\n"
         for ___key, ___value in pairs(nodeCache) do
            --print("--", ___key, ___value)
         end
         for ___key, ___value in pairs(gwCache) do
             --print("--", ___key, ___value)
          end
         --local msg = "thread %d made %d requests and got %d responses"
         --print(msg:format(id, requests, responses))
   end
end
