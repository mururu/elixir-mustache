Code.require_file "test_helper.exs", __DIR__

defmodule MustacheTest do
  use ExUnit.Case

  test "render simple" do
    assert Mustache.render("Hello, {{name}}", [name: "Mustache"]) == "Hello, Mustache"
  end

  test "render multi line" do
    assert Mustache.render("Hello\n{{name}}", [name: "Mustache"]) == "Hello\nMustache"
  end

  test "render with nested context" do
    assert Mustache.render("{{#a}}{{#b}}Mustache{{/b}}{{/a}}", [a: true, b: true]) == "Mustache"
  end

  test "render nil" do
    assert Mustache.render("Hello, {{name}}", [name: nil]) == "Hello, "
  end
  test "render missing variable" do
    assert Mustache.render("Hello, {{name}}", []) == "Hello, "
  end

  test "render unescaped" do
    assert Mustache.render("{{{string}}}", [string: "&\'\"<>"]) == "&\'\"<>"
  end

  test "render unescaped ampersand" do
    assert Mustache.render("{{{string}}}", [string: "&\'\"<>"]) == "&\'\"<>"
  end

  test "render escaped" do
    assert Mustache.render("{{string}}", [string: "&\'\"<>"]) == "&amp;&#39;&quot;&lt;&gt;"
  end

  test "render list" do
    assert Mustache.render("Hello{{#names}}, {{name}}{{/names}}", [names: [[name: "Mustache"], [name: "Elixir"]]]) == "Hello, Mustache, Elixir"
  end

  test "render list twice" do
    assert Mustache.render("Hello{{#names}}, {{name}}{{/names}}! Hello{{#names}}, {{name}}{{/names}}!", [names: [[name: "Mustache"], [name: "Elixir"]]]) == "Hello, Mustache, Elixir! Hello, Mustache, Elixir!"
  end

  test "render single value" do
    assert Mustache.render("Hello{{#person}}, {{name}}{{/person}}!", [person: [name: "Mustache"]]) == "Hello, Mustache!"
  end

  test "render empty list" do
    assert Mustache.render("{{#things}}something{{/things}}", [things: []]) == ""
  end

  test "render nested list" do
    assert Mustache.render("{{#x}}{{#y}}{{z}}{{/y}}{{/x}}", [x: [y: [z: "z"]]]) == "z"
  end

  test "render comment" do
    assert Mustache.render("Hello, {{! comment }}{{name}}", [name: "Mustache"]) == "Hello, Mustache"
  end

  test "render tags with whitespace" do
    assert Mustache.render("Hello, {{# names }}{{ name }}{{/ names }}", [names: [[name: "Mustache"]]]) == "Hello, Mustache"
  end

  test "render true section" do
    assert Mustache.render("Hello, {{#bool}}Mustache{{/bool}}", [bool: true]) == "Hello, Mustache"
  end

  test "render false section" do
    assert Mustache.render("Hello, {{#bool}}Mustache{{/bool}}", [bool: false]) == "Hello, "
  end

  test "render inverted empty list" do
    assert Mustache.render("{{^things}}Empty{{/things}}", [thins: []]) == "Empty"
  end

  test "render inverted list" do
    assert Mustache.render("{{^things}}Empty{{/things}}", [things: ["yeah"]]) == ""
  end

  test "render inverted true section" do
    assert Mustache.render("Hello, {{^bool}}Mustache{{/bool}}", [bool: true]) == "Hello, "
  end

  test "render inverted false section" do
    assert Mustache.render("Hello, {{^bool}}Mustache{{/bool}}", [bool: false]) == "Hello, Mustache"
  end

  test "render with delimiters" do
    assert Mustache.render("{{=<% %>=}}Hello, <%name%>", [name: "Mustache"]) == "Hello, Mustache"
  end

  test "render with delimiters changed twice" do
    assert Mustache.render("{{=[ ]=}}[greeting], [=<% %>=]<%name%>", [greeting: "Hello", name: "Mustache"]) == "Hello, Mustache"
  end

  test "render dotted name" do
    assert Mustache.render("Hello, {{cool.mustache.name}}", [cool: [mustache: [name: "Mustache"]]]) == "Hello, Mustache"
  end

  test "render dotted name section" do
    assert Mustache.render("Hello, {{#person.name}}Mustache{{/person.name}}", [person: [name: true]]) == "Hello, Mustache"
  end

  test "render dotted name inverted section" do
    assert Mustache.render("Hello, {{#person.name}}Mustache{{/person.name}}", [people: [names: true]]) == "Hello, "
  end

  test "render implicit iterator" do
    assert Mustache.render("Hello{{#names}}, {{.}}{{/names}}!", [names: ["Mustache", "Elixir"]]) == "Hello, Mustache, Elixir!"
  end

  test "render lambda" do
    assert Mustache.render("Hello, {{name}}", [name: fn -> "Mustache" end]) == "Hello, Mustache"
  end

  test "render partial" do
    assert Mustache.render("Hello, {{>name}}", [n: "Mustache"], partials: [name: "{{n}}"]) == "Hello, Mustache"
  end

  test "render looooong" do
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
