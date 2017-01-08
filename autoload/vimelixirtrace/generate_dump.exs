
test_spec = "%%TEST_SPEC%%"
is_running_test = (test_spec != "")
trace_gen_timeout = 20_000

defmodule TraceRunner do
  # 20 sec should be enough for most tests to finish
  @run_timeout 20_000

  def run(is_running_test, test_spec) do
    :dbg.stop_clear
    :dbg.start

    port_fun = :dbg.trace_port(:file, '%%FILE%%')
    :dbg.tracer(:port, port_fun)

    if is_running_test do
      ExUnit.start autorun: false, trace: true, formatters: []
      single_file = test_spec
      {single_file, opts} = ExUnit.Filters.parse_path(single_file)
      ExUnit.configure(opts)
      Code.require_file(single_file)
      ExUnit.Server.cases_loaded()

      # manually add tracing of test runner so that
      # we can find exact call which started test execution
      # and executed AFTER test execution
        # so that the run log will be clean from ExUnit internal messages
        :dbg.tpl ExUnit.Runner, [{:'_', [], [{:return_trace}]}]
    end

    alias Mix.Tasks.Compile.Elixir, as: E
    import Mix.Compilers.Elixir, only: [read_manifest: 2, module: 1]

    # start tracing for all modules in project
    for manifest <- E.manifests(),
    module(module: mod_name) <- read_manifest(manifest, ""),
    do:
    :dbg.tpl mod_name, [{:'_', [], [{:return_trace}]}]

    :dbg.p(:new_processes, [:c, :m])

    if is_running_test do
      runner(fn() -> ExUnit.run() end)
    else
      # TODO: add waiting until CODE finishes execution and then only stop
      # the tracer
      runner(fn() ->
        %%CODE%%
      end)
    end

    :dbg.trace_port_control(node(), :flush)
    :dbg.stop
  end

  def runner(fun) do
    Process.flag(:trap_exit, true)

    pid = spawn_link(fun)

    receive do
      {:EXIT, _, _} -> :ok
    after
      @run_timeout ->
        Process.exit(pid, :kill)
        :not_ok
    end
  end
end




