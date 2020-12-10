defmodule ValuationTest do
  use ExUnit.Case

  test "test valuation get function" do
    # Function output: Map in form %{{price, side} -> qty, ...}
    # Book_depth = 2, return correct book_depth
    fv         = 99.5
    inventory  = 0
    qty_limit  = 10
    margin     = 0.1
    book_depth = 2
    md = %BBO{
      bids: [{99,  10}, {98,  10}, {97, 10}, {96, 5}, {95, 4}],
      asks: [{100, 10}, {101, 12}, {102, 5}, {103,16}, {104, 22}],
      instrument: "BTCCQ"
    }
    # Function output : Map in form %{{price, side} => qty, ... }
    # Return correct depth of the book
    assert Valuations.get(fv, md, inventory, qty_limit, margin, book_depth) == %{
      {99,  :bid } => 10,
      {98,  :bid } => 10,
      {100, :ask } => 10,
      {101, :ask } => 12,
    }

    # case 2
    # Inventory reached hard limit. Oversold
    # Place only bid side order, place bid@99, bid@100
    # To avoid bid@100 self-trade with ask@100
    # Drop bid@100 and place bid@98 to fill up book_depth
    fv         = 99.5
    inventory  = -10
    qty_limit  = 10
    margin     = 0.1
    book_depth = 2
    assert Valuations.get(fv, md, inventory, qty_limit, margin, book_depth) == %{
      {99,  :bid } => 10,
      {98,  :bid } => 10
    }

    # case 3
    # Handle Self-Trading problem
    # inv = 8 and we should move our orders down
    # ask@99 willnot be placed to avoid self-trade
    fv         = 99.5
    inventory  = 8
    qty_limit  = 10
    margin     = 0.1
    book_depth = 3
    assert Valuations.get(fv, md, inventory, qty_limit, margin, book_depth) == %{
      {98,  :bid} => 10,
      {97,  :bid} => 10,
      {96,  :bid} => 5,
      {100, :ask} => 10,
      {101, :ask} => 12,
      {102, :ask} => 5
    }

    # case 4
    # Handle market moves, this will cancel ask@100, place bid@100
    # To avoid self-trade, bid@100 will not be placed until next BBO update
    fv         = 101
    inventory  = 0
    qty_limit  = 10
    margin     = 0.1
    book_depth = 3
    assert Valuations.get(fv, md, inventory, qty_limit, margin, book_depth) == %{
      {97,  :bid} => 10,
      {98,  :bid} => 10,
      {99,  :bid} => 10,
      {102, :ask} => 5,
      {103, :ask} => 16,
      {104, :ask} => 22
    }

    # case 5
    # return nothing for empty order book
    fv         = 101
    inventory  = 0
    qty_limit  = 10
    margin     = 0.1
    book_depth = 6
    md = %{bids: [], asks: [], instrument: nil}
    assert Valuations.get(fv, md, inventory, qty_limit, margin, book_depth) == %{}
  end
end
