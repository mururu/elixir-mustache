defmodule Mustache.Tokenizer do

  @doc """
  { :text,  line, contents :: binary }
  { :unescaped_variable,   line, contents :: atom }
  { :section,  line, contents :: atom }
  { :inverted_section,   line, contents :: atom }
  { :end_section, line, contents :: atom }
  { :variable,   line, contents :: atom }
  { :dot, line, contents :: atom}
  { :unescaped_dot, line, contents :: atom }
  { :dotted_name, line, contents :: [atom..] }
  { :unescaped_dotted_name, line, contents :: [atom..] }
  { :dotted_name_section, line, contents :: [atom..] }
  { :dotted_name_inverted_section, line, contents :: [atom..] }
  { :partial, line, contents :: contents :: atom }
  """
  def tokenize(bin, line) when is_binary(bin) do
    tokenize(:unicode.characters_to_list(bin), line)
  end

  def tokenize(list, line) when is_list(list) do
    Enum.reverse(tokenize(list, line, line, [], []))
  end

  ## private

  # tokenize
  defp tokenize('{{{' ++ t, current_line, line, buffer, acc) do
    acc = tokenize_text(current_line, buffer, acc)
    { var, new_line, rest, _ } = tokenize_variable_for_triple(t, line, [])

    cond do
      var == :. ->
        tokenize(rest, new_line, new_line, [], [{ :unescaped_dot, line, var } | acc])
      to_binary(var) =~ %r/^\w+(\.\w+)+$/ ->
        atoms = to_binary(var) |> String.split(".") |> Enum.map(binary_to_atom(&1))
        tokenize(rest, new_line, new_line, [], [{ :unescaped_dotted_name, line, atoms } | acc])
      true ->
        tokenize(rest, new_line, new_line, [], [{ :unescaped_variable, line, var } | acc])
    end
  end

  defp tokenize('{{!' ++ t, current_line, line, buffer, acc) do
    ignore_break_flg = ignore_break?(buffer, acc)
    { rest, new_line, ignore_tail_whitespace_flg } = tokenize_comment(t, line, ignore_break_flg)
    acc = tokenize_text(current_line, buffer, acc, ignore_tail_whitespace_flg)

    tokenize(rest, current_line, new_line, [], acc)
  end

  defp tokenize('{{&' ++ t, current_line, line, buffer, acc) do
    acc = tokenize_text(current_line, buffer, acc)
    { var, new_line, rest, _ } = tokenize_variable(t, line, [])

    cond do
      var == :. ->
        tokenize(rest, new_line, new_line, [], [{ :unescaped_dot, line, var } | acc])
      to_binary(var) =~ %r/^\w+(\.\w+)+$/ ->
        atoms = to_binary(var) |> String.split(".") |> Enum.map(binary_to_atom(&1))
        tokenize(rest, new_line, new_line, [], [{ :unescaped_dotted_name, line, atoms } | acc])
      true ->
        tokenize(rest, new_line, new_line, [], [{ :unescaped_variable, line, var } | acc])
    end
  end

  defp tokenize('{{#' ++ t, current_line, line, buffer, acc) do
    ignore_break_flg = ignore_break?(buffer, acc)
    { var, new_line, rest, ignore_tail_whitespace_flg } = tokenize_variable(t, line, [], ignore_break_flg)
    acc = tokenize_text(current_line, buffer, acc, ignore_tail_whitespace_flg)

    if to_binary(var) =~ %r/^\w+(\.\w+)+$/ do
      atoms = to_binary(var) |> String.split(".") |> Enum.map(binary_to_atom(&1))
      tokenize(rest, new_line, new_line, [], [{ :dotted_name_section, line, atoms } | acc])
    else
      tokenize(rest, new_line, new_line, [], [{ :section, line, var } | acc])
    end
  end

  defp tokenize('{{^' ++ t, current_line, line, buffer, acc) do
    ignore_break_flg = ignore_break?(buffer, acc)
    { var, new_line, rest, ignore_tail_whitespace_flg } = tokenize_variable(t, line, [], ignore_break_flg)
    acc = tokenize_text(current_line, buffer, acc, ignore_tail_whitespace_flg)

    if to_binary(var) =~ %r/^\w+(\.\w+)+$/ do
      atoms = to_binary(var) |> String.split(".") |> Enum.map(binary_to_atom(&1))
      tokenize(rest, new_line, new_line, [], [{ :dotted_name_inverted_section, line, atoms } | acc])
    else
      tokenize(rest, new_line, new_line, [], [{ :inverted_section, line, var } | acc])
    end
  end

  defp tokenize('{{/' ++ t, current_line, line, buffer, acc) do
    ignore_break_flg = ignore_break?(buffer, acc)
    { var, new_line, rest, ignore_tail_whitespace_flg } = tokenize_variable(t, line, [], ignore_break_flg)
    acc = tokenize_text(current_line, buffer, acc, ignore_tail_whitespace_flg)

    if to_binary(var) =~ %r/^\w+(\.\w+)+$/ do
      atoms = to_binary(var) |> String.split(".") |> Enum.map(binary_to_atom(&1))
      tokenize(rest, new_line, new_line, [], [{ :end_section, line, atoms } | acc])
    else
      tokenize(rest, new_line, new_line, [], [{ :end_section, line, var } | acc])
    end
  end

 defp tokenize('{{>' ++ t, current_line, line, buffer, acc) do
    ignore_break_flg = ignore_break?(buffer, acc)
    { var, new_line, rest, ignore_tail_whitespace_flg } = tokenize_variable(t, line, [], ignore_break_flg)
    acc = tokenize_text(current_line, buffer, acc, ignore_tail_whitespace_flg)

    tokenize(rest, new_line, new_line, [], [{ :partial, line, var } | acc])
  end


  defp tokenize('{{' ++ t, current_line, line, buffer, acc) do
    acc = tokenize_text(current_line, buffer, acc)
    { var, new_line, rest, _ } = tokenize_variable(t, line, [])

    cond do
      var == :. ->
        tokenize(rest, new_line, new_line, [], [{ :dot, line, var } | acc])
      to_binary(var) =~ %r/^\w+(\.\w+)+$/ ->
        atoms = to_binary(var) |> String.split(".") |> Enum.map(binary_to_atom(&1))
        tokenize(rest, new_line, new_line, [], [{ :dotted_name, line, atoms } | acc])
      true ->
        tokenize(rest, new_line, new_line, [], [{ :variable, line, var } | acc])
    end
  end

   defp tokenize('\r\n' ++ t, current_line, line, buffer, acc) do
    tokenize(t, current_line, line + 1, [?\n,?\r|buffer], acc)
  end

  defp tokenize('\n' ++ t, current_line, line, buffer, acc) do
    tokenize(t, current_line, line + 1, [?\n|buffer], acc)
  end

  defp tokenize([h|t], current_line, line, buffer, acc) do
    tokenize(t, current_line, line, [h|buffer], acc)
  end

  defp tokenize([], current_line, _line, buffer, acc) do
    tokenize_text(current_line, buffer, acc)
  end

  # tokenize comment

  defp tokenize_comment('}}\r\n' ++ t, line, true) do
    { t, line, true }
  end

  defp tokenize_comment('}}\n' ++ t, line, true) do
    { t, line, true }
  end

  defp tokenize_comment('}}', line, true) do
    { '', line, true }
  end

  defp tokenize_comment('}}' ++ t, line, _ignore_break_flg) do
    { t, line, false }
  end

  defp tokenize_comment([?\r,?\n|t], line, ignore_break_flg) do
    tokenize_comment(t, line + 1, ignore_break_flg)
  end

  defp tokenize_comment([?\n|t], line, ignore_break_flg) do
    tokenize_comment(t, line + 1, ignore_break_flg)
  end

  defp tokenize_comment([_|t], line, ignore_break_flg) do
    tokenize_comment(t, line, ignore_break_flg)
  end

  defp tokenize_comment([], line, _ignore_break_flg) do
    raise SyntaxError, line: line, description: "Unclosed tag"
  end

  # tokenize variable

  defp tokenize_variable(list, line, buffer, ignore_break_flg // false, finish_flg // false)

  defp tokenize_variable('}}' ++ _, line, [], _ignore_break_flg, _finish_flg) do
    raise SyntaxError, line: line, description: "No contents in tag"
  end

  defp tokenize_variable('}}\r\n' ++ t, line, buffer, true, _finish_flg) do
    { buffer |> Enum.reverse |> list_to_atom, line, t, true }
  end

  defp tokenize_variable('}}\n' ++ t, line, buffer, true, _finish_flg) do
    { buffer |> Enum.reverse |> list_to_atom, line, t, true }
  end

  defp tokenize_variable('}}', line, buffer, true, _finish_flg) do
    { buffer |> Enum.reverse |> list_to_atom, line, '', true }
  end

  defp tokenize_variable('}}' ++ t, line, buffer, _ignore_break_flg, _finish_flg) do
    { buffer |> Enum.reverse |> list_to_atom, line, t, false }
  end

  defp tokenize_variable(' ' ++ t, line, [], ignore_break_flg, finish_flg) do
    tokenize_variable(t, line, [], ignore_break_flg, finish_flg)
  end

  defp tokenize_variable(' ' ++ t, line, buffer, ignore_break_flg, _finish_flg) do
    tokenize_variable(t, line, buffer, ignore_break_flg, true)
  end

  defp tokenize_variable([_h|_], line, _buffer, _ignore_break_flg, true) do
    raise SyntaxError, line: line, description: "Illegal content in tag #{inspect(" ")}"
  end

  defp tokenize_variable([h|t], line, buffer, ignore_break_flg, finish_flg) when h in ?a..?z or h in ?A..?Z or h in ?0..?9 or h in [?_, ?-, ?/, ?!, ??, ?.] do
    tokenize_variable(t, line, [h|buffer], ignore_break_flg, finish_flg)
  end

  defp tokenize_variable([h|_], line, _buffer, _ignore_break_flg, _finish_flg) do
    raise SyntaxError, line: line, description: "Illegal content in tag #{inspect(<<h>>)}"
  end

  defp tokenize_variable([], line, _buffer, _ignore_break_flg, _finish_flg) do
    raise SyntaxError, line: line, description: "Unclosed tag"
  end

  # same with tokenize_variable
  defp tokenize_variable_for_triple(list, line, buffer, ignore_break_flg // false, finish_flg // false)

  defp tokenize_variable_for_triple('}}}' ++ _, line, [], _ignore_break_flg, _finish_flg) do
    raise SyntaxError, line: line, description: "No contents in tag"
  end

  defp tokenize_variable_for_triple('}}}\r\n' ++ t, line, buffer, true, _finish_flg) do
    { buffer |> Enum.reverse |> list_to_atom, line, t, true }
  end

  defp tokenize_variable_for_triple('}}}\n' ++ t, line, buffer, true, _finish_flg) do
    { buffer |> Enum.reverse |> list_to_atom, line, t, true }
  end

  defp tokenize_variable_for_triple('}}}', line, buffer, true, _finish_flg) do
    { buffer |> Enum.reverse |> list_to_atom, line, '', true }
  end

  defp tokenize_variable_for_triple('}}}' ++ t, line, buffer, _ignore_break_flg, _finish_flg) do
    { buffer |> Enum.reverse |> list_to_atom, line, t, false }
  end

  defp tokenize_variable_for_triple(' ' ++ t, line, [], ignore_break_flg, finish_flg) do
    tokenize_variable_for_triple(t, line, [], ignore_break_flg, finish_flg)
  end

  defp tokenize_variable_for_triple(' ' ++ t, line, buffer, ignore_break_flg, _finish_flg) do
    tokenize_variable_for_triple(t, line, buffer, ignore_break_flg, true)
  end

  defp tokenize_variable_for_triple([_h|_], line, _buffer, _ignore_break_flg, true) do
    raise SyntaxError, line: line, description: "Illegal content in tag #{inspect(" ")}"
  end

  defp tokenize_variable_for_triple([h|t], line, buffer, ignore_break_flg, finish_flg) when h in ?a..?z or h in ?A..?Z or h in ?0..?9 or h in [?_, ?-, ?/, ?!, ??, ?.] do
    tokenize_variable_for_triple(t, line, [h|buffer], ignore_break_flg, finish_flg)
  end

  defp tokenize_variable_for_triple([h|_], line, _buffer, _ignore_break_flg, _finish_flg) do
    raise SyntaxError, line: line, description: "Illegal content in tag #{inspect(<<h>>)}"
  end

  defp tokenize_variable_for_triple([], line, _buffer, _ignore_break_flg, _finish_flg) do
    raise SyntaxError, line: line, description: "Unclosed tag"
  end



  # tokenize text

  # last argument is flag whether tail whitespaces should be ignored
  defp tokenize_text(line, buffer, acc, ignore_tail_whitespaces_flg // false)

  defp tokenize_text(line, buffer, acc, true) do
    [{ :text, line, String.rstrip(:unicode.characters_to_binary(Enum.reverse(buffer)), ? ) } | acc]
  end

  defp tokenize_text(line, buffer, acc, false) do
    [{ :text, line, :unicode.characters_to_binary(Enum.reverse(buffer)) } | acc]
  end

  # ignore flg

  defp ignore_break?([? |t], acc), do: ignore_break?(t,acc)
  defp ignore_break?([?\n,?\r|_], _), do: true
  defp ignore_break?([?\n|_], _), do: true
  defp ignore_break?([], []), do: true
  defp ignore_break?(_, _), do: false
end
