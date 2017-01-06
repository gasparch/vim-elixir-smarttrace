
IO.puts "======== trace start ========"

:dbg.stop_clear
:dbg.start

port_fun = :dbg.trace_port(:file, '%%FILE%%')
:dbg.tracer(:port, port_fun)

alias Mix.Tasks.Compile.Elixir, as: E
import Mix.Compilers.Elixir, only: [read_manifest: 2, module: 1]

# start tracing for all modules in project
for manifest <- E.manifests(),
  module(module: mod_name) <- read_manifest(manifest, ""),
  do:
    :dbg.tpl mod_name, [{:'_', [], [{:return_trace}]}]

:dbg.p(:new_processes, [:c, :m])

# TODO: add waiting until CODE finishes execution and then only stop
# the tracer
spawn(fn() -> %%CODE%% end)

:dbg.trace_port_control(node(), :flush)
:dbg.stop
Process.sleep 1500

defmodule TraceReader do
  defstruct procmap: %{},     # map PIDs to letter A..Z
            proc_level: %{},  # track call/return depth in each processk
            prev_result: :no_results_defined  # use to collapse tail resucsion results

  #{:trace, #PID<0.275.0>, :call, {MapUtils, :deep_merge, [%{a: 123, b: %{c: 123}}, %{b: %{c: 123123}}]}}
  def read({:trace, pid, :call, {m, f, args}}, state) do
    {proc_name, state} = proc2name(pid, state)
    {level, state} = proc_change_level(pid, state, +1)
    state = %{state| prev_result: :no_results_defined}

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
  def read(:end_of_trace,state) do
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

  def init() do
    %__MODULE__{}
  end
end

:dbg.trace_client(:file, '%%FILE%%', {&TraceReader.read/2, TraceReader.init() })
Process.sleep 1500

IO.puts "======== trace stop ========"
