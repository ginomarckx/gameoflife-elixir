defmodule GameOfLife do
  @moduledoc false

  import Game.{Builder, Organism, Printer}

  def main() do
    %Game{}
    |> add(glider())
    |> add(beacon(), {10, 10})
    |> print_generations(100, 100)
  end
end
