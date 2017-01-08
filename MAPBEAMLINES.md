# Mapping function names to positions in original source file.

The problem: trace and profile files contain function names which are not easily recognizable and confusing.

Like this: 

```erlang
1> beam_lib:chunks("Elixir.Ets.DB.beam", [labeled_locals]).
{ok,{'Elixir.Ets.DB',
        [{labeled_locals,
             [{'-stream/2-fun-0-',1,79},
              {'-stream/2-fun-1-',2,77},
              {'-stream/2-fun-2-',1,74},
              {'-stream/3-fun-0-',2,72},
              {'-stream/3-fun-1-',2,70},
              {'-stream/3-fun-2-',1,67},
              {stream_iterator,2,42},
              {stream_iterator_list,2,52}]}]}}
```

There is no ordinary way to understand which function is really which one in
source file. Last number is no way a line number, but a **label** used
internally in Erlang compiler.

Here is the way to find mapping.

## Finding line numbers for each function (exported and internal)

 1) We take beam file disassembly and check `{line, N}` attributes at function definitions. 
 2) We take `Line` section of beam file and decode it to array of numbers (which are positions in original source file).
 3) number **N** from first file gives us index in array from step 2. So we can use that map to translate function's `{line, N}` attributes to real line numers.
 999) PROFIT!




 

