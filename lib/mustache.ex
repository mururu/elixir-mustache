defmodule Mustache do
  def render(source, bindings // [], options // []) do
    render_string(source, bindings, options)
  end

  def render_string(source, bindings // [], options // []) do
    compiled = compile_string(source, options)
    do_eval(compiled, bindings, options)
  end

  def render_file(filename, bindings // [], options // []) do
    render_string(File.read!(filename), bindings, options)
  end

  def compile_string(source, options // []) do
    Mustache.Compiler.compile(source, options)
  end

  def compile_file(filename, options // []) do
    compile_string(File.read!(filename), options)
  end

  defp do_eval(compiled, bindings, options) do
    { result, _ } = Code.eval_quoted(compiled, wrap_bindings(bindings), options)
    result
  end

  defp wrap_bindings(bindings) do
    [mustache_root: [bindings]]
  end
end
