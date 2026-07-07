defmodule PredictorTest do
  use ExUnit.Case
  doctest Predictor

  test "greets the world" do
    assert Predictor.hello() == :world
  end
end
