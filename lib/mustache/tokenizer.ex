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
    Enum.reverse(tokenize(list, { '{{', '}}' }, line, line, [], []))
  end

  ## private

  # tokenize

  defp tokenize('\r\n' ++ t, tags, current_line, line, buffer, acc) do
    tokenize(t, tags, current_line, line + 1, [?\n,?\r|buffer], acc)
  end

  defp tokenize('\n' ++ t, tags, current_line, line, buffer, acc) do
    tokenize(t, tags, current_line, line + 1, [?\n|buffer], acc)
  end

  defp tokenize([], _tags, current_line, _line, buffer, acc) do
    tokenize_text(current_line, buffer, acc)
  end

  defp tokenize(string, { otag, _ } = tags, current_line, line, buffer, acc) do
    case strip_tag(string, otag) do
      { :ok, rest } ->
        case rest do
          [] -> raise SyntaxError, description: "Illegal content in tag"
          [?{|t] -> tokenize_mustache(t, tags, current_line, line, buffer, acc)
          [?!|t] -> tokenize_bang(t, tags, current_line, line, buffer, acc)
          [?#|t] -> tokenize_hash(t, tags, current_line, line, buffer, acc)
          [?^|t] -> tokenize_hat(t, tags, current_line, line, buffer, acc)
          [?/|t] -> tokenize_slash(t, tags, current_line, line, buffer, acc)
          [?>|t] -> tokenize_gt(t, tags, current_line, line, buffer, acc)
          [?&|t] -> tokenize_and(t, tags, current_line, line, buffer, acc)
          [?=|t] -> tokenize_equal(t, tags, current_line, line, buffer, acc)
          t -> tokenize_simple(t, tags, current_line, line, buffer, acc)
        end
      _ ->
        [h|t] = string
        tokenize(t, tags, current_line, line, [h|buffer], acc)
    end
  end

  # tokenize inside of tags

  defp tokenize_mustache(t, { _, ctag } = tags, current_line, line, buffer, acc) do
    acc = tokenize_text(current_line, buffer, acc)
    { var, new_line, rest, _ } = tokenize_variable(t, [?}|ctag] , line, [])

    cond do
      var == :. ->
        tokenize(rest, tags, new_line, new_line, [], [{ :unescaped_dot, line, var } | acc])
      to_binary(var) =~ %r/^\w+(\.\w+)+$/ ->
        atoms = to_binary(var) |> String.split(".") |> Enum.map(binary_to_atom(&1))
        tokenize(rest, tags, new_line, new_line, [], [{ :unescaped_dotted_name, line, atoms } | acc])
      true ->
        tokenize(rest, tags, new_line, new_line, [], [{ :unescaped_variable, line, var } | acc])
    end
  end

  defp tokenize_bang(t, { _, ctag } = tags, current_line, line, buffer, acc) do
    ignore_break_flg = ignore_break?(buffer, acc)
    { rest, new_line, ignore_tail_whitespace_flg } = tokenize_comment(t, ctag, line, ignore_break_flg)
    acc = tokenize_text(current_line, buffer, acc, ignore_tail_whitespace_flg)

    tokenize(rest, tags, current_line, new_line, [], acc)
  end

  defp tokenize_and(t, { _, ctag } = tags, current_line, line, buffer, acc) do
    acc = tokenize_text(current_line, buffer, acc)
    { var, new_line, rest, _ } = tokenize_variable(t, ctag, line, [])

    cond do
      var == :. ->
        tokenize(rest, tags, new_line, new_line, [], [{ :unescaped_dot, line, var } | acc])
      to_binary(var) =~ %r/^\w+(\.\w+)+$/ ->
        atoms = to_binary(var) |> String.split(".") |> Enum.map(binary_to_atom(&1))
        tokenize(rest, tags, new_line, new_line, [], [{ :unescaped_dotted_name, line, atoms } | acc])
      true ->
        tokenize(rest, tags, new_line, new_line, [], [{ :unescaped_variable, line, var } | acc])
    end
  end

  defp tokenize_hash(t, { _, ctag } = tags, current_line, line, buffer, acc) do
    ignore_break_flg = ignore_break?(buffer, acc)
    { var, new_line, rest, ignore_tail_whitespace_flg } = tokenize_variable(t, ctag, line, [], ignore_break_flg)
    acc = tokenize_text(current_line, buffer, acc, ignore_tail_whitespace_flg)

    if to_binary(var) =~ %r/^\w+(\.\w+)+$/ do
      atoms = to_binary(var) |> String.split(".") |> Enum.map(binary_to_atom(&1))
      tokenize(rest, tags, new_line, new_line, [], [{ :dotted_name_section, line, atoms } | acc])
    else
      tokenize(rest, tags, new_line, new_line, [], [{ :section, line, var } | acc])
    end
  end

  defp tokenize_hat(t, { _, ctag } = tags, current_line, line, buffer, acc) do
    ignore_break_flg = ignore_break?(buffer, acc)
    { var, new_line, rest, ignore_tail_whitespace_flg } = tokenize_variable(t, ctag, line, [], ignore_break_flg)
    acc = tokenize_text(current_line, buffer, acc, ignore_tail_whitespace_flg)

    if to_binary(var) =~ %r/^\w+(\.\w+)+$/ do
      atoms = to_binary(var) |> String.split(".") |> Enum.map(binary_to_atom(&1))
      tokenize(rest, tags, new_line, new_line, [], [{ :dotted_name_inverted_section, line, atoms } | acc])
    else
      tokenize(rest, tags, new_line, new_line, [], [{ :inverted_section, line, var } | acc])
    end
  end

  defp tokenize_slash(t, { _, ctag } = tags, current_line, line, buffer, acc) do
    ignore_break_flg = ignore_break?(buffer, acc)
    { var, new_line, rest, ignore_tail_whitespace_flg } = tokenize_variable(t, ctag, line, [], ignore_break_flg)
    acc = tokenize_text(current_line, buffer, acc, ignore_tail_whitespace_flg)

    if to_binary(var) =~ %r/^\w+(\.\w+)+$/ do
      atoms = to_binary(var) |> String.split(".") |> Enum.map(binary_to_atom(&1))
      tokenize(rest, tags, new_line, new_line, [], [{ :end_section, line, atoms } | acc])
    else
      tokenize(rest, tags, new_line, new_line, [], [{ :end_section, line, var } | acc])
    end
  end

 defp tokenize_gt(t, { _, ctag } = tags, current_line, line, buffer, acc) do
    ignore_break_flg = ignore_break?(buffer, acc)
    { var, new_line, rest, ignore_tail_whitespace_flg } = tokenize_variable(t, ctag, line, [], ignore_break_flg)
    acc = tokenize_text(current_line, buffer, acc, ignore_tail_whitespace_flg)

    tokenize(rest, tags, new_line, new_line, [], [{ :partial, line, var } | acc])
  end


  defp tokenize_simple(t, { _, ctag } = tags, current_line, line, buffer, acc) do
    acc = tokenize_text(current_line, buffer, acc)
    { var, new_line, rest, _ } = tokenize_variable(t, ctag, line, [])

    cond do
      var == :. ->
        tokenize(rest, tags, new_line, new_line, [], [{ :dot, line, var } | acc])
      to_binary(var) =~ %r/^\w+(\.\w+)+$/ ->
        atoms = to_binary(var) |> String.split(".") |> Enum.map(binary_to_atom(&1))
        tokenize(rest, tags, new_line, new_line, [], [{ :dotted_name, line, atoms } | acc])
      true ->
        tokenize(rest, tags, new_line, new_line, [], [{ :variable, line, var } | acc])
    end
  end

  defp tokenize_equal(t, { _, ctag }, current_line, line, buffer, acc) do
    ignore_break_flg = ignore_break?(buffer, acc)
    { new_tags, new_line, rest, ignore_tail_whitespace_flg } = tokenize_new_tag(t, [?=|ctag], line, ignore_break_flg)
    acc = tokenize_text(current_line, buffer, acc, ignore_tail_whitespace_flg)

    tokenize(rest, new_tags, new_line, new_line, [], acc)
  end

  # tokenize comment

  defp tokenize_comment([?\r,?\n|t], ctag, line, ignore_break_flg) do
    tokenize_comment(t, ctag, line + 1, ignore_break_flg)
  end

  defp tokenize_comment([?\n|t], ctag, line, ignore_break_flg) do
    tokenize_comment(t, ctag, line + 1, ignore_break_flg)
  end

  defp tokenize_comment([], _ctag, line, _ignore_break_flg) do
    raise SyntaxError, line: line, description: "Unclosed tag"
  end

  defp tokenize_comment(string, ctag, line, ignore_break_flg) do
    case strip_tag(string, ctag) do
      { :ok, rest } ->
        case rest do
          [?\r,?\n|t] when ignore_break_flg -> { t, line, true }
          [?\n|t] when ignore_break_flg -> { t, line, true }
          [] when ignore_break_flg -> { '', line, true }
          t -> { t, line, false }
        end
      _ ->
        [_|t] = string
        tokenize_comment(t, ctag, line, ignore_break_flg)
    end
  end

  # tokenize variable

  defp tokenize_variable(list, ctag, line, buffer, ignore_break_flg // false, finish_flg // false)

  defp tokenize_variable(' ' ++ t, ctag, line, [], ignore_break_flg, finish_flg) do
    tokenize_variable(t, ctag, line, [], ignore_break_flg, finish_flg)
  end

  defp tokenize_variable(' ' ++ t, ctag, line, buffer, ignore_break_flg, _finish_flg) do
    tokenize_variable(t, ctag, line, buffer, ignore_break_flg, true)
  end

  defp tokenize_variable([], _ctag, line, _buffer, _ignore_break_flg, _finish_flg) do
    raise SyntaxError, line: line, description: "Unclosed tag"
  end

  defp tokenize_variable(string, ctag, line, buffer, ignore_break_flg, finish_flg) do
    case strip_tag(string, ctag) do
      { :ok, rest } ->
        case rest do
          _ when buffer == [] ->
            raise SyntaxError, line: line, description: "No contents in tag"
          [?\r,?\n|t] when ignore_break_flg ->
            { buffer |> Enum.reverse |> list_to_atom, line, t, true }
          [?\n|t] when ignore_break_flg ->
            { buffer |> Enum.reverse |> list_to_atom, line, t, true }
          [] when ignore_break_flg ->
            { buffer |> Enum.reverse |> list_to_atom, line, '', true }
          t ->
            { buffer |> Enum.reverse |> list_to_atom, line, t, false }
        end
      _ ->
        case string do
          [_|_] when finish_flg ->
            raise SyntaxError, line: line, description: "Illegal content in tag #{inspect(" ")}"
          [h|t] when h in ?a..?z or h in ?A..?Z or h in ?0..?9 or h in [?_, ?-, ?/, ?!, ??, ?.] ->
            tokenize_variable(t, ctag, line, [h|buffer], ignore_break_flg, finish_flg)
          [h|_] ->
            raise SyntaxError, line: line, description: "Illegal content in tag #{inspect(<<h>>)}"
        end
    end
  end

  # tokenize new tag

  defp tokenize_new_tag(string, ctag, line, ignore_break_flg) do
    string = strip_space(string)

    { new_otag, rest } = tokenize_new_otag(string, [])
    { new_ctag, rest, ignore_tail_whitespace_flg } = tokenize_new_ctag(rest, ctag, [], ignore_break_flg)

    { { new_otag, new_ctag }, line, rest, ignore_tail_whitespace_flg }
  end

  defp strip_psace([]), do: raise(SyntaxError, description: "Unclosed tag")
  defp strip_space([? |t]), do: t
  defp strip_space(string), do: string

  defp tokenize_new_otag(string, buffer, finish_flg // false)

  defp tokenize_new_otag('', _, _) do
    raise SyntaxError, description: "Unclosed tag"
  end

  defp tokenize_new_otag([? |t], buffer, _finish_flg) do
    tokenize_new_otag(t, buffer, true)
  end

  defp tokenize_new_otag([h|t], buffer, false) do
    tokenize_new_otag(t, [h|buffer], false)
  end

  defp tokenize_new_otag(rest, buffer, true) do
    { :lists.reverse(buffer), rest }
  end

  defp tokenize_new_ctag(string, ctag, buffer, ignore_break_flg) do
    case strip_tag(string, ctag) do
      { :ok, rest } ->
        case rest do
          [?\r,?\n|t] when ignore_break_flg ->
            { :lists.reverse(buffer), t, true }
          [?\n|t] when ignore_break_flg ->
            { :lists.reverse(buffer), t, true }
          [] when ignore_break_flg ->
            { :lists.reverse(buffer), '', true }
          t ->
            { :lists.reverse(buffer), t, false }
        end
      _ ->
        case string do
          [] -> raise SyntaxError, description: "Unclosed tag"
          [? |t] ->
            tokenize_new_ctag(t, ctag, buffer, ignore_break_flg)
          [h|t] ->
            tokenize_new_ctag(t, ctag, [h|buffer], ignore_break_flg)
        end
    end
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

  # strip tag

  defp strip_tag(rest, '') do
    { :ok, rest }
  end

  defp strip_tag('', _) do
    nil
  end

  defp strip_tag([h|t1], [h|t2]) do
    strip_tag(t1, t2)
  end

  defp strip_tag(_, _) do
    nil
  end


end
