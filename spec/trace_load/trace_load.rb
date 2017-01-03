# frozen_string_literal: true

require 'spec_helper'

describe 'running trace' do
  it "generates trace file" do
    content = <<~EOF
|| **CWD**%%DIRNAME%%
|| Compiling 1 file (.ex)
lib/fixture.ex|3 error| undefined function asd/0
EOF

    expect(<<~EOF).to be_trace_output("trace_line2", content)
defmodule A do
@moduledoc """
    A.test([1,2,3,4])
"""
  def test([]) do
    1
  end
  def test([h|t]) do
    [ h*2 | test(t) ]
  end

end

defmodule B do
  def run_trace() do
    :dbg.stop_clear
    :dbg.start

    port_fun = :dbg.trace_port(:file, 'trace')
    :dbg.tracer(:port, port_fun)

    #:dbg.p(:all, [:all])
    :dbg.tp A, [{:'_', [], [{:return_trace}]}]
    :dbg.p(:new_processes, [:c, :m])

    A.test([1,2,3,4])

    :dbg.trace_port_control(node(), :flush)
    :dbg.stop
    Process.sleep 500
  end
end
    EOF
  end
end
