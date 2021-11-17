defmodule Game.Test do
  use ExUnit.Case
  import Game.{Cell, Builder, Organism}

  describe "Living cell" do
    test "survives with 2 or 3 neighbours", do: assert :alive |> next(2) == :alive
    test "dies of underpopulation with less than 2 neighbours", do: assert :alive |> next(1) == :dead
    test "dies of overpopulation with more than 3 neighbours", do: assert :alive |> next(4) == :dead
  end

  describe "Dead cell" do
    test "regenerates with exactly 3 neighbours", do: assert :dead |> next(3) == :alive
    test "remains dead", do: assert :dead |> next(4) == :dead
  end

  describe "Game" do
    test "next returns the next generation of the board" do
      assert %Game{} |> add(oscillator()) |> Game.next()
             == %Game{age: 1, living: ~o/ #, #, #/}
    end
  end
end

defmodule Game.Universe.Test do
  use ExUnit.Case

  import Game.{Builder, Organism, Universe}

  describe "count living neighbours" do
    test "for empty game", do: assert ~o//g |> count_living_neighbours() == %{}

    test "returns map with 9 cells for single cell game" do
      assert ~o/#/g |> count_living_neighbours
             == %{
               {-1,-1} => {:dead, 1},
               {0,-1} => {:dead, 1},
               {1,-1} => {:dead, 1},
               {-1,0} => {:dead, 1},
               {0,0} => {:alive, 0},
               {1,0} => {:dead, 1},
               {-1,1} => {:dead, 1},
               {0,1} => {:dead, 1},
               {1,1} => {:dead, 1},
             }
    end

    test "accumulates neighbours in map" do
      assert ~o/##/g |> count_living_neighbours
             == %{
               {-1,-1} => {:dead, 1},
               {0,-1} => {:dead, 2},
               {1,-1} => {:dead, 2},
               {2,-1} => {:dead, 1},
               {-1,0} => {:dead, 1},
               {0,0} => {:alive, 1},
               {1,0} => {:alive, 1},
               {2,0} => {:dead, 1},
               {-1,1} => {:dead, 1},
               {0,1} => {:dead, 2},
               {1,1} => {:dead, 2},
               {2,1} => {:dead, 1},
             }
    end
  end

  describe "bounds for" do
    test "single cell" do
      assert %Game{living: [{2,3}]} |> bounds()
             == %{origin: {2,3}, dimensions: {1,1}}
    end

    test "second cell right" do
      assert %Game{living: [{1,1}, {2, 1}]} |> bounds()
             == %{origin: {1,1}, dimensions: {2,1}}
    end

    test "second cell left" do
      assert %Game{living: [{1,1}, {0, 1}]} |> bounds()
             == %{origin: {0,1}, dimensions: {2,1}}
    end

    test "second cell bottom" do
      assert %Game{living: [{1,1}, {1, 2}]} |> bounds()
             == %{origin: {1,1}, dimensions: {1,2}}
    end

    test "second cell top" do
      assert %Game{living: [{1,1}, {1, 0}]} |> bounds()
             == %{origin: {1,0}, dimensions: {1,2}}
    end

    test "second cell bottom right" do
      assert %Game{living: [{2,3}, {4, 3}]} |> bounds()
             == %{origin: {2,3}, dimensions: {3, 1}}
    end
  end
end

defmodule Game.Builder.Test do
  use ExUnit.Case

  import Game.{Builder, Organism}

  describe "builder" do
    test "adds block at origin", do: assert %Game{} |> add(block()) == ~o/##,##/g
    test "adds block at location", do: assert %Game{} |> add(block(), {1, 2}) == ~o/,, ##, ##/g

    test "raises conflict when adding organism to location that is occupied" do
      assert_raise RuntimeError, fn -> %Game{} |> add(block()) |> add(block()) end
    end
  end
end

defmodule Game.Organism.Test do
  use ExUnit.Case

  import Game.Organism

  test "~o//", do: assert ~o// == []
  test "~o/#/", do: assert ~o/#/ == [{0,0}]
  test "~o/ #/", do: assert ~o/ #/ == [{1,0}]
  test "~o/,#/", do: assert ~o/,#/ == [{0,1}]
  test "~o/#, #/", do: assert ~o/#, #/ == [{0,0}, {1,1}]

  test "~o/#, #/g", do: assert ~o/#, #/g == %Game{living: ~o/#, #/}
end

defmodule Point.Test do
  use ExUnit.Case

  import Point

  describe "compare" do
    import Kernel, except: [<=: 2]

    test "same points", do: assert {1,3} <= {1,3}
    test "left and right", do: assert {1,3} <= {3,3}
    test "right and left", do: refute {1,3} <= {0,3}
    test "higher and lower", do: assert {1,3} <= {1,4}
    test "lower and higher", do: refute {1,3} <= {1,2}
  end

  describe "translate" do
    test "point", do: assert {1,3} |> translate({4,5}) == {5,8}
    test "list", do: assert [{0,0}, {1,0}] |> translate({2,3}) == [{2,3}, {3,3}]
  end
end
