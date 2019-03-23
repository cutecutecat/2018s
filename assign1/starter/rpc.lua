local util = require("common.util")
local posix = require("posix")
local Pipe = util.Pipe
local mod = {}

function mod.get_tuple(nowat, trans)
    return string.format("(%d,%d)", nowat, nowat + string.len(trans))
end

function seri(t, begin)
    if begin == true then
        nowat = 0
        types = ""
        info = ""
    end
    if type(t) == "number" then
        trans = string.format("%d", t)
        types = string.format("%snumber%s", types, mod.get_tuple(nowat, trans))
        nowat = nowat + string.len(trans)
        info = info .. trans
    elseif type(t) == "string" then
        trans = string.format("%s", t)
        types = string.format("%sstring%s", types, mod.get_tuple(nowat, trans))
        nowat = nowat + string.len(trans)
        info = info .. trans
    elseif type(t) == "table" then
        types = types .. "dict{"
        for k, v in pairs(t) do
            seri(k, false)
            types = types .. ":"
            seri(v, false)
            types = types .. ";"
        end
        types = types .. "}"
    elseif type(t) == "boolean" then
        trans = t and "true" or "false"
        types = string.format("%sboolean%s", types, mod.get_tuple(nowat, trans))
        nowat = nowat + string.len(trans)
        info = info .. trans
    elseif type(t) == "function" then

        trans = string.format("%s", string.dump(t))
        types = string.format("%sfunction%s", types, mod.get_tuple(nowat, trans))
        nowat = nowat + string.len(trans)
        info = info .. trans
    elseif type(t) == "nil" then
        trans = "nil"
        types = string.format("%snil%s", types, mod.get_tuple(nowat, trans))
        nowat = nowat + string.len(trans)
        info = info .. trans
    end
    result = string.format("%d%s%s", string.len(types), types, info)
    return result, nowat
end

function dese(s, begin)
    if begin == true then
        mode_num = "%d+"
        from, to = string.find(s, mode_num)
        l = tonumber(string.sub(s, from, to))
        types = string.sub(s, to + 1, to + l)
        info = string.sub(s, to + l + 1)
    end

    mode_base = "%((%d+),(%d+)%)"

    if string.sub(types, 1, 4) == ("dict") then
        local result = {}
        local key, val
        types = string.sub(types, 6)

        while string.sub(types, 1, 1) ~= "}" do
            key = dese(nil, false)
            val = dese(nil, false)
            result[key] = val
        end
        types = string.sub(types, 3)
        return result
    elseif string.sub(types, 1, 7) == "boolean" then
        _, all_to, from, to = string.find(types, "boolean" .. mode_base)
        from = tonumber(from)
        to = tonumber(to)
        types = string.sub(types, all_to + 2)
        return mod.toboolean(string.sub(info, from + 1, to))
    elseif string.sub(types, 1, 6) == "string" then
        _, all_to, from, to = string.find(types, "string" .. mode_base)
        from = tonumber(from)
        to = tonumber(to)
        types = string.sub(types, all_to + 2)
        return string.sub(info, from + 1, to)
    elseif string.sub(types, 1, 6) == "number" then
        _, all_to, from, to = string.find(types, "number" .. mode_base)
        from = tonumber(from)
        to = tonumber(to)
        types = string.sub(types, all_to + 2)
        return tonumber(string.sub(info, from + 1, to))
    elseif string.sub(types, 1, 8) == "function" then
        _, all_to, from, to = string.find(types, "function" .. mode_base)
        from = tonumber(from)
        to = tonumber(to)
        types = string.sub(types, all_to + 2)
        return load(string.sub(info, from + 1, to))
    elseif string.sub(types, 1, 3) == "nil" then
        _, all_to, from, to = string.find(types, "nil" .. mode_base)
        from = tonumber(from)
        to = tonumber(to)
        types = string.sub(types, all_to + 2)
        return nil
    end
end

function mod.serialize(t)
    return seri(t, true)

end

function mod.deserialize(s)
    return dese(s, true)
end

function tablelength(T)
    local count = 0
    for _ in pairs(T) do
        count = count + 1
    end
    return count
end



-- split by the first occurance
function mod.split2(str, pat)
    local words = {}
    idx = string.find(str, pat)
    if idx == nil then
        return words
    end
    table.insert(words, string.sub(str, 1, idx - 1))
    table.insert(words, string.sub(str, idx + 1))
    return words
end

function mod.toboolean(s)
    if s == "true" then
        return true
    elseif s == "false" then
        return false
    else
        error(string.format("can't convert %s", s))
    end
end

function mod.rpcify(class)
    local MyClassRPC = {}

    local in_pipe = Pipe.new()
    local out_pipe = Pipe.new()

    function gen(attr, ...)
        function f(inst, ...)
            --for k, v in pairs(...) do
            --    print(k, v)
            --end
            Pipe.write(in_pipe, mod.serialize(attr))
            Pipe.read(out_pipe)
            Pipe.write(in_pipe, mod.serialize(...))
            return mod.deserialize(Pipe.read(out_pipe))
        end
        return f
    end

    function gen_async(attr, ...)
        function f_async(inst, ...)
            function get()
                return mod.deserialize(Pipe.read(out_pipe))
            end
            Pipe.write(in_pipe, mod.serialize(attr))
            Pipe.read(out_pipe)
            Pipe.write(in_pipe, mod.serialize(...))
            return get
        end
        return f_async
    end

    MyClassRPC["exit"] = gen("exit")
    for k, _ in pairs(class) do
        if k ~= "new" then
            MyClassRPC[k] = gen(k)
            MyClassRPC[string.format("%s_async", k)] = gen_async(k)
        end
    end


    function MyClassRPC.new()

        local pid = posix.fork()

        if pid == 0 then

            child()
        else

        end
        return
    end

    function child()
        local t = {
            counter = 0,
            tail = false,
            exit = function(self)
                self.tail = true
                return
            end
        }
        for k, v in pairs(class) do
            t[k] = v
        end
        while t.tail == false do
            cmd = mod.deserialize(Pipe.read(in_pipe))
            Pipe.write(out_pipe, "arg")
            arg = mod.deserialize(Pipe.read(in_pipe))
            ans = t[cmd](t, arg) or "nil"
            Pipe.write(out_pipe, mod.serialize(ans))
        end
    end

    return MyClassRPC
end
return mod

