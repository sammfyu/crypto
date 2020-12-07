defmodule ValuationTest do
  use ExUnit.Case

  test "test valuation function" do
    inventory  = 0
    qty_limit  = 30
    md = %BBO{
      bids: [{99,  10}, {98,  10}, {97, 10}],
      asks: [{100, 10}, {101, 12}, {102, 5}],
      instrument: "BTCCQ"
    }
    assert Valuations.get(99.5, md, inventory, qty_limit) == %{
      {99,  :bid } => 0.5,
      {98,  :bid } => 1.5,
      {97,  :bid } => 2.5,
      {100, :ask } => 0.5,
      {101, :ask } => 1.5,
      {102, :ask } => 2.5
    }
  end
end
