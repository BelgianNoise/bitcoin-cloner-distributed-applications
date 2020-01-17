defmodule ReporterTest do
  use ExUnit.Case
  doctest Reporter

  test "greets the world" do
    assert Reporter.hello() == :world
  end
end
