# sample working decoded of beam file. now incorporated into generate_dump.exs

defmodule LineDecoder do
  use Bitwise

  @tag_i 1
  @tag_a 2

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

  defp decode_int(tag,b,bs) when (b &&& 0x08) === 0 do
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

#IO.inspect LineDecoder.get_lines_to_real_lines('Elixir.Ets.DB.beam')
#IO.inspect LineDecoder.get_disassembly('Elixir.Ets.DB.beam')
IO.inspect LineDecoder.get_translated_lines('/home/nm/dev/betonerlang/FEEDIN/odds_feed/_build/dev/lib/odds_feed/ebin/Elixir.Ets.DB.beam')


# find beam for module
#for {m, _}=x <- :code.all_loaded(), m == Ets.DB, do: x



