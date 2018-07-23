defmodule RegretomaticTest do
  use ExUnit.Case
  doctest Regretomatic

  test "greets the world" do
    assert Regretomatic.hello() == :world
  end
end
