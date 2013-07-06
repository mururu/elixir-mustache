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
  test "17", do: assert Mustache.render("{{# a }}{{b}}{{/ a }}", a: [b: 2]) == "2"
  test "18", do: assert Mustache.render("{{^ a }}{{b}}{{/ a }}", a: [b: 2]) == ""
  test "19" do
    template = """
    {{! ignore this line! }}
    Hello {{name}}
    {{! ignore this line! }}
    You have just won {{value}} dollars!
    {{#in_ca}}
    Well, {{taxed_value}} dollars, after taxes.
    {{/in_ca}}
    a{{! dont ignore this line! }}
    """

    expected = """
    Hello mururu
    You have just won 1000 dollars!
    Well, 50 dollars, after taxes.
    Well, 40 dollars, after taxes.
    a
    """

    assert Mustache.render(template, [name: "mururu", value: 1000, in_ca: [[taxed_value: 50], [taxed_value: 40]]]) == expected
  end
end