defmodule TraceReader do
  defstruct skip_test_internals: false,
            procmap: %{},     # map PIDs to letter A..Z
            proc_level: %{},  # track call/return depth in each processk
            prev_result: :no_results_defined,  # use to collapse tail resucsion results
            prev_msg: :no_msg_defined,
            prev_receiver: :no_msg_defined,
            seen_modules: %{},
            notify_pid: nil

  #{:trace, #PID<0.275.0>, :call, {MapUtils, :deep_merge, [%{a: 123, b: %{c: 123}}, %{b: %{c: 123123}}]}}
  def read({:trace, _, :return_from, {ExUnit.Runner, :exec_test, _}, _}, %{skip_test_internals: false}=state) do
    # return from exec_test triggers skip mode
    %{state | skip_test_internals: true}
  end

  def read({:trace, _, :call, {ExUnit.Runner, :exec_test, _}}, %{skip_test_internals: true}=state) do
    # running exec_test stops skip mode
    %{state | skip_test_internals: false}
  end

  # while skip_test_internals is true - skip all trace messages
  def read({:trace, _, :call, _}, %{skip_test_internals: true}=state) do
    state
  end
  def read({:trace, _, :return_from, _, _}, %{skip_test_internals: true}=state) do
    state
  end
  def read({:trace, _, :send, _, _}, %{skip_test_internals: true}=state) do
    state
  end
  def read({:trace, _, :receive, _}, %{skip_test_internals: true}=state) do
    state
  end

  # part when test started and we show messages from test processes
  # GenServer processing
  def read({:trace, pid, :send, {:"$gen_call", _, msg} = full_msg, to_pid}, state) do
    {proc_name, state} = proc2name(pid, state)
    {to_proc, state} = proc2name(to_pid, state)

    msg_view = my_inspect(state, msg, width: 70, pretty: true)

    prefix = "#{proc_name}→#{to_proc}: GenServer.call (\"ꜝ#{to_proc}\"❟"
    print_call(prefix, msg_view, "", ")")

    state = %{state| prev_msg: full_msg, prev_receiver: to_pid}
    state = %{state| prev_result: :no_results_defined}
    state
  end
  def read({:trace, pid, :call, {m, f, args}}, state) when f == :handle_call do
    state = add_seen_module(m, state)
    {proc_name, state} = proc2name(pid, state)
    {level, state} = proc_change_level(pid, state, +1)
    state = %{state| prev_result: :no_results_defined}
    state = %{state| prev_msg: :no_msg_defined}

    args_view = args |> Enum.map(&my_inspect(state, &1, width: 70, pretty: true))
                |> Enum.join("❟,❟ ")

    arity = length(args)

    prefix = "#{proc_name}:#{level}: #{f} #{my_inspect(state, m)}"
    print_call(prefix, args_view, "(", ")")

    state
  end
  def read({:trace, pid, :return_from, {m, f, arity}, result}, state) when
    f == :handle_call do
    state = %{state| prev_msg: {:ignore_reference, elem(result, 1)}}

    {proc_name, state} = proc2name(pid, state)
    # nil if no calls to this process yet, should never occur
    level = state.proc_level[pid]

    {result_view, state} = if result == state.prev_result do
      {" —″— ", state}
    else
      result_view = my_inspect(state, result, width: 70, pretty: true)
      {result_view, %{state| prev_result: result}}
    end

    prefix = "#{proc_name}:#{level}: ⤶#{f} #{my_inspect(state, m)}"
    print_call(prefix, result_view)

    {_, state} = proc_change_level(pid, state, -1)
    state
  end
  def read({:trace, _, :send, {ref, res}, _},
          %{prev_msg: {:ignore_reference, res1}} = state) when is_reference(ref) and res == res1 do
    state
  end
  def read({:trace, _, :receive, {ref, res}},
          %{prev_msg: {:ignore_reference, res1}} = state) when is_reference(ref) and res == res1 do
    state = %{state| prev_msg: :no_msg_defined}
    state
  end


  # generic messages/calls
  def read({:trace, pid, :send, msg, to_pid}, state) do
    {proc_name, state} = proc2name(pid, state)
    {to_proc, state} = proc2name(to_pid, state)

    msg_view = my_inspect(state, msg, width: 70, pretty: true)

    prefix = "#{proc_name}→#{to_proc}:"
    print_call(prefix, msg_view)

    state = %{state| prev_msg: msg, prev_receiver: to_pid}
    state = %{state| prev_result: :no_results_defined}
    state
  end
  def read({:trace, pid, :send_to_non_existing_process, msg, to_pid}, state) do
    {proc_name, state} = proc2name(pid, state)
    {to_proc, state} = proc2name(to_pid, state)

    msg_view = my_inspect(state, msg, width: 70, pretty: true)

    prefix = "#{proc_name}→☠#{to_proc}:"
    print_call(prefix, msg_view)

    state = %{state| prev_msg: :no_msg_defined}
    state = %{state| prev_result: :no_results_defined}
    state
  end
  def read({:trace, pid, :receive, msg}, %{prev_receiver: pid, prev_msg: msg}=state) do
    # do not show receive of message, which we just showed we sent
    state
  end
  def read({:trace, pid, :receive, msg}, state) do
    {proc_name, state} = proc2name(pid, state)

    msg_view = if msg == state.prev_msg do
      " —″— "
    else
      my_inspect(state, msg, width: 70, pretty: true)
    end

    prefix = "#{proc_name}←:"
    print_call(prefix, msg_view)

    state = %{state| prev_msg: msg}
    state = %{state| prev_result: :no_results_defined}
    state
  end

  def read({:trace, pid, :call, {m, f, args}}, state) do
    state = add_seen_module(m, state)
    {proc_name, state} = proc2name(pid, state)
    {level, state} = proc_change_level(pid, state, +1)
    state = %{state| prev_result: :no_results_defined}
    state = %{state| prev_msg: :no_msg_defined}

    args_view = args |> Enum.map(&my_inspect(state, &1, width: 70, pretty: true))
                |> Enum.join("❟,❟ ")

    arity = length(args)

    prefix = "#{proc_name}:#{level}: call #{my_inspect(state, m)}:#{f}/#{arity}"
    print_call(prefix, args_view, "(", ")")

    state
  end

  #{:trace, #PID<0.275.0>, :return_from, {MapUtils, :deep_resolve, 3}, 123123}
  def read({:trace, pid, :return_from, {m, f, arity}, result}, state) do
    state = %{state| prev_msg: :no_msg_defined}

    {proc_name, state} = proc2name(pid, state)
    # nil if no calls to this process yet, should never occur
    level = state.proc_level[pid]

    {result_view, state} = if result == state.prev_result do
      {" —″— ", state}
    else
      result_view = my_inspect(state, result, width: 70, pretty: true)
      {result_view, %{state| prev_result: result}}
    end

    prefix = "#{proc_name}:#{level}: ret  #{my_inspect(state, m)}:#{f}/#{arity} ⤶"
    print_call(prefix, result_view)

    {_, state} = proc_change_level(pid, state, -1)
    state
  end

