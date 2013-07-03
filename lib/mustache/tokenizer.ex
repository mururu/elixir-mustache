defmodule Mustache.Tokenizer do

  @doc """
  { :text,  line, contents :: binary }
  { :unescaped_variable,   line, contents :: atom }
  { :section,  line, contents :: atom }
  { :inverted_section,   line, contents :: atom }
  { :end_section, line, contents :: atom }
  { :variable,   line, contents :: atom }
  """
  def tokenize(bin, line) when is_binary(bin) do
    tokenize(:unicode.characters_to_list(bin), line)
  end

  def tokenize(list, line) when is_list(list) do
    Enum.reverse(tokenize(list, line, line, [], []))
  end

  ## private

  # tokenize

  defp tokenize('{{!' ++ t, current_line, line, buffer, acc) do
    acc = tokenize_text(current_line, buffer, acc)
    { rest, new_line } = tokenize_comment(t, line)

    tokenize(rest, current_line, new_line, [], acc)
  end

  defp tokenize('{{&' ++ t, current_line, line, buffer, acc) do
    acc = tokenize_text(current_line, buffer, acc)
    { var, new_line, rest } = tokenize_variable(t, line, [])

    tokenize(rest, new_line, new_line, [], [{ :unescaped_variable, line, var } | acc])
  end

  defp tokenize('{{#' ++ t, current_line, line, buffer, acc) do
    acc = tokenize_text(current_line, buffer, acc)
    { var, new_line, rest } = tokenize_variable(t, line, [])

    tokenize(rest, new_line, new_line, [], [{ :section, line, var } | acc])
  end

  defp tokenize('{{^' ++ t, current_line, line, buffer, acc) do
    acc = tokenize_text(current_line, buffer, acc)
    { var, new_line, rest } = tokenize_variable(t, line, [])

    tokenize(rest, new_line, new_line, [], [{ :inverted_section, line, var } | acc])
  end

  defp tokenize('{{/' ++ t, current_line, line, buffer, acc) do
    acc = tokenize_text(current_line, buffer, acc)
    { var, new_line, rest } = tokenize_variable(t, line, [])

    tokenize(rest, new_line, new_line, [], [{ :end_section, line, var } | acc])
  end

  defp tokenize('{{' ++ t, current_line, line, buffer, acc) do
    acc = tokenize_text(current_line, buffer, acc)
    { var, new_line, rest } = tokenize_variable(t, line, [])

    tokenize(rest, new_line, new_line, [], [{ :variable, line, var } | acc])
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

  defp tokenize_comment('}}' ++ t, line) do
    { t, line }
  end

  defp tokenize_comment([?\n|t], line) do
    tokenize_comment(t, line + 1)
  end

  defp tokenize_comment([_|t], line) do
    tokenize_comment(t, line)
  end

  defp tokenize_comment([], line) do
    raise SyntaxError, line: line, description: "Unclosed tag"
  end

  # tokenize variable

  defp tokenize_variable(list, line, buffer, finish_flg // false)

  defp tokenize_variable('}}' ++ _, line, [], _finish_flg) do
    raise SyntaxError, line: line, description: "No contents in tag"
  end

  defp tokenize_variable('}}' ++ t, line, buffer, _finish_flg) do
    { buffer |> Enum.reverse |> list_to_atom, line, t }
  end

  defp tokenize_variable(' ' ++ t, line, [], finish_flg) do
    tokenize_variable(t, line, [], finish_flg)
  end

  defp tokenize_variable(' ' ++ t, line, buffer, _finish_flg) do
    tokenize_variable(t, line, buffer, true)
  end

  defp tokenize_variable([_h|_], line, _buffer, true) do
    raise SyntaxError, line: line, description: "Illegal content in tag #{inspect(" ")}"
  end

  defp tokenize_variable([h|t], line, buffer, _finish_tag) when h in ?a..?z or h in ?A..?Z or h in ?0..?9 or h in [?_, ?-, ?/, ?!, ??, ?.] do
    tokenize_variable(t, line, [h|buffer])
  end

  defp tokenize_variable([h|_], line, _buffer, _finish_flg) do
    raise SyntaxError, line: line, description: "Illegal content in tag #{inspect(<<h>>)}"
  end

  defp tokenize_variable([], line, _buffer, _finish_flg) do
    raise SyntaxError, line: line, description: "Unclosed tag"
  end

  # tokenize text

  defp tokenize_text(line, buffer, acc) do
    [{ :text, line, :unicode.characters_to_binary(Enum.reverse(buffer)) } | acc]
  end
end
