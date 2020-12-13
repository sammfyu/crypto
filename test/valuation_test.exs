defmodule ValuationTest do
  use ExUnit.Case

  test "test valuation get function" do
    # Function output: Map in form %{{price, side} -> qty, ...}
    # Book_depth = 2, return correct book_depth
    fv         = 99.5
    inventory  = 0
    d_inv      = 0
    qty_limit  = 10
    margin     = 0.1
    book_depth = 2
    tick       = 1
    md = %BBO{
      bids: [{99,  10}, {98,  10}, {97, 10}, {96, 5}, {95, 4}],
      asks: [{100, 10}, {101, 12}, {102, 5}, {103,16}, {104, 22}],
      instrument: "BTCCQ"
    }
    # Function output : Map in form %{{price, side} => qty, ... }
    # Return correct depth of the book
    assert Valuations.get(fv, md, inventory, d_inv, qty_limit, margin, book_depth, tick) == %{
      {99,  :bid } => 10,
      {98,  :bid } => 10,
      {100, :ask } => 10,
      {101, :ask } => 12,
    }

    # case 2
    # Inventory reached hard limit. Oversold
    # Place only bid side order, place bid@99, bid@100
    fv         = 99.5
    inventory  = -10
    d_inv      = -10
    qty_limit  = 10
    margin     = 0.1
    book_depth = 2
    tick       = 1
    assert Valuations.get(fv, md, inventory, d_inv, qty_limit, margin, book_depth, tick) == %{
      {99,   :bid } => 10,
      {100,  :bid } => 10
    }

    # case 3
    # Handle Self-Trading problem
    # inv = 8 and we should move our orders down
    fv         = 99.5
    inventory  = 8
    d_inv      = 8
    qty_limit  = 10
    margin     = 0.1
    book_depth = 3
    tick       = 1
    assert Valuations.get(fv, md, inventory, d_inv, qty_limit, margin, book_depth, tick) == %{
      {98,  :bid} => 10,
      {97,  :bid} => 10,
      {96,  :bid} => 5,
      {99,  :ask} => 10,
      {100, :ask} => 10,
      {101, :ask} => 12,
    }

    # case 4
    # Handle market moves, this will cancel ask@100, place bid@100
    # No need to avoid self trade. Ignore inv adjustment condition and place aggressive order
    fv         = 101
    inventory  = 0
    d_inv      = 0
    qty_limit  = 10
    margin     = 0.1
    book_depth = 3
    tick       = 1
    assert Valuations.get(fv, md, inventory, d_inv, qty_limit, margin, book_depth, tick) == %{
      {98,  :bid} => 10,
      {99,  :bid} => 10,
      {100, :bid} => 10,
      {102, :ask} => 5,
      {103, :ask} => 16,
      {104, :ask} => 22
    }

    # case 5
    # return nothing for empty order book
    fv         = 101
    inventory  = 0
    d_inv      = 0
    qty_limit  = 10
    margin     = 0.1
    book_depth = 6
    tick       = 1
    md = %{bids: [], asks: [], instrument: nil}
    assert Valuations.get(fv, md, inventory, d_inv, qty_limit, margin, book_depth, tick) == %{}

    # case 6
    # Adjust price to prevent osillation
    # Assume we had 99/100 -> fill ask 8 lots -> 100/101 -> fill bid 7 lots > 99/100
    # inv = -1 but d_inv = 7, adjust bid such that -> 99/101
    md = %BBO{
      bids: [{99,  10}, {98,  10}, {97, 10}, {96, 5}, {95, 4}],
      asks: [{100, 10}, {101, 12}, {102, 5}, {103,16}, {104, 22}],
      instrument: "BTCCQ"
    }
    assert Valuations.get(99.5, md, -1, 7, 10, 0.1, 1, 1) == %{
      {99, :bid} => 10,
      {101,:ask} => 12
    }

    # case 7
    assert Valuations.get(99.5, md, 0, 7, 10, 0.1, 1, 1) == %{
      {99, :bid} => 10,
      {101,:ask} => 12
    }

  end
end
