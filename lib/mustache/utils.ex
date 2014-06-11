defmodule Mustache.Utils do
  @moduledoc false

  import Kernel, except: [to_binary: 1]

  def to_coll(term, vars, bind) when is_list(term) do
    cond do
      term == [] ->
        []
      is_keyword?(term) ->
       [Enum.map(vars, fn(x) -> term[x] || bind[x] end)]
      true ->
        Enum.map term, fn(elem) ->
          if is_keyword?(elem) do
            Enum.map(vars, fn(x) -> elem[x] || bind[x] end)
          else
            to_nilcoll(vars, bind)
          end
        end
    end
  end

  def to_coll(term, _vars, _bind) when term == nil or term == false, do: []
  def to_coll(_term, vars, bind), do: [to_nilcoll(vars, bind)]

  def to_nilcoll(vars, bind), do: Enum.map(vars, &bind[&1])

  def to_coll_for_dot(term) when is_list(term), do: Enum.map(term, &[&1])
  def to_coll_for_dot(term), do: [[term]]

  defp is_keyword?(list) when is_list(list), do: :lists.all(&is_keyword_tuple?(&1), list)
  defp is_keyword?(_), do: false

  defp is_keyword_tuple?({ x, _ }) when is_atom(x), do: true
  defp is_keyword_tuple?(_), do: false

  def to_binary(float) when is_float(float) do
    bin = round(float * 100000000000000) |> Kernel.to_string
    { integer, decimal } = split_float(bin)
    Kernel.to_string([integer, ".", decimal])
  end
  def to_binary(other), do: Kernel.to_string(other)

  defp split_float(bin) do
    String.to_char_list!(bin)
    |> :lists.reverse
    |> split_float(0, '')
  end

  defp split_float(list, 14, '') do
    { :lists.reverse(list), '0' }
  end

  defp split_float(list, 14, acc) do
    { :lists.reverse(list), acc }
  end

  defp split_float([?0|t], i, acc) do
    split_float(t, i + 1, acc)
  end

  defp split_float([h|t], i, acc) do
    split_float(t, i + 1, [h|acc])
  end

  def recur_access(term, []), do: term
  def recur_access(term, [atom|t]) do
    if is_keyword?(term), do: recur_access(term[atom], t), else: []
  end

  def recur_access_for_dotted(term, []), do: term
  def recur_access_for_dotted(term, [atom|t]) do
    if is_keyword?(term), do: recur_access(term[atom], t), else: []
  end

  def escape_html(str) do
    escape_html(:unicode.characters_to_list(str), [])
    |> Enum.reverse
    |> to_binary
  end

  @table_for_escape_html [
    { '\'', '&#39;' },
    { '&',  '&amp;' },
    { '"',  '&quot;' },
    { '<',  '&lt;' },
    { '>',  '&gt;' },
  ]

  for { k, v } <- @table_for_escape_html do
    defp escape_html(unquote(k) ++ t, acc) do
      escape_html(t, unquote(Enum.reverse(v)) ++ acc)
    end
  end

  defp escape_html([h|t], acc) do
    escape_html(t, [h|acc])
  end

  defp escape_html([], acc) do
    acc
  end
end
