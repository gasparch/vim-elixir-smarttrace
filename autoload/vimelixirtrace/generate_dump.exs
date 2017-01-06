
test_spec = "%%TEST_SPEC%%"

:dbg.stop_clear
:dbg.start

port_fun = :dbg.trace_port(:file, '%%FILE%%')
:dbg.tracer(:port, port_fun)

is_running_test = (test_spec != "")

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
  spawn(fn() -> ExUnit.run() end)
else
  # TODO: add waiting until CODE finishes execution and then only stop
  # the tracer
  spawn(fn() -> %%CODE%% end)
  #%%CODE%%
end

Process.sleep 1500
:dbg.trace_port_control(node(), :flush)
:dbg.stop

defmodule TraceReader do
  defstruct skip_test_internals: false,
            procmap: %{},     # map PIDs to letter A..Z
            proc_level: %{},  # track call/return depth in each processk
            prev_result: :no_results_defined,  # use to collapse tail resucsion results
            prev_msg: :no_msg_defined

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

  def read({:trace, pid, :send, msg, to_pid}, state) do
    {proc_name, state} = proc2name(pid, state)
    {to_proc, state} = proc2name(to_pid, state)

    msg_view = inspect(msg, width: 70, pretty: true)

    if msg_view =~ ~R[\n] do
      first_line = msg_view |> String.split("\n") |> List.first()
      IO.puts "#{proc_name}->#{to_proc}: #{first_line}..."
      IO.puts ">msg\n" <> msg_view <> "\n<msg"
    else
      IO.puts "#{proc_name}->#{to_proc}: #{msg_view}"
    end

    state = %{state| prev_msg: msg}
    state = %{state| prev_result: :no_results_defined}
    state
  end
  def read({:trace, pid, :send_to_non_existing_process, msg, to_pid}, state) do
    {proc_name, state} = proc2name(pid, state)
    {to_proc, state} = proc2name(to_pid, state)

    msg_view = inspect(msg, width: 70, pretty: true)

    if msg_view =~ ~R[\n] do
      first_line = msg_view |> String.split("\n") |> List.first()
      IO.puts "#{proc_name}->☠#{to_proc}: #{first_line}..."
      IO.puts ">msg\n" <> msg_view <> "\n<msg"
    else
      IO.puts "#{proc_name}->☠#{to_proc}: #{msg_view}"
    end

    state = %{state| prev_msg: msg}
    state = %{state| prev_result: :no_results_defined}
    state
  end
  def read({:trace, pid, :receive, msg}, state) do
    {proc_name, state} = proc2name(pid, state)

    msg_view = if msg == state.prev_msg do
      " —″— "
    else
      inspect(msg, width: 70, pretty: true)
    end

    if msg_view =~ ~R[\n] do
      first_line = msg_view |> String.split("\n") |> List.first()
      IO.puts "->#{proc_name}: #{first_line}..."
      IO.puts ">msg\n" <> msg_view <> "\n<msg"
    else
      IO.puts "->#{proc_name}: #{msg_view}"
    end

    state = %{state| prev_msg: msg}
    state = %{state| prev_result: :no_results_defined}
    state
  end

  def read({:trace, pid, :call, {m, f, args}}, state) do
    {proc_name, state} = proc2name(pid, state)
    {level, state} = proc_change_level(pid, state, +1)
    state = %{state| prev_result: :no_results_defined}
    state = %{state| prev_msg: :no_msg_defined}

    args_view = args |> Enum.map(&inspect(&1, width: 70, pretty: true))
                |> Enum.join("❟ ")

    arity = length(args)

    if args_view =~ ~R[\n] do
      first_line = args_view |> String.split("\n") |> List.first()
      IO.puts "#{proc_name}:#{level}: call #{inspect(m)}:#{f}/#{arity} (#{first_line} ...)"
      IO.puts ">args\n" <> args_view <> "\n<args"
    else
      IO.puts "#{proc_name}:#{level}: call #{inspect(m)}:#{f}/#{arity} (#{args_view})"
    end

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
      result_view = inspect(result, width: 70, pretty: true)
      {result_view, %{state| prev_result: result}}
    end

    if result_view =~ ~R[\n] do
      first_line = result_view |> String.split("\n") |> List.first()
      IO.puts "#{proc_name}:#{level}: ret  #{inspect(m)}:#{f}/#{arity} -> #{first_line}..."
      IO.puts ">results\n" <> result_view <> "\n<results"
    else
      IO.puts "#{proc_name}:#{level}: ret  #{inspect(m)}:#{f}/#{arity} -> #{result_view}"
    end

    {_, state} = proc_change_level(pid, state, -1)
    state
  end

#{:trace, #PID<0.228.0>, :send, {:code_call, #PID<0.228.0>, {:ensure_loaded, ExUnit.EventManager}}, :code_server}
#{:trace, #PID<0.228.0>, :receive, {:code_server, {:module, ExUnit.EventManager}}}

  def read(:end_of_trace,state) do
    IO.puts "======== trace stop ========"
    state
  end
  def read(x,state) do
    IO.inspect x, limit: 10000, pretty: true, width: 140
    state
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

  def init(do_skip) do
    %__MODULE__{skip_test_internals: do_skip}
  end
end

IO.puts "======== trace start ========"
:dbg.trace_client(:file, '%%FILE%%', {&TraceReader.read/2, TraceReader.init(is_running_test) })
Process.sleep 1500
