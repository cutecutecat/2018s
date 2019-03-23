1. 结合对 [`lua.lua`](https://github.com/ustc-fopl/2018s/blob/master/code/lua.lua) 和 [`lua-repl.lua`](https://github.com/ustc-fopl/2018s/blob/master/code/lua-repl.lua) 的理解和运行，回答问题

   - 在 REPL 环境下运行 [`lua.lua`](https://github.com/ustc-fopl/2018s/blob/master/code/lua.lua) 会面临哪些问题？

     缩进规范，定义的变量在本次运行过程中会一直保留

   - [`lua.lua`](https://github.com/ustc-fopl/2018s/blob/master/code/lua.lua) 中使用了哪些你不熟悉的语言特性（列举 2 个），结合代码及其执行说明你的理解。

     setmetatable 设置对table的元表，用来增加操作，类似于c++中的操作符重载

     table中可以将函数作为值

   - 在 [`lua.lua`](https://github.com/ustc-fopl/2018s/blob/master/code/lua.lua#L298) 的Exercise 里, `fib[n]` 的时间复杂度如何? 如何改进? 请给出时间复杂度为 O(n) 的算法(用 Lua 写), 要求仍能够以 `fib[n]` 的形式调用.

     O(2^n)，改进时可以

     ```lua
     function fib(n)
         a = {}
         for i=1,n+1,1 do
             a[i] = i-1
         end
         for i=3,30,1 do
             a[i] = a[i-1]+a[i-2]
         end
         return a[n+1]
     end
     ```

2. 在 [Part 1, Serialization](https://github.com/ustc-fopl/2018s/blob/master/assign1/README.md#part-1-serialization), 你可能会试图写类似如下的代码

   ```
   str = ""
   for k, v in pairs(t) do
     str = str .. k .. v
   end
   ```

   请问这样的代码存在什么问题（分析时间复杂度)? 如何改进? 

   每个循环都需要进行一次字符串连接，复杂度O(n)，可用table.concat降低到O(1)

3. 在 [Part 2: RPC](https://github.com/ustc-fopl/2018s/blob/master/assign1/README.md#part-2-rpc), 你需要实现 `inst.k_async()` 函数, 虽然函数名字里有 async (异步), 但仍然是阻塞式的调用. 如果要改成非阻塞式, 应该怎么做?

   将read函数改为非阻塞式的