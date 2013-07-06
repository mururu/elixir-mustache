defmodule Mix.Tasks.Spec.Run do
  use Mix.Task

  @spec_path Path.expand("../../../../spec", __DIR__)

  def run(_) do
    Kernel.ParallelRequire.files [Path.join(@spec_path, "spec.exs")]
  end
end