#{:trace, #PID<0.228.0>, :send, {:code_call, #PID<0.228.0>, {:ensure_loaded, ExUnit.EventManager}}, :code_server}
#{:trace, #PID<0.228.0>, :receive, {:code_server, {:module, ExUnit.EventManager}}}

  def read(:end_of_trace, state) do
    module_paths = :code.all_loaded |> Enum.into(%{}) |> Map.take(Map.keys(state.seen_modules))

    IO.puts "======== trace stop ========"
    Enum.each(module_paths, fn({mod,filename}) ->
      lines = LineDecoder.get_translated_lines(filename)
      src_filename = mod.module_info(:compile)[:source]

      Enum.each(lines, fn({{fun_name, fun_arity}, line}) ->
        if line > -1 do
          IO.puts "#{mod}:#{fun_name}:#{fun_arity}:#{line}:#{src_filename}"
        end
      end)
    end)
    IO.puts "======== module lines ========"


    send state.notify_pid, :ok
    state
  end
  def read(x,state) do
    IO.inspect x, limit: 10000, pretty: true, width: 140
    state
  end

  defp print_call(prefix, args_view, open_brace\\"", close_brace\\"") do
    if args_view =~ ~R[\n] do
      split_lines = "#{open_brace}#{args_view}" |> String.split("\n")
      first_line = List.first(split_lines)
      split_lines = split_lines |> Enum.map(&"    #{&1}") |> Enum.join("\n")
      IO.puts "#{prefix} #{first_line}… «⋯"
      IO.puts "#{split_lines}#{close_brace} ⋯»"
    else
      IO.puts "#{prefix} #{open_brace}#{args_view}#{close_brace}"
    end
  end

  def proc2name(pid, state) do
    if Map.has_key?(state.procmap, pid) do
      {state.procmap[pid], state}
    else
      proc_number = "#{[map_size(state.procmap) + ?A]}"
      procmap = Map.put state.procmap, pid, proc_number
      {proc_number, %{state| procmap: procmap}}
    end
  end

  def proc_change_level(pid, state, increment) do
    state = %{state| proc_level: Map.update(state.proc_level, pid, 0, &(&1 + increment))}
    {state.proc_level[pid], state}
  end

  defp add_seen_module(mod, state) do
    %{state| seen_modules: Map.put(state.seen_modules, mod, 1)}
  end

  defp my_inspect(state, msg, options\\[]) do
    inspect(replace_pids(msg, state), options)
  end

  defp replace_pids({k,v}=val, state) when is_pid(v) do
    case state.procmap do
      %{^v => name} -> {k, "ꜝ#{name}"}
      _ -> val
    end
  end
  defp replace_pids(v, state) when is_pid(v) do
    case state.procmap do
      %{^v => name} -> "ꜝ#{name}"
      _ -> v
    end
  end
  defp replace_pids(%{__struct__: type} = msg, state) do
    msg
    |> Map.delete(:__struct__)
    |> Enum.map(&replace_pids(&1, state))
    |> Enum.into(%{})
    |> Map.put(:__struct__, type)
  end
  defp replace_pids(msg, state) when is_map(msg) do
    msg |> Enum.map(&replace_pids(&1, state)) |> Enum.into(%{})
  end
  defp replace_pids(msg, state) when is_list(msg) do
    msg |> Enum.map(&replace_pids(&1, state))
  end
  defp replace_pids(msg, state) when is_tuple(msg) do
    msg |> Tuple.to_list |> Enum.map(&replace_pids(&1, state)) |> List.to_tuple
  end
  defp replace_pids(val, _) do
    val
  end

  def init(do_skip, notify_pid) do
    %__MODULE__{skip_test_internals: do_skip, notify_pid: notify_pid}
  end
end

