defmodule Mustache do
  @moduledoc """
  Mustache is a logic-less templates.
  See [mustache(5) -- Logic-less templates.](http://mustache.github.io/mustache.5.html) for more details
  """

  @doc """
  Get a string `source` and evaluate the values using the `bindings`.
  This is an alias of `Mustache.render_string`.

  ## Examples

      Mustache.render "Hello, {{name}}", [name: "Mustache"]
      #=> "Hello, Mustache!"

  """
  def render(source, bindings // [], options // []) do
    render_string(source, bindings, options)
  end

  @doc """
  Get a string `source` and evaluate the values using the `bindings`.

  ## Examples

      Mustache.render_string "Hello, {{name}}!", [name: "Mustache"]
      #=> "Hello, Mustache!"

  """
  def render_string(source, bindings // [], options // []) do
    compiled = compile_string(source, options)
    do_eval(compiled, bindings, options)
  end

  @doc """
  Get a `filename` and evaluate the values using the `bindings`.

  ## Examples

      # hello.mustache
      Hello, {{name}}!

      # iex
      Mustache.render_file "hello.mustache", [name: "Mustache"]
      #=> "Hello, Mustache!"

  """
  def render_file(filename, bindings // [], options // []) do
    render_string(File.read!(filename), bindings, options)
  end

  @doc """
  Get a quoted expression as a `template` and evaluate the values using the `bindings`.
  """
  def render_compiled_template(template, bindings, options // []) do
    do_eval(template, bindings, options)
  end

  @doc """
  Get a string `source` and generate a quoted expression.
  This is an alias of `compile_string`.
  """
  def compile(source, options // []) do
    compile_string(source, options)
  end

  @doc """
  Get a string `source` and generate a quoted expression.
  """
  def compile_string(source, options // []) do
    Mustache.Compiler.compile(source, options)
  end

  @doc """
  Get a `filename` and generate a quoted expression.
  """
  def compile_file(filename, options // []) do
    compile_string(File.read!(filename), options)
  end

  defp to_context(bindings) do
    [mustache_root: [bindings]]
  end

  defp do_eval(compiled, bindings, options) do
    { result, _ } = Code.eval_quoted(compiled, to_context(bindings), options)
    result
  end
end
