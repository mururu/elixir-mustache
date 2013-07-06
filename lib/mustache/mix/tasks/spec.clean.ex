defmodule Mix.Tasks.Spec.Clean do
   use Mix.Task

  @spec_path Path.expand("../../../../spec", __DIR__)

  def run(_) do
    File.rm Path.join(@spec_path, "spec.exs")
  end
end
