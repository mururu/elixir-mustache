defmodule Mustache.Compiler do
  import Kernel, except: [to_binary: 1]

  def compile(source, options) do
    line = options[:line] || 1
    tokens = Mustache.Tokenizer.tokenize(source, line)

    partials = options[:partials] || []

    partials = Enum.map partials, fn({ k, partial }) -> { k, Mustache.Tokenizer.tokenize(partial, line) } end

    { [], buffer, inner_vars } = generate_buffer(tokens, "", [], partials, :mustache_root, :mustache_root, false)

    handle_expr(buffer, :mustache, inner_vars)
  end

  ## private

  defp generate_buffer([{ :text, _line, text } | t], buffer, vars, partials, parent, root_parent, dot_flg) do
    buffer = handle_text(buffer, text)

    generate_buffer(t, buffer, vars, partials, parent, root_parent, dot_flg)
  end

  defp generate_buffer([{ :unescaped_variable, line, atom } | t], buffer, vars, partials, parent, root_parent, dot_flg) do
    var = { atom, [line: line], nil }
    buffer = handle_unescaped_variable(buffer, var)

    generate_buffer(t, buffer, [atom|vars], partials, parent, root_parent, dot_flg)
  end

  defp generate_buffer([{ :section, _line, atom } | t], buffer, vars, partials, parent, root_parent, dot_flg) do
    { rest, expr, inner_vars, inner_dot_flg } = generate_buffer(t, "", [], partials, atom, root_parent, false)

    inner_vars = Enum.uniq(inner_vars)

    new_buffer =
      if inner_dot_flg do
        if length(inner_vars) > 1 do
          raise(SyntaxError, description: "dot and other cannot be together")
        else
          handle_expr_including_dot(expr, atom)
        end
      else
        handle_expr(expr, atom, inner_vars)
      end

    buffer = handle_text(buffer, new_buffer)

    generate_buffer(rest, buffer, [atom|vars], partials, parent, root_parent, dot_flg)
  end

  defp generate_buffer([{ :inverted_section, _line, atom } | t], buffer, vars, partials, parent, root_parent, dot_flg) do
    { rest, expr, inner_vars, inner_dot_flg } = generate_buffer(t, "", [], partials, atom, root_parent, false)

    inner_vars = Enum.uniq(inner_vars)

    new_buffer =
      if inner_dot_flg do
        if length(inner_vars) > 1 do
          raise(SyntaxError, description: "dot and other cannot be together")
        else
          handle_inverted_expr_including_dot(expr, atom)
        end
      else
        handle_inverted_expr(expr, atom, inner_vars)
  end

    buffer = handle_text(buffer, new_buffer)

    generate_buffer(rest, buffer, [atom|vars], partials, parent, root_parent, dot_flg)
  end

  defp generate_buffer([{ :end_section, _line, parent } | t], buffer, vars, _partials, parent, _root_parent, dot_flg) do
    { t, buffer, vars, dot_flg }
  end

  defp generate_buffer([{ :variable, line, atom } | t], buffer, vars, partials, parent, root_parent, dot_flg) do
    var = { atom, [line: line], nil }
    buffer = handle_variable(buffer, var)

    generate_buffer(t, buffer, [atom|vars], partials, parent, root_parent, dot_flg)
  end

  defp generate_buffer([{ :dot, _line, _atom } | _], _buffer, _partials, _vars, root_parent, root_parent, _dot_flg) do
    raise SyntaxError, description: "Top level dotted names is invalid"
  end

  defp generate_buffer([{ :dot, line, atom } | t], buffer, vars, partials, parent, root_parent, _dot_flg) do
    var = { atom, [line: line], nil }
    buffer = handle_variable(buffer, var)

    generate_buffer(t, buffer, [atom|vars], partials, parent, root_parent, true)
  end

  defp generate_buffer([{ :unescaped_dot, _line, _atom } | _], _buffer, _vars, _partials, root_parent, root_parent, _dot_flg) do
    raise SyntaxError, description: "Top level dotted names is invalid"
  end

  defp generate_buffer([{ :unescaped_dot, line, atom } | t], buffer, vars, partials, parent, root_parent, _dot_flg) do
    var = { atom, [line: line], nil }
    buffer = handle_unescaped_variable(buffer, var)

    generate_buffer(t, buffer, [atom|vars], partials, parent, root_parent, true)
  end

  defp generate_buffer([{ :dotted_name, line, [atom|atoms] } | t], buffer, vars, partials, parent, root_parent, dot_flg) do
    var = { atom, [line: line], nil }
    buffer = handle_dotted_name(buffer, var, atoms)

    generate_buffer(t, buffer, [atom|vars], partials, parent, root_parent, dot_flg)
  end

  defp generate_buffer([{ :unescaped_dotted_name, line, [atom|atoms] } | t], buffer, vars, partials, parent, root_parent, dot_flg) do
    var = { atom, [line: line], nil }
    buffer = handle_unescaped_dotted_name(buffer, var, atoms)

    generate_buffer(t, buffer, [atom|vars], partials, parent, root_parent, dot_flg)
  end

  defp generate_buffer([{ :dotted_name_section, _line, [atom|atoms] } | t], buffer, vars, partials, parent, root_parent, dot_flg) do
    { rest, expr, inner_vars, inner_dot_flg } = generate_buffer(t, "", [], partials, [atom|atoms], root_parent, false)

    inner_vars = Enum.uniq(inner_vars)

    new_buffer =
      if inner_dot_flg do
        if length(inner_vars) > 1 do
          raise(SyntaxError, description: "dot and other cannot be together")
        else
          handle_dotted_expr_including_dot(expr, atom, atoms)
      end
      else
        handle_dotted_expr(expr, atom, atoms, inner_vars)
      end

    buffer = handle_text(buffer, new_buffer)

    generate_buffer(rest, buffer, [atom|vars], partials, parent, root_parent, dot_flg)
  end

  defp generate_buffer([{ :dotted_name_inverted_section, _line, [atom|atoms] } | t], buffer, vars, partials, parent, root_parent, dot_flg) do
    { rest, expr, inner_vars, inner_dot_flg } = generate_buffer(t, "", [], partials, [atom|atoms], root_parent, false)

    inner_vars = Enum.uniq(inner_vars)

    new_buffer =
      if inner_dot_flg do
        if length(inner_vars) > 1 do
          raise(SyntaxError, description: "dot and other cannot be together")
        else
          handle_dotted_inverted_expr_including_dot(expr, atom, atoms)
        end
      else
        handle_dotted_inverted_expr(expr, atom, atoms, inner_vars)
      end

    buffer = handle_text(buffer, new_buffer)

    generate_buffer(rest, buffer, [atom|vars], partials, parent, root_parent, dot_flg)
  end

  defp generate_buffer([{ :partial, _line, atom } | t], buffer, vars, partials, parent, root_parent, dot_flg) do
    partial = partials[atom] || []

    Enum.each partial, fn(token) ->
      case token do
        { :partial, _, ^atom } -> raise SyntaxError, description: "Recursive partials is not supported"
        _ -> :ok
      end
    end

    generate_buffer(partial ++ t, buffer, vars, partials, parent, root_parent, dot_flg)
  end

  defp generate_buffer([], buffer, vars, _partials, root_parent, root_parent, _dot_flg) do
    { [], buffer, vars }
  end

  # handler

  defp handle_text(buffer, text) do
    quote do: unquote(buffer) <> unquote(text)
  end

  defp handle_variable(buffer, var) do
    quote do: unquote(buffer) <> Mustache.Compiler.escape_html(Mustache.Compiler.to_binary(unquote(var)))
  end

  defp handle_unescaped_variable(buffer, var) do
    quote do: unquote(buffer) <> to_binary(unquote(var))
  end

  def handle_dotted_name(buffer, var, atoms) do
    quote do
      buffer = unquote(buffer)
      adding = Mustache.Compiler.recur_access(unquote(var), unquote(atoms)) |> Mustache.Compiler.to_binary
      buffer <> adding
    end
  end

  def handle_unescaped_dotted_name(buffer, var, atoms) do
    quote do
      buffer = unquote(buffer)
      adding = Mustache.Compiler.recur_access(unquote(var), unquote(atoms))
        |> Mustache.Compiler.to_binary
        |> Mustache.Compiler.escape_html
      buffer <> adding
    end
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

  defp handle_expr_including_dot(expr, atom) do
    var = { atom, [], nil }
    real_vars = [{ :., [], nil}]
    fun = {:fn,[],[[do: {:->,[],[{[real_vars],[],expr}]}]]}
    quote do
      var = unquote(var)
      fun = unquote(fun)
      coll = Mustache.Compiler.to_coll_for_dot(var)
      Enum.map(coll, fun) |> Enum.join
    end
  end

  defp handle_inverted_expr_including_dot(_expr, _atom) do
    quote do: ""
  end

  # almost same handle_expr
  defp handle_dotted_expr(expr, atom, atoms, vars) do
    top_var = { atom, [], nil }
    real_vars = Enum.map vars, fn(atom) -> { atom, [], nil} end
    fun = {:fn,[],[[do: {:->,[],[{[real_vars],[],expr}]}]]}
    quote do
      var = Mustache.Compiler.recur_access_for_dotted(unquote(top_var), unquote(atoms))
      vars = unquote(vars)
      fun = unquote(fun)
      coll = Mustache.Compiler.to_coll(var, vars)
      Enum.map(coll, fun) |> Enum.join
    end
  end

  # almost same handle_expr
  defp handle_dotted_inverted_expr(expr, atom, atoms, vars) do
    top_var = { atom, [], nil }
    real_vars = Enum.map vars, fn(atom) -> { atom, [], nil} end
    fun = {:fn,[],[[do: {:->,[],[{[real_vars],[],expr}]}]]}
    quote do
      var = Mustache.Compiler.recur_access_for_dotted(unquote(top_var), unquote(atoms))
      vars = unquote(vars)
      fun = unquote(fun)
      coll = Mustache.Compiler.to_coll(var, vars)
      case coll do
        [] -> fun.(Mustache.Compiler.to_nilcoll(vars))
        _  -> ""
      end
    end
  end

  defp handle_dotted_expr_including_dot(expr, atom, atoms) do
    top_var = { atom, [], nil }
    real_vars = [{ :., [], nil}]
    fun = {:fn,[],[[do: {:->,[],[{[real_vars],[],expr}]}]]}
    quote do
      var = Mustache.Compiler.recur_access_for_dotted(unquote(top_var), unquote(atoms))
      fun = unquote(fun)
      coll = Mustache.Compiler.to_coll_for_dot(var)
      Enum.map(coll, fun) |> Enum.join
    end
  end

  defp handle_dotted_inverted_expr_including_dot(_expr, _atom, _atoms) do
    quote do: ""
  end

  # utils

  def to_coll(term, vars) when is_list(term) do
    cond do
      term == [] ->
        []
      is_keyword?(term) ->
       [Enum.map(vars, fn(x) -> term[x] end)]
      true ->
        Enum.map term, fn(elem) ->
          if is_keyword?(elem) do
            Enum.map(vars, fn(x) -> elem[x] end)
          else
            to_nilcoll(vars)
          end
        end
    end
  end

  def to_coll(term, _vars) when term == nil or term == false, do: []
  def to_coll(_term, vars), do: [to_nilcoll(vars)]

  def to_nilcoll(vars), do: List.duplicate(nil, length(vars))

  defp is_keyword?(list) when is_list(list), do: :lists.all(is_keyword_tuple?(&1), list)
  defp is_keyword?(_), do: false

  defp is_keyword_tuple?({ x, _ }) when is_atom(x), do: true
  defp is_keyword_tuple?(_), do: false

  def to_coll_for_dot(term) when is_list(term), do: Enum.map(term, [&1])
  def to_col_for_dot(term), do: [[term]]

  def to_binary(float) when is_float(float) do
    bin = round(float * 100000000000000) |> Kernel.to_binary
    { integer, decimal } = split_float(bin)
    Kernel.to_binary([integer, ".", decimal])
  end
  def to_binary(other), do: Kernel.to_binary(other)

  def recur_access(term, []), do: term
  def recur_access(term, [atom|t]) do
    if is_keyword?(term), do: recur_access(term[atom], t), else: []
  end

  def recur_access_for_dotted(term, []), do: term
  def recur_access_for_dotted(term, [atom|t]) do
    if is_keyword?(term), do: recur_access(term[atom], t), else: []
  end

  defp split_float(bin) do
    binary_to_list(bin)
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
