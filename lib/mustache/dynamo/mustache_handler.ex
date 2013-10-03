if Enum.all? [Dynamo.Templates.Handler, Dynamo.Template], &Code.ensure_loaded?(&1) do
  defmodule Dynamo.Templates.MUSTACHEHandler do
    @moduledoc """
    Mustache Handler for [Dynamo](https://github.com/elixir-lang/dynamo)

      ## Examples

        # hello.html.mustache
        <html>
        <head>
          <title>{{title}}</title>
        </head>
        <body>
          <ul>
          {{#contents}}
            <li>{{.}}</li>
          {{/contents}}
          </ul>
        </body>
        </html>

        # router
        get "/" do
          conn.assign(:title, "Mustache")
          conn.assign(:contents, ["first", "second"])
          render conn, "hello.html"
        end

        # result
        <html>
        <head>
          <title>Mustache</title>
        </head>
        <body>
          <ul>
            <li>first</li>
            <li>second</li>
          <ul>
        </body>
        </html>

    """

    @behaviour Dynamo.Templates.Handler

    @doc false
    def compile(Dynamo.Template[identifier: identifier], source, locals) do
      vars   = vars(locals)
      args   = [{ :mustache_root, [], nil }|vars]
      match  = match(args)
      source = Mustache.compile_string(source, file: identifier)

      { args, quote do
        unquote_splicing(match)
        body = unquote(source)
        { unquote(vars), body }
      end }
    end

    @doc false
    def render(module, function, locals, assigns) do
      apply module, function, [assigns|Keyword.values(locals)]
    end

    defp vars(locals) do
      lc name inlist locals, do: { name, [], nil }
    end

    defp match(locals) do
      lc var inlist locals, do: { :=, [], [{ :_, [], nil }, var] }
    end
  end
end
