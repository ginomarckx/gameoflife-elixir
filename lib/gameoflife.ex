defmodule Game.Cell do
  def next(:dead, 3), do: :alive
  def next(:alive, alive_neighbours) when alive_neighbours < 2 or alive_neighbours > 3, do: :dead
  def next(status, _), do: status
end

defmodule Game do
  defstruct age: 0, living: []

  def next(game = %Game{}) do
    %Game{
      age: game.age + 1,
      living: game
              |> Game.Universe.count_living_neighbours()
              |> calculate_next_generation()
    }
  end

  defp calculate_next_generation(cells), do: cells |> Enum.map(&next_cell_or_nil/1) |> Enum.reject(&is_nil/1)

  defp next_cell_or_nil({cell, {status, neighbours}}), do:
    Game.Cell.next(status, neighbours) == :alive && cell
    || nil
end

defmodule Game.Builder do
  def add(game = %Game{}, organism, location \\ {0, 0}), do: %{game |
        living: addSafely(
          game.living,
          organism
          |> Point.translate(location)
        )
      }

  defp addSafely(cells, life) do
    cells -- life == cells or raise "location not available"
    cells ++ life
  end
end

defmodule Game.Universe do
  def count_living_neighbours(game = %Game{}), do: game.living |> Enum.reduce(%{}, &expand_living_cell/2)

  defp expand_living_cell({x, y}, cells) do
    cells
    |> add_living_cell({x, y})
    |> add_neighbour({x - 1, y - 1})
    |> add_neighbour({x, y - 1})
    |> add_neighbour({x + 1, y - 1})
    |> add_neighbour({x - 1, y})
    |> add_neighbour({x + 1, y})
    |> add_neighbour({x - 1, y + 1})
    |> add_neighbour({x, y + 1})
    |> add_neighbour({x + 1, y + 1})
  end

  defp add_living_cell(cells, cell) do
    case cells do
      %{^cell => {_, neighbours}} ->
        %{cells | cell => {:alive, neighbours}}
      _ ->
        cells |> Map.put(cell, {:alive, 0})
    end
  end

  defp add_neighbour(cells, cell) do
    case cells do
      %{^cell => {status, neighbours}} ->
        %{cells | cell => {status, neighbours + 1}}
      _ ->
        cells |> Map.put(cell, {:dead, 1})
    end
  end

  def bounds(game = %Game{}) when game.living == [], do: %{origin: {0, 0}, dimensions: {0, 0}}
  def bounds(game = %Game{}), do: game.living |> Enum.reduce(:nil, &include/2)

  defp include(cell, :nil), do: %{origin: cell, dimensions: {1, 1}}

  defp include(cell = {x, y}, %{origin: {ox, oy}, dimensions: {width, height}}) when x < ox and y < oy do
    %{origin: cell, dimensions: {width + ox - x, height + oy - y}}
  end

  defp include({x, y}, %{origin: {ox, oy}, dimensions: {width, height}}) when x < ox do
    %{origin: {x, oy}, dimensions: {width + ox - x, max(height, y - oy + 1)}}
  end

  defp include({x, y}, %{origin: {ox, oy}, dimensions: {width, height}}) when y < oy do
    %{origin: {ox, y}, dimensions: {max(width, x - ox + 1), height + oy - y}}
  end

  defp include({x, y}, bounds = %{origin: {ox, oy}, dimensions: {width, height}}) do
    %{bounds | dimensions: {max(width, x - ox + 1), max(height, y - oy + 1)}}
  end
end

defmodule Game.Printer do
  import Enum, only: [sort: 2, reduce: 3]
  import String, only: [duplicate: 2]

  @dead "  "
  @alive "\u2588\u258B"

  def print(game = %Game{}) do
    bounds = game
             |> Game.Universe.bounds()

    output = game.living
             |> Enum.sort(&Point.<=/2)
             |> Enum.reduce(%{origin: bounds.origin, cursor: bounds.origin, board: ""}, &print_cell/2)

    IO.puts("Origin: #{bounds.origin |> elem(0)}, #{bounds.origin |> elem(1)}")
    IO.puts(output.board)
    game
  end

  def print_generations(game, times, sleep \\ 200)
  def print_generations(game, times, sleep) when times > 1, do: game |> print_generations(1, sleep) |> print_generations(times - 1, sleep)
  def print_generations(game, times, sleep) when times == 1 do
    :timer.sleep(sleep)
    IO.write(IO.ANSI.clear())
    IO.write(IO.ANSI.home())
    IO.write("#{game.age} >> ")
    game
    |> Game.next()
    |> print()
  end

  defp print_cell({x, y}, output = %{origin: {ox, _}, cursor: {_, cy}, board: board}) when cy < y do
    %{
      output |
      cursor: {x + 1, y},
      board: board <> duplicate("\n", y - cy) <> duplicate(@dead, x - ox) <> @alive
    }
  end

  defp print_cell({x, y}, output = %{origin: _, cursor: {cx, _}, board: board}) do
    %{
      output |
      cursor: {x + 1, y},
      board: board <> duplicate(@dead, x - cx) <> @alive
    }
  end
end

defmodule Point do
  def {_, y1} <= {_, y2} when y1 < y2, do: true
  def {_, y1} <= {_, y2} when y1 > y2, do: false
  def {x1, y1} <= {x2, y2} when y1 == y2, do: Kernel.<=(x1, x2)

  def translate({x, y}, {dx, dy}), do: {x + dx, y + dy}
  def translate(points = [_ | _], point), do: points |> Enum.map( &(&1 |> translate(point)) )
end

defmodule Game.Organism do
  import String, only: [split: 2]
  import Enum, only: [map: 2, flat_map: 2, reject: 2]
  import Stream, only: [with_index: 1]

  @doc """
  Sigil for creating organisms. Living cells are represented by #. Lines are separated by ,.
  Use the 'g' modifier to return a game with this organism.
  """
  def sigil_o(string, []),
      do: string
          |> split(~r/,/)
          |> with_index()
          |> flat_map(&parse_line/1)
          |> reject(&is_nil/1)

  def sigil_o(string, [?g]), do: %Game{living: sigil_o(string, [])}

  defp parse_line({string, y}),
       do: string
           |> to_charlist()
           |> with_index()
           |> map(&(parse_cell(&1, y)))

  defp parse_cell({?#, x}, y), do: {x, y}
  defp parse_cell(_, _), do: nil

  # Still lives
  def block, do: ~o/##,##/
  def beehive, do: ~o/ ##,#  #, ##/
  def loaf, do: ~o/ ##,#  #, # #,  #/
  def boat, do: ~o/##,# #, #/
  def tub, do: ~o/ #,# #, #/

  # Oscillators
  def oscillator, do: ~o/,###/
  def toad, do: ~o/, ###,###/
  def beacon, do: ~o/##,#,   #,  ##/

  # Space ships
  def glider, do: ~o/# #, ##, #/
  def lwss, do: ~o/#  #,    #,#   #, ####/
end
