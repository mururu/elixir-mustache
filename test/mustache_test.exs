Code.require_file "test_helper.exs", __DIR__

defmodule MustacheTest do
  use ExUnit.Case

  test "1",  do: assert Mustache.render("{{ a }}", a: 1) == "1"
  test "2",  do: assert Mustache.render("{{ a }}", a: "&") == "&amp;"
  test "3",  do: assert Mustache.render("{{& a }}", a: "&") == "&"
  test "4",  do: assert Mustache.render("{{# a }}a{{/ a }}", a: true) == "a"
  test "5",  do: assert Mustache.render("{{# a }}a{{/ a }}", a: false) == ""
  test "6",  do: assert Mustache.render("{{# a }}a{{/ a }}") == ""
  test "7",  do: assert Mustache.render("{{# a }}a{{/ a }}", a: []) == ""
  test "8",  do: assert Mustache.render("{{# a }}a{{/ a }}", a: [[]]) == "a"
  test "9",  do: assert Mustache.render("{{# a }}a{{/ a }}", a: [1,2]) == "aa"
  test "10", do: assert Mustache.render("{{# a }}{{ b }}{{/ a }}", a: [[b: 3], [b: 3]]) == "33"
  test "11", do: assert Mustache.render("{{# a }}{{ b }}1{{/ a }}", a: [[], [b: "&"]]) == "1&amp;1"
  test "12", do: assert Mustache.render("{{^ a }}1{{/ a }}", []) == "1"
  test "13", do: assert Mustache.render("{{^ a }}1{{/ a }}", [a: false]) == "1"
  test "14", do: assert Mustache.render("{{^ a }}1{{/ a }}", [a: []]) == "1"
  test "15", do: assert Mustache.render("{{^ a }}1{{/ a }}", [a: true]) == ""
  test "16", do: assert Mustache.render("{{^ a }}1{{/ a }}", [a: [1]]) == ""

end