```
# beam file holds compiled form and abstract form.
# abstract form keeps mapping to source file names, but gives no mapping into fun names
# compiled form after disassembly can provide still mapping to original file line numbers
# 
# {line, 21} in beam\_disasm output is a index position in 'Line' section mapping 
# 

# Line section just holds array of numbers of lines in original file, nothing else.
# So looking up values from {line, 21} will give mapping to correct place in 
# source file.

# decode 'Line' section of beam file to map {lineNo, realFileLine}
# relevant function is beam_asm:build_line_table which serializes into 'Line' chunk
#



@glados ~...odds\_feed/ebin> erl
Erlang/OTP 19 [erts-8.2] [source] [64-bit] [smp:3:3] [async-threads:10] [hipe] [kernel-poll:false]

Eshell V8.2  (abort with ^G)
1> io:format("~p", [ beam\_disasm:file("Elixir.Ets.DB.beam") ]).
{beam\_file,'Elixir.Ets.DB',
    [{'\_\_info\_\_',1,2},
     {clear,1,7},
     {delete,2,9},
     {destroy,1,11},
     {get\_next\_key,1,13},
     {get\_next\_key,2,15},
     {get\_or\_false,2,17},
     {give\_away,2,22},
     {give\_away,3,24},
     {kinda\_transaction,2,26},
     {module\_info,0,63},
     {module\_info,1,65},
     {new,1,28},
     {new,2,30},
     {put,2,32},
     {put,3,34},
     {put,4,36},
     {stream,2,38},
     {stream,3,40}],
    [{vsn,[201428032978481918561351464100627788713]}],
    [{options,[debug\_info]},
     {version,"7.0.3"},
     {source,
         "/home/nm/dev/betonerlang/FEEDIN/odds\_feed/lib/storage/ets\_db.ex"}],
    [{function,'\_\_info\_\_',1,2,
         [{label,1},
          {line,0},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,'\_\_info\_\_'},1},
          {label,2},
          {test,is\_atom,{f,5},[{x,0}]},
          {select\_val,
              {x,0},
              {f,5},
              {list,[{atom,functions},{f,3},{atom,macros},{f,4}]}},
          {label,3},
          {move,
              {literal,
                  [{clear,1},
                   {delete,2},
                   {destroy,1},
                   {get\_next\_key,1},
                   {get\_next\_key,2},
                   {get\_or\_false,2},
                   {give\_away,2},
                   {give\_away,3},
                   {kinda\_transaction,2},
                   {new,1},
                   {new,2},
                   {put,2},
                   {put,3},
                   {put,4},
                   {stream,2},
                   {stream,3}]},
              {x,0}},
          return,
          {label,4},
          {move,nil,{x,0}},
          return,
          {label,5},
          {move,{x,0},{x,1}},
          {move,{atom,'Elixir.Ets.DB'},{x,0}},
          {line,0},
          {call\_ext\_only,2,{extfunc,erlang,get\_module\_info,2}}]},
     {function,clear,1,7,
         [{line,1},
          {label,6},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,clear},1},
          {label,7},
          {line,2},
          {call\_ext\_only,1,{extfunc,ets,delete\_all\_objects,1}}]},
     {function,delete,2,9,
         [{line,3},
          {label,8},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,delete},2},
          {label,9},
          {line,4},
          {call\_ext\_only,2,{extfunc,ets,delete,2}}]},
     {function,destroy,1,11,
         [{line,5},
          {label,10},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,destroy},1},
          {label,11},
          {line,6},
          {call\_ext\_only,1,{extfunc,ets,delete,1}}]},
     {function,get\_next\_key,1,13,
         [{line,7},
          {label,12},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,get\_next\_key},1},
          {label,13},
          {line,8},
          {call\_ext\_only,1,{extfunc,ets,first,1}}]},
     {function,get\_next\_key,2,15,
         [{line,9},
          {label,14},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,get\_next\_key},2},
          {label,15},
          {line,10},
          {call\_ext\_only,2,{extfunc,ets,next,2}}]},
     {function,get\_or\_false,2,17,
         [{line,11},
          {label,16},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,get\_or\_false},2},
          {label,17},
          {allocate,0,2},
          {line,12},
          {call\_ext,2,{extfunc,ets,lookup,2}},
          {test,is\_nonempty\_list,{f,19},[{x,0}]},
          {get\_list,{x,0},{x,1},{x,2}},
          {test,is\_tuple,{f,18},[{x,1}]},
          {test,test\_arity,{f,18},[{x,1},2]},
          {test,is\_nil,{f,20},[{x,2}]},
          {get\_tuple\_element,{x,1},1,{x,0}},
          {deallocate,0},
          return,
          {label,18},
          {test,is\_nil,{f,20},[{x,2}]},
          {test,is\_tuple,{f,20},[{x,1}]},
          {bif,tuple\_size,{f,20},[{x,1}],{x,3}},
          {test,is\_lt,{f,20},[{integer,2},{x,3}]},
          {move,{x,1},{x,0}},
          {deallocate,0},
          return,
          {label,19},
          {test,is\_nil,{f,20},[{x,0}]},
          {move,{atom,false},{x,0}},
          {deallocate,0},
          return,
          {label,20},
          {line,12},
          {case\_end,{x,0}}]},
     {function,give\_away,2,22,
         [{line,13},
          {label,21},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,give\_away},2},
          {label,22},
          {move,{atom,nil},{x,2}},
          {call\_only,3,{'Elixir.Ets.DB',give\_away,3}}]},
     {function,give\_away,3,24,
         [{line,13},
          {label,23},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,give\_away},3},
          {label,24},
          {line,14},
          {call\_ext\_only,3,{extfunc,ets,give\_away,3}}]},
     {function,kinda\_transaction,2,26,
         [{line,15},
          {label,25},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,kinda\_transaction},2},
          {label,26},
          {line,16},
          {call\_ext\_only,2,{extfunc,ets,safe\_fixtable,2}}]},
     {function,new,1,28,
         [{line,17},
          {label,27},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,new},1},
          {label,28},
          {move,{literal,[protected]},{x,1}},
          {call\_only,2,{'Elixir.Ets.DB',new,2}}]},
     {function,new,2,30,
         [{line,17},
          {label,29},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,new},2},
          {label,30},
          {test\_heap,2,2},
          {put\_list,{atom,set},{x,1},{x,1}},
          {line,18},
          {call\_ext\_only,2,{extfunc,ets,new,2}}]},
     {function,put,2,32,
         [{line,19},
          {label,31},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,put},2},
          {label,32},
          {test,is\_tuple,{f,31},[{x,1}]},
          {line,20},
          {call\_ext\_only,2,{extfunc,ets,insert,2}}]},
     {function,put,3,34,
         [{line,21},
          {label,33},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,put},3},
          {label,34},
          {test\_heap,3,3},
          {put\_tuple,2,{x,3}},
          {put,{x,1}},
          {put,{x,2}},
          {move,{x,3},{x,1}},
          {line,22},
          {call\_ext\_only,2,{extfunc,ets,insert,2}}]},
     {function,put,4,36,
         [{line,23},
          {label,35},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,put},4},
          {label,36},
          {test\_heap,4,4},
          {put\_tuple,3,{x,4}},
          {put,{x,1}},
          {put,{x,2}},
          {put,{x,3}},
          {move,{x,4},{x,1}},
          {line,24},
          {call\_ext\_only,2,{extfunc,ets,insert,2}}]},
     {function,stream,2,38,
         [{line,25},
          {label,37},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,stream},2},
          {label,38},
          {allocate\_zero,2,2},
          {move,{x,1},{y,1}},
          {make\_fun2,{'Elixir.Ets.DB','-stream/2-fun-0-',1},0,79449350,1},
          {move,{x,0},{x,1}},
          {move,{y,1},{x,0}},
          {move,{x,1},{y,1}},
          {make\_fun2,{'Elixir.Ets.DB','-stream/2-fun-1-',2},1,79449350,1},
          {move,{x,0},{y,0}},
          {make\_fun2,{'Elixir.Ets.DB','-stream/2-fun-2-',1},2,79449350,0},
          {move,{y,0},{x,1}},
          {move,{x,0},{x,2}},
          {move,{y,1},{x,0}},
          {line,26},
          {call\_ext\_last,3,{extfunc,'Elixir.Stream',resource,3},2}]},
     {function,stream,3,40,
         [{line,27},
          {label,39},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,stream},3},
          {label,40},
          {allocate\_zero,2,3},
          {move,{x,1},{x,3}},
          {move,{x,0},{x,1}},
          {move,{x,3},{x,0}},
          {move,{x,2},{y,1}},
          {make\_fun2,{'Elixir.Ets.DB','-stream/3-fun-0-',2},3,79449350,2},
          {move,{x,0},{x,1}},
          {move,{y,1},{x,0}},
          {move,{x,1},{y,1}},
          {make\_fun2,{'Elixir.Ets.DB','-stream/3-fun-1-',2},4,79449350,1},
          {move,{x,0},{y,0}},
          {make\_fun2,{'Elixir.Ets.DB','-stream/3-fun-2-',1},5,79449350,0},
          {move,{y,0},{x,1}},
          {move,{x,0},{x,2}},
          {move,{y,1},{x,0}},
          {line,28},
          {call\_ext\_last,3,{extfunc,'Elixir.Stream',resource,3},2}]},
     {function,stream\_iterator,2,42,
         [{line,29},
          {label,41},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,stream\_iterator},2},
          {label,42},
          {test,is\_tuple,{f,41},[{x,0}]},
          {test,test\_arity,{f,41},[{x,0},2]},
          {get\_tuple\_element,{x,0},0,{x,2}},
          {get\_tuple\_element,{x,0},1,{x,3}},
          {test,is\_eq\_exact,{f,43},[{x,3},{atom,'$end\_of\_table'}]},
          {test\_heap,3,3},
          {put\_tuple,2,{x,0}},
          {put,{atom,halt}},
          {put,{x,2}},
          return,
          {label,43},
          {allocate,4,4},
          {init,{y,0}},
          {move,{x,1},{y,2}},
          {move,{x,3},{x,1}},
          {move,{x,2},{x,0}},
          {move,{x,1},{y,1}},
          {move,{x,0},{y,3}},
          {line,30},
          {call,2,{'Elixir.Ets.DB',get\_or\_false,2}},
          {move,{x,0},{y,0}},
          {move,{y,1},{x,1}},
          {move,{y,3},{x,0}},
          {line,31},
          {call,2,{'Elixir.Ets.DB',get\_next\_key,2}},
          {test\_heap,3,1},
          {put\_tuple,2,{x,3}},
          {put,{y,3}},
          {put,{x,0}},
          {move,{y,0},{x,1}},
          {move,{y,2},{x,2}},
          {move,{y,1},{x,0}},
          {move,{x,3},{y,1}},
          {init,{y,0}},
          {line,32},
          {call\_fun,2},
          {test,is\_tuple,{f,47},[{x,0}]},
          {test,test\_arity,{f,50},[{x,0},2]},
          {get\_tuple\_element,{x,0},0,{x,1}},
          {get\_tuple\_element,{x,0},1,{x,2}},
          {test,is\_atom,{f,50},[{x,1}]},
          {select\_val,
              {x,1},
              {f,50},
              {list,
                  [{atom,cont\_list},
                   {f,44},
                   {atom,cont\_stream},
                   {f,45},
                   {atom,cont},
                   {f,46}]}},
          {label,44},
          {test,is\_list,{f,50},[{x,2}]},
          {test\_heap,3,3},
          {put\_tuple,2,{x,0}},
          {put,{x,2}},
          {put,{y,1}},
          {deallocate,4},
          return,
          {label,45},
          {test,is\_function,{f,50},[{x,2}]},
          {test\_heap,3,3},
          {put\_tuple,2,{x,0}},
          {put,{x,2}},
          {put,{y,1}},
          {deallocate,4},
          return,
          {label,46},
          {test\_heap,5,3},
          {put\_list,{x,2},nil,{x,1}},
          {put\_tuple,2,{x,0}},
          {put,{x,1}},
          {put,{y,1}},
          {deallocate,4},
          return,
          {label,47},
          {test,is\_atom,{f,50},[{x,0}]},
          {select\_val,
              {x,0},
              {f,50},
              {list,[{atom,halt},{f,48},{atom,skip},{f,49}]}},
          {label,48},
          {test\_heap,3,0},
          {put\_tuple,2,{x,0}},
          {put,{atom,halt}},
          {put,{y,3}},
          {deallocate,4},
          return,
          {label,49},
          {move,{y,2},{x,1}},
          {move,{y,1},{x,0}},
          {call\_last,2,{'Elixir.Ets.DB',stream\_iterator,2},4},
          {label,50},
          {line,32},
          {case\_end,{x,0}}]},
     {function,stream\_iterator\_list,2,52,
         [{line,33},
          {label,51},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,stream\_iterator\_list},2},
          {label,52},
          {test,is\_tuple,{f,51},[{x,0}]},
          {test,test\_arity,{f,51},[{x,0},2]},
          {get\_tuple\_element,{x,0},0,{x,2}},
          {get\_tuple\_element,{x,0},1,{x,3}},
          {test,is\_nonempty\_list,{f,60},[{x,3}]},
          {allocate,4,4},
          {get\_list,{x,3},{x,4},{y,0}},
          {move,{x,1},{y,1}},
          {move,{x,4},{x,1}},
          {move,{x,2},{x,0}},
          {move,{x,0},{y,2}},
          {move,{x,1},{y,3}},
          {line,34},
          {call,2,{'Elixir.Ets.DB',get\_or\_false,2}},
          {test\_heap,3,1},
          {put\_tuple,2,{x,1}},
          {put,{y,2}},
          {put,{y,0}},
          {test,is\_eq\_exact,{f,53},[{x,0},{atom,false}]},
          {move,{x,1},{x,0}},
          {move,{y,1},{x,1}},
          {call\_last,2,{'Elixir.Ets.DB',stream\_iterator\_list,2},4},
          {label,53},
          {move,{x,1},{x,3}},
          {move,{x,0},{x,1}},
          {move,{y,1},{x,2}},
          {move,{y,3},{x,0}},
          {move,{x,3},{y,3}},
          {init,{y,0}},
          {line,35},
          {call\_fun,2},
          {test,is\_tuple,{f,57},[{x,0}]},
          {test,test\_arity,{f,61},[{x,0},2]},
          {get\_tuple\_element,{x,0},0,{x,1}},
          {get\_tuple\_element,{x,0},1,{x,2}},
          {test,is\_atom,{f,61},[{x,1}]},
          {select\_val,
              {x,1},
              {f,61},
              {list,
                  [{atom,cont\_list},
                   {f,54},
                   {atom,cont\_stream},
                   {f,55},
                   {atom,cont},
                   {f,56}]}},
          {label,54},
          {test,is\_list,{f,61},[{x,2}]},
          {test\_heap,3,3},
          {put\_tuple,2,{x,0}},
          {put,{x,2}},
          {put,{y,3}},
          {deallocate,4},
          return,
          {label,55},
          {test,is\_function,{f,61},[{x,2}]},
          {test\_heap,3,3},
          {put\_tuple,2,{x,0}},
          {put,{x,2}},
          {put,{y,3}},
          {deallocate,4},
          return,
          {label,56},
          {test\_heap,5,3},
          {put\_list,{x,2},nil,{x,1}},
          {put\_tuple,2,{x,0}},
          {put,{x,1}},
          {put,{y,3}},
          {deallocate,4},
          return,
          {label,57},
          {test,is\_atom,{f,61},[{x,0}]},
          {select\_val,
              {x,0},
              {f,61},
              {list,[{atom,halt},{f,58},{atom,skip},{f,59}]}},
          {label,58},
          {test\_heap,3,0},
          {put\_tuple,2,{x,0}},
          {put,{atom,halt}},
          {put,{y,2}},
          {deallocate,4},
          return,
          {label,59},
          {move,{y,1},{x,1}},
          {move,{y,3},{x,0}},
          {call\_last,2,{'Elixir.Ets.DB',stream\_iterator\_list,2},4},
          {label,60},
          {test,is\_nil,{f,51},[{x,3}]},
          {test\_heap,3,3},
          {put\_tuple,2,{x,0}},
          {put,{atom,halt}},
          {put,{x,2}},
          return,
          {label,61},
          {line,35},
          {case\_end,{x,0}}]},
     {function,module\_info,0,63,
         [{line,0},
          {label,62},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,module\_info},0},
          {label,63},
          {move,{atom,'Elixir.Ets.DB'},{x,0}},
          {line,0},
          {call\_ext\_only,1,{extfunc,erlang,get\_module\_info,1}}]},
     {function,module\_info,1,65,
         [{line,0},
          {label,64},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,module\_info},1},
          {label,65},
          {move,{x,0},{x,1}},
          {move,{atom,'Elixir.Ets.DB'},{x,0}},
          {line,0},
          {call\_ext\_only,2,{extfunc,erlang,get\_module\_info,2}}]},
     {function,'-stream/3-fun-2-',1,67,
         [{line,36},
          {label,66},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,'-stream/3-fun-2-'},1},
          {label,67},
          {test,is\_tuple,{f,68},[{x,0}]},
          {test,test\_arity,{f,68},[{x,0},2]},
          {get\_tuple\_element,{x,0},0,{x,0}},
          {label,68},
          {move,{atom,false},{x,1}},
          {call\_only,2,{'Elixir.Ets.DB',kinda\_transaction,2}}]},
     {function,'-stream/3-fun-1-',2,70,
         [{line,37},
          {label,69},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,'-stream/3-fun-1-'},2},
          {label,70},
          {call\_only,2,{'Elixir.Ets.DB',stream\_iterator\_list,2}}]},
     {function,'-stream/3-fun-0-',2,72,
         [{line,38},
          {label,71},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,'-stream/3-fun-0-'},2},
          {label,72},
          {allocate,2,2},
          {move,{x,0},{y,0}},
          {move,{x,1},{x,0}},
          {move,{atom,true},{x,1}},
          {move,{x,0},{y,1}},
          {line,39},
          {call,2,{'Elixir.Ets.DB',kinda\_transaction,2}},
          {test\_heap,3,0},
          {put\_tuple,2,{x,0}},
          {put,{y,1}},
          {put,{y,0}},
          {deallocate,2},
          return]},
     {function,'-stream/2-fun-2-',1,74,
         [{line,40},
          {label,73},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,'-stream/2-fun-2-'},1},
          {label,74},
          {test,is\_tuple,{f,75},[{x,0}]},
          {test,test\_arity,{f,75},[{x,0},2]},
          {get\_tuple\_element,{x,0},0,{x,0}},
          {label,75},
          {move,{atom,false},{x,1}},
          {call\_only,2,{'Elixir.Ets.DB',kinda\_transaction,2}}]},
     {function,'-stream/2-fun-1-',2,77,
         [{line,41},
          {label,76},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,'-stream/2-fun-1-'},2},
          {label,77},
          {call\_only,2,{'Elixir.Ets.DB',stream\_iterator,2}}]},
     {function,'-stream/2-fun-0-',1,79,
         [{line,42},
          {label,78},
          {func\_info,{atom,'Elixir.Ets.DB'},{atom,'-stream/2-fun-0-'},1},
          {label,79},
          {allocate,1,1},
          {move,{atom,true},{x,1}},
          {move,{x,0},{y,0}},
          {line,43},
          {call,2,{'Elixir.Ets.DB',kinda\_transaction,2}},
          {move,{y,0},{x,0}},
          {line,44},
          {call,1,{'Elixir.Ets.DB',get\_next\_key,1}},
          {test\_heap,3,1},
          {put\_tuple,2,{x,1}},
          {put,{y,0}},
          {put,{x,0}},
          {move,{x,1},{x,0}},
          {deallocate,1},
          return]}]}ok
       
====== decode.exs =====
# decode 'Line' section of beam file to map {lineNo, realFileLine}

defmodule A do

  @tag\_i 1
  @tag\_a 2

  def run do
    z = :beam\_lib.chunks('Elixir.Ets.DB.beam', ['Line'])
    {\_, {\_, [{\_, bin}]}} = z


    <<ver::integer-size(32),bits::integer-size(32),numLineInstrs::integer-size(32),numLines::integer-size(32),numFnames::integer-size(32), tail::binary>> = bin

    IO.inspect {ver, bits, numLineInstrs, numLines, numFnames}
    IO.inspect tail

    #tail = String.split(tail, ~R[]) |> Enum.take(1) |> IO.iodata\_to\_binary()

    #IO.inspect :erlang.binary\_to\_term(tail)

    lst = decode\_to\_list(tail)
    range = 0..(length(lst))
    IO.inspect Enum.zip(range, lst)
  end

  def decode\_to\_list(bin), do: decode\_to\_list(bin, [])

  def decode\_to\_list(<<>>, acc) do
    acc
  end
  def decode\_to\_list(bin, acc) do
    <<\_::bits-size(4), tag::unsigned-integer-size(4), \_::binary>> = bin
    {value, bin\_tail} = decode\_tag(tag, bin)
    IO.inspect {tag, value}
    decode\_to\_list(bin\_tail, acc ++ [value])
  end

  def decode\_tag(@tag\_a, bin) do
    <<high::unsigned-integer-size(4), \_::bits-size(4), tail::binary>> = bin
    {high, tail}
  end

  #def decode\_tag(8+@tag\_a, bin) do
  #  <<high::unsigned-integer-size(4), \_::bits-size(4), tail::binary>> = bin
  #  {high, tail}
  #end
  
  def decode\_tag(@tag\_i, bin) do
    <<high::unsigned-integer-size(4), \_::bits-size(4), tail::binary>> = bin
    {high, tail}
  end

  def decode\_tag(8+@tag\_i, bin) do
    <<high::unsigned-integer-size(3), \_::bits-size(5), next\_byte::unsigned-integer-size(8), tail::binary>> = bin
    {high*256 + next\_byte, tail}
  end

  def decode\_tag(0, \_) do
    {nil, <<>>}
  end
end

A.run()
====== decode.exs =====


bash > elixir decode.exs 
[{0, 1}, {1, 6}, {2, 7}, {3, 10}, {4, 11}, {5, 14}, {6, 15}, {7, 44}, {8, 45},
 {9, 48}, {10, 49}, {11, 18}, {12, 19}, {13, 26}, {14, 27}, {15, 40}, {16, 41},
 {17, 2}, {18, 3}, {19, 30}, {20, 31}, {21, 33}, {22, 34}, {23, 36}, {24, 37},
 {25, 75}, {26, 76}, {27, 115}, {28, 116}, {29, 52}, {30, 56}, {31, 57},
 {32, 59}, {33, 91}, {34, 95}, {35, 102}, {36, 123}, {37, 121}, {38, 117},
 {39, 118}, {40, 82}, {41, 81}, {42, 77}, {43, 78}, {44, 79}, {45, nil}]
```

