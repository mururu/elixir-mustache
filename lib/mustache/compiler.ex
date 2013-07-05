defmodule Mustache.Compiler do
  def compile(source, options) do
    line = options[:line] || 1
    tokens = Mustache.Tokenizer.tokenize(source, line)

    { [], buffer, inner_vars } = generate_buffer(tokens, "", [], :mustache_root)

    handle_expr(buffer, :mustache, inner_vars)
  end

  ## private

  defp generate_buffer([{ :text, _line, text } | t], buffer, vars, parent) do
    buffer = handle_text(buffer, text)

    generate_buffer(t, buffer, vars, parent)
  end

  defp generate_buffer([{ :unescaped_variable, line, atom } | t], buffer, vars, parent) do
    var = { atom, [line: line], nil }
    buffer = handle_unescape_variable(buffer, var)

    generate_buffer(t, buffer, [atom|vars], parent)
  end

  defp generate_buffer([{ :section, _line, atom } | t], buffer, vars, parent) do
    { rest, expr, inner_vars } = generate_buffer(t, "", [], atom)

    new_buffer = handle_expr(expr, atom, inner_vars)
    buffer = handle_text(buffer, new_buffer)

    generate_buffer(rest, buffer, [atom|vars], parent)
  end

  defp generate_buffer([{ :inverted_section, _line, atom } | t], buffer, vars, parent) do
    { rest, expr, inner_vars } = generate_buffer(t, "", [], atom)

    new_buffer = handle_inverted_expr(expr, atom, inner_vars)
    buffer = handle_text(buffer, new_buffer)

    generate_buffer(rest, buffer, [atom|vars], parent)
  end

  defp generate_buffer([{ :end_section, _line, parent } | t], buffer, vars, parent) do
    { t, buffer, vars }
  end

  defp generate_buffer([{ :variable, line, atom } | t], buffer, vars, parent) do
    var = { atom, [line: line], nil }
    buffer = handle_variable(buffer, var)

    generate_buffer(t, buffer, [atom|vars], parent)
  end

  defp generate_buffer([], buffer, vars, :mustache_root) do
    { [], buffer, vars }
  end

  # handler

  defp handle_text(buffer, text) do
    quote do: unquote(buffer) <> unquote(text)
  end

  defp handle_variable(buffer, var) do
    quote do: unquote(buffer) <> Mustache.Compiler.escape_html(to_binary(unquote(var)))
  end

  defp handle_unescape_variable(buffer, var) do
    quote do: unquote(buffer) <> to_binary(unquote(var))
  end

  defp handle_expr(expr, atom, vars) do
    var = { atom, [], nil }
    real_vars = Enum.map vars, fn(atom) -> { atom, [], nil} end
    fun = {:fn,[],[[do: {:->,[],[{[real_vars],[],expr}]}]]}
    quote do
      var = unquote(var)
      vars = unquote(vars)
      fun = unquote(fun)
      coll = Mustache.Compiler.to_coll(var, vars)
      Enum.map(coll, fun) |> Enum.join
    end
  end

  defp handle_inverted_expr(expr, atom, vars) do
    var = { atom, [], nil }
    real_vars = Enum.map vars, fn(atom) -> { atom, [], nil} end
    fun = {:fn,[],[[do: {:->,[],[{[real_vars],[],expr}]}]]}
    quote do
      var = unquote(var)
      vars = unquote(vars)
      fun = unquote(fun)
      coll = Mustache.Compiler.to_coll(var, vars)
      case coll do
        [] -> fun.(Mustache.Compiler.to_nilcoll(vars))
        _  -> ""
      end
    end
  end

  # utils

  def to_coll(term, vars) when is_list(term) do
    Enum.map term, fn(elem) ->
      if is_keyword?(elem) do
        Enum.map(vars, fn(x) -> elem[x] end)
      else
        to_nilcoll(vars)
      end
    end
  end

  def to_coll(term, _vars) when term == nil or term == false, do: []
  def to_coll(_term, vars), do: [to_nilcoll(vars)]

  def to_nilcoll(vars), do: List.duplicate(nil, Enum.count(vars))

  defp is_keyword?(list) when is_list(list), do: :lists.all(is_keyword_tuple?(&1), list)
  defp is_keyword?(_), do: false

  defp is_keyword_tuple?({ x, _ }) when is_atom(x), do: true
  defp is_keyword_tuple?(_), do: false

  def escape_html(str) do
    escape_html(:unicode.characters_to_list(str), []) |> Enum.reverse |> to_binary
  end

  @table_for_escape_html [
    { '\'', '&#39;' },
    { '&',  '&amp;' },
    { '"',  '&quot;' },
    { '<',  '&lt;' },
    { '>',  '&gt;' },
  ]

  lc { k, v } inlist @table_for_escape_html do
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