defmodule LineDecoder do
  use Bitwise

  @tag_i 1
  @tag_a 2

  # main entry point to module
  def get_translated_lines(filename) do
    lines_hash = get_lines_to_real_lines(filename) |> Enum.into(%{})

    fun_starts = get_disassembly(filename)

    fun_starts |> Enum.map(fn({fun, ln}) -> {fun, lines_hash[ln]} end)
  end

  def get_lines_to_real_lines(filename) do
    z = :beam_lib.chunks(filename, ['Line'])
    {_, {_, [{_, bin}]}} = z

    <<_ver::integer-size(32),_bits::integer-size(32),_numLineInstrs::integer-size(32),numLines::integer-size(32),_numFnames::integer-size(32), tail::binary>> = bin

    #IO.inspect {ver, bits, numLineInstrs, numLines, numFnames}

    tail = :erlang.binary_to_list(tail)

    lst = decode_lines_chunk(tail, numLines+1)
    lst = Enum.map(lst, fn
                     ({:a, _}) -> -1
                     ({:i, n}) -> n
    end)

    range = 0..(length(lst))
    Enum.zip(range, lst)
  end

  def get_disassembly(filename) do
    {:beam_file, _, _, _, _, funs} = :beam_disasm.file(filename)

    funs = Enum.map(funs, &get_line_reference/1)

    funs
  end

  defp get_line_reference({:function, fname, arity, _, ops}) do
    ops = (for {:line, _} = x <- ops, do: elem(x, 1)) |> List.first
    {{fname, arity}, ops}
  end

  defp decode_lines_chunk(tail, num) do
    decode_lines_chunk(tail, num, [])
  end

  defp decode_lines_chunk(_, 0, acc) do
    Enum.reverse(acc)
  end

  # modelled after OTP/lib/compiler/src/beam_disasm.erl
  defp decode_lines_chunk([b|bs0], num, acc) do
    tag = decode_tag(b &&& 0b111)

    {{type, val}, tail} = case tag do
      :a ->
      case decode_int(tag, b, bs0) do
        {{:a, 0}, tail} -> {nil, tail}
        {{:a, _}, tail} -> {{:a, :ignored_atom}, tail}
      end
      :i ->
        decode_int(tag, b, bs0)
    end
    decode_lines_chunk(tail, num-1, [{type, val} | acc])
  end

  defp decode_tag(@tag_i), do: :i
  defp decode_tag(@tag_a), do: :a
  defp decode_tag(v), do: raise "Do not support tag #{v}"

  defp decode_int(tag,b,bs) when (b &&& 0x08) === 0 do
    # -----------------------------------------------------------------------
    #  Decodes an integer value.  Handles positives, negatives, and bignums.
    #
    #  Tries to do the opposite of:
    #    beam_asm:encode(1, 5) =            [81]
    #    beam_asm:encode(1, 1000) =         [105,232]
    #    beam_asm:encode(1, 2047) =         [233,255]
    #    beam_asm:encode(1, 2048) =         [25,8,0]
    #    beam_asm:encode(1,-1) =            [25,255,255]
    #    beam_asm:encode(1,-4294967295) =   [121,255,0,0,0,1]
    #    beam_asm:encode(1, 4294967295) =   [121,0,255,255,255,255]
    #    beam_asm:encode(1, 429496729501) = [121,99,255,255,255,157]
    # -----------------------------------------------------------------------
    #%% N < 16 = 4 bits, NNNN:0:TTT
    n = b >>> 4
    {{tag,n},bs}
  end
  defp decode_int(tag,b,bs) when (b &&& 0x10) === 0 do
    #%% N < 2048 = 11 bits = 3:8 bits, NNN:01:TTT, NNNNNNNN
    [b1|bs1] = bs
    val0 = b &&& 0b11100000
    n = (val0 <<< 3) ||| b1
    {{tag,n},bs1}
  end
  defp decode_int(tag,b,bs) do
    {len,bs1} = decode_int_length(b,bs)
    {intBs,remBs} = take_bytes(len,bs1)
    n = build_arg(intBs)
    [f|_] = intBs
    num = if f > 127 && tag == :i do
      decode_negative(n, len)
    else
      n
    end
    {{tag,num},remBs}
  end

  # cut very bignum support from here
  defp decode_int_length(b, bs) do
    #%% The following imitates get_erlang_integer() in beam_load.c
    #%% Len is the size of the integer value in bytes
    case b >>> 5 do
      7 ->
        raise "decode_int, too_big bignum_sublength"
      l ->
        {l+2,bs}
    end
  end

  defp take_bytes(n, bs) do
    take_bytes(n, bs, [])
  end

  defp take_bytes(n, [b|bs], acc) when n > 0 do
    take_bytes(n-1, bs, [b|acc])
  end
  defp take_bytes(0, bs, acc) do
    {:lists.reverse(acc), bs}
  end

  defp build_arg(bs) do
    build_arg(bs, 0)
  end
  defp build_arg([b|bs], n) do
    build_arg(bs, (n <<< 8) ||| b);
  end
  defp build_arg([], n) do
    n
  end

  defp decode_negative(n, len) do
    n - (1 <<< (len*8)) # 8 is number of bits in a byte
  end
end

TraceRunner.run(is_running_test, test_spec)

IO.puts "======== trace start ========"
my_pid = self()
:dbg.trace_client(:file, '%%FILE%%', {&TraceReader.read/2, TraceReader.init(is_running_test, my_pid) })

receive do
  :ok -> :ok
after
  trace_gen_timeout ->
    IO.puts "======== trace stop ========"
    IO.puts "======== module lines ========"
end
