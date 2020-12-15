defmodule AlgoTest do
  use ExUnit.Case

  test "should handle various number of price levels in book" do
    this = self()
    {:ok, pid} = GenServer.start_link(Algo, {this,
      %{instrument: "BTCP", qty_limit: 30, book_printing_qty: 10, book_depth: 3, margin: 0.1, tick: 1}})

    GenServer.cast(pid, %BBO{
      bids: [],
      asks: [{100, 10}, {101, 12}, {102, 5}, {103, 12}],
      instrument: "BTCP"
    })
    refute_receive _

    GenServer.cast(pid, %Model{
      fv: 99.5,
      instrument: "BTCP"
    })

    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 100, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active}}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 101, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active}}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 102, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active}}}
    refute_receive _
  end

  test "should handle bbo vs model reordering" do
    this = self()
    {:ok, pid} = GenServer.start_link(Algo, {this,
      %{instrument: "BTCP", qty_limit: 30, book_printing_qty: 10, book_depth: 3, margin: 0.1, tick: 1}})

    GenServer.cast(pid, %Model{
      fv: 99.5,
      instrument: "BTCP"
    })
    refute_receive _

    GenServer.cast(pid, %BBO{
      bids: [{99,  10}, {98,  10}, {97, 10}],
      asks: [{100, 10}, {101, 12}, {102, 5}],
      instrument: "BTCP"
    })

    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 99,  side: :bid, type: :limit, instrument: "BTCP", state: :pending_active}}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 98,  side: :bid, type: :limit, instrument: "BTCP", state: :pending_active}}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 97,  side: :bid, type: :limit, instrument: "BTCP", state: :pending_active}}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 100, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active}}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 101, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active}}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 102, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active}}}
    refute_receive _

    GenServer.cast(pid, %BBO{
      bids: [{102, 2}, {101, 5}, {100, 20}, {99, 5}, {98, 6}],
      asks: [{103, 10}, {104, 12}, {105, 5}, {106, 12}, {107,20}],
      instrument: "BTCP"
    })



  end

  test "handles qty hard-limit" do
    this = self()
    {:ok, pid} = GenServer.start_link(Algo, {this,
      %{instrument: "BTCP", qty_limit: 10, book_printing_qty: 10, book_depth: 3, margin: 0.1, tick: 1}})

    GenServer.cast(pid, %Model{
      fv: 99.5,
      instrument: "BTCP"
    })
    refute_receive _

    GenServer.cast(pid, %BBO{
      bids: [{99,  10}, {98,  10}, {97, 10}],
      asks: [{100, 10}, {101, 12}, {102, 5}],
      instrument: "BTCP"
    })

    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 99,  side: :bid, type: :limit, instrument: "BTCP", state: :pending_active} = order1}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 98,  side: :bid, type: :limit, instrument: "BTCP", state: :pending_active} = order2}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 97,  side: :bid, type: :limit, instrument: "BTCP", state: :pending_active} = order3}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 100, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active} = order4}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 101, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active} = order5}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 102, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active} = order6}}
    refute_receive _

    order1 = %Order{order1 | order_id: 1, active_qty: 10}
    msg    = {:state_update, %{order: order1, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order2 = %Order{order2 | order_id: 2, active_qty: 10}
    msg    = {:state_update, %{order: order2, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order3 = %Order{order3 | order_id: 3, active_qty: 10}
    msg    = {:state_update, %{order: order3, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order4 = %Order{order4 | order_id: 4, active_qty: 10}
    msg    = {:state_update, %{order: order4, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order5 = %Order{order5 | order_id: 5, active_qty: 10}
    msg    = {:state_update, %{order: order5, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order6 = %Order{order6 | order_id: 6, active_qty: 10}
    msg    = {:state_update, %{order: order6, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _


    # Sell too much and reached to hard-limit, algo places only bid order
    fill  = %Fill{price: 100, qty: 10, side: :ask, fill_id: 1337, order_id: 4, client_order_id: order4.client_order_id}
    order4 = %Order{order4 | active_qty: 0, state: :active}
    msg   = {:fill, %{fill: fill, order: order4}}
    GenServer.cast(pid, msg)
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: 5, price: 101, side: :ask}}}
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: 6, price: 102, side: :ask}}}
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: 3, price: 97,  side: :bid}}}
    refute_receive _

  end

  # This test handles the problem of self-trading due to inventory changes
  # Set soft-limit to 10 lots and book_depth to 1 level, which only quotes best bid and ask, margin is still 0.1
  # If inventory is greater or equal to 6 lots, the valuation tells us to cancel bid@99, ask@100 and place bid@98, ask@99
  # But here I want the algo not to place ask@99 otherwise it will cause self-trading since market did not move at all
  test "handles avoiding self trading problem due to inventory" do
    this = self()
    {:ok, pid} = GenServer.start_link(Algo, {this,
      %{instrument: "BTCP", qty_limit: 10, book_printing_qty: 10, book_depth: 1, margin: 0.1, tick: 1}})

    GenServer.cast(pid, %Model{
      fv: 99.5,
      instrument: "BTCP"
    })
    refute_receive _

    GenServer.cast(pid, %BBO{
      bids: [{99,  10}, {98,  10}, {97, 10}],
      asks: [{100, 10}, {101, 12}, {102, 5}],
      instrument: "BTCP"
    })
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 99,  side: :bid, type: :limit, instrument: "BTCP", state: :pending_active} = order1}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 100, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active} = order2}}

    order1 = %Order{order1 | order_id: 1, active_qty: 10}
    msg    = {:state_update, %{order: order1, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order2 = %Order{order2 | order_id: 2, active_qty: 10}
    msg    = {:state_update, %{order: order2, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    # Fill message trigger, we only want to cancel bid@99 but we do not want place ask@99
    fill  = %Fill{price: 99, qty: 6, side: :bid, fill_id: 1337, order_id: 1, client_order_id: order1.client_order_id}
    order1 = %Order{order1 | active_qty: 4, state: :active}
    msg   = {:fill, %{fill: fill, order: order1}}
    GenServer.cast(pid, msg)
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: 1, price: 99}}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 98,  side: :bid, type: :limit, instrument: "BTCP", state: :pending_active}}}
    refute_receive _
  end

  test "handles avoiding self trading problem due to inventory with more depth" do
    this = self()
    {:ok, pid} = GenServer.start_link(Algo, {this,
      %{instrument: "BTCP", qty_limit: 10, book_printing_qty: 10, book_depth: 2, margin: 0.1, tick: 1}})

    GenServer.cast(pid, %Model{
      fv: 99.5,
      instrument: "BTCP"
    })
    refute_receive _

    GenServer.cast(pid, %BBO{
      bids: [{99,  10}, {98,  10}, {97, 10}],
      asks: [{100, 10}, {101, 12}, {102, 5}],
      instrument: "BTCP"
    })
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 99,  side: :bid, type: :limit, instrument: "BTCP", state: :pending_active} = order1}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 98,  side: :bid, type: :limit, instrument: "BTCP", state: :pending_active} = order2}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 100, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active} = order3}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 101, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active} = order4}}

    order1 = %Order{order1 | order_id: 1, active_qty: 10}
    msg    = {:state_update, %{order: order1, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order2 = %Order{order2 | order_id: 2, active_qty: 10}
    msg    = {:state_update, %{order: order2, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order3 = %Order{order3 | order_id: 3, active_qty: 10}
    msg    = {:state_update, %{order: order3, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order4 = %Order{order4 | order_id: 4, active_qty: 10}
    msg    = {:state_update, %{order: order4, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    fill  = %Fill{price: 100, qty: 7, side: :ask, fill_id: 1337, order_id: 3, client_order_id: order3.client_order_id}
    order3 = %Order{order3 | active_qty: 3, state: :active}
    msg   = {:fill, %{fill: fill, order: order3}}
    GenServer.cast(pid, msg)
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: 3, price: 100}}}
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: 2, price: 98}}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 102,  side: :ask, type: :limit, instrument: "BTCP", state: :pending_active}}}
    refute_receive _
  end

  test "Handle Self-Osillation Problem" do
    this = self()
    {:ok, pid} = GenServer.start_link(Algo, {this,
      %{instrument: "BTCP", qty_limit: 10, book_printing_qty: 10, book_depth: 1, margin: 0.1, tick: 1}})

    GenServer.cast(pid, %BBO{
      bids: [{99,  10}, {98,  10}, {97, 10}],
      asks: [{100, 10}, {101, 12}, {102, 5}],
      instrument: "BTCP"
    })
    refute_receive _

    GenServer.cast(pid, %Model{
      fv: 99.5,
      instrument: "BTCP"
    })
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 99,  side: :bid, type: :limit, instrument: "BTCP", state: :pending_active} = order1}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 100, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active} = order2}}
    refute_receive _

    order1 = %Order{order1 | order_id: 1, active_qty: 10}
    msg    = {:state_update, %{order: order1, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order2 = %Order{order2 | order_id: 2, active_qty: 10}
    msg    = {:state_update, %{order: order2, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    fill   = %Fill{price: 100, qty: 8, side: :ask, fill_id: 1337, order_id: 2, client_order_id: order2.client_order_id}
    order2 = %Order{order2 | active_qty: 2, state: :active}
    msg    = {:fill, %{fill: fill, order: order2}}
    GenServer.cast(pid, msg)
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: 1, price: 99,  side: :bid}}}
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: 2, price: 100, side: :ask}}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 101, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active}}}

    refute_receive _

  end



  test "basic flow Market Making" do
    this = self()
    {:ok, pid} = GenServer.start_link(Algo, {this,
      %{instrument: "BTCP", qty_limit: 30, book_printing_qty: 10, book_depth: 3, margin: 0.1, tick: 1}})

    # Do not store MD for the wrong instrument
    GenServer.cast(pid, %BBO{
      bids: [{99,  10}, {98,  10}, {97, 10}],
      asks: [{100, 10}, {101, 12}, {102, 5}],
      instrument: "BTCCQ"
    })
    refute_receive _

    # Receive MD and store it
    GenServer.cast(pid, %BBO{
      bids: [{99,  10}, {98,  10}, {97, 10}],
      asks: [{100, 10}, {101, 12}, {102, 5}],
      instrument: "BTCP"
    })
    refute_receive _

    # fv comes, place order
    GenServer.cast(pid, %Model{
      fv: 99.5,
      instrument: "BTCP"
    })
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 99,  side: :bid, type: :limit, instrument: "BTCP", state: :pending_active} = order1}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 98,  side: :bid, type: :limit, instrument: "BTCP", state: :pending_active} = order2}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 97,  side: :bid, type: :limit, instrument: "BTCP", state: :pending_active} = order3}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 100, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active} = order4}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 101, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active} = order5}}
    assert_receive {:"$gen_cast",
      {:place, %Order{qty: 10, price: 102, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active} = order6}}
    refute_receive _


    # Gets Feedback
    order1 = %Order{order1 | order_id: 1, active_qty: 10}
    msg    = {:state_update, %{order: order1, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order2 = %Order{order2 | order_id: 2, active_qty: 10}
    msg    = {:state_update, %{order: order2, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order3 = %Order{order3 | order_id: 3, active_qty: 10}
    msg    = {:state_update, %{order: order3, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order4 = %Order{order4 | order_id: 4, active_qty: 10}
    msg    = {:state_update, %{order: order4, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order5 = %Order{order5 | order_id: 5, active_qty: 10}
    msg    = {:state_update, %{order: order5, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order6 = %Order{order6 | order_id: 6, active_qty: 10}
    msg    = {:state_update, %{order: order6, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    # fv comes again, algo recalculate the valuation, do nothing
    GenServer.cast(pid, %Model{
      fv: 99.3,
      instrument: "BTCP"
    })
    refute_receive _


    # Fill message came, inventory changed, store and go
    fill  = %Fill{price: 99, qty: 3, side: :bid, fill_id: 1337, order_id: 1, client_order_id: order1.client_order_id}
    order1 = %Order{order1 | active_qty: 7, state: :active}
    msg   = {:fill, %{fill: fill, order: order1}}
    GenServer.cast(pid, msg)
    refute_receive _


    #New fv comes, cancel order
    GenServer.cast(pid, %Model{
      fv: 99.1,
      instrument: "BTCP"
    })
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: 1, price: 99, side: :bid}}}
    refute_receive _
    # New fv comes. New cancel is still pending so do nothing.
    GenServer.cast(pid, %Model{
      fv: 99.0,
      instrument: "BTCP"
    })
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: 6, price: 102, side: :ask}}}
    assert_receive {:"$gen_cast", {:place,
      %Order{qty: 10, price: 99, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active} = order7}}
    refute_receive _


    # Cancel bid@99 Successful
    msg = {:state_update, %{order: order1, state: :cancelled, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    # Cancel ask@102 Successful and Order ask@99 active
    msg = {:state_update, %{order: order6, state: :cancelled, code: :ok}}
    GenServer.cast(pid, msg)
    order7 = %Order{order7 | order_id: 7, active_qty: 10}
    msg    = {:state_update, %{order: order7, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _



    # This test is based on old design, not used for now
    # Market moves
    # Cancel bid@97 because price is out of orderbook
    # Cancel ask@100 because market moved up, cancel asap
    # Place  ask@103 because we follow book depth of 3
    GenServer.cast(pid, %BBO{
      bids: [{100,  10}, {99,  10}, {98, 10}],
      asks: [{101, 10}, {102, 12}, {103, 5}],
      instrument: "BTCP"
    })
    assert_receive {:"$gen_cast", {:cancel, %Order{price: 97,  side: :bid, state: :pending_cancel}}}
    refute_receive _


    # FV comes,  place bid@99, bid@100
    # However bid@100 too late to cancel
    GenServer.cast(pid, %Model{
      fv: 101,
      instrument: "BTCP"
    })
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: 7, price: 99,  side: :ask}}}
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: 4, price: 100, side: :ask}}}
    assert_receive {:"$gen_cast", {:place,
      %Order{qty: 10, price: 99 , side: :bid, type: :limit, instrument: "BTCP", state: :pending_active} = order8}}
    assert_receive {:"$gen_cast", {:place,
      %Order{qty: 10, price: 100, side: :bid, type: :limit, instrument: "BTCP", state: :pending_active} = order9}}
    assert_receive {:"$gen_cast", {:place,
      %Order{qty: 10, price: 102, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active} = order10}}
    assert_receive {:"$gen_cast", {:place,
      %Order{qty: 10, price: 103, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active} = order11}}
    refute_receive _

    # bid@97 cancel success
    msg    = {:state_update, %{order: order3, state: :cancelled, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    # Receive feedback, ask@99 cancelled.
    msg    = {:state_update, %{order: order7, state: :cancelled, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    # Receive feedback, but ask@100 too late to cancel
    order4 = %Order{order4 | order_id: 4, active_qty: 0}
    msg    = {:state_update, %{order: order4, state: :filled, code: :too_late_to_cancel}}
    GenServer.cast(pid, msg)

    # Receive full-fill on ask@100, valuation evaluates cancellation at ask@101, no order place in 100@bid
    fill   = %Fill{price: 100, qty: 10, side: :ask, fill_id: 1339, order_id: order4.order_id, client_order_id: order4.client_order_id}
    order4 = %Order{order4 | active_qty: 0}
    msg    = {:fill, %{fill: fill, order: order4}}
    GenServer.cast(pid, msg)
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: 5, price: 101, side: :ask}}}
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: 2, price:  98, side: :bid}}}
    refute_receive _

    # bid@98 and ask@101 cancel confirmed
    msg    = {:state_update, %{order: order2, state: :cancelled, code: :ok}}
    GenServer.cast(pid, msg)
    msg    = {:state_update, %{order: order5, state: :cancelled, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    # bid@99, bid@100 activate confirmed, but bid@100 has to be cancelled because fill does not allow self-trade at bid@10
    order8 = %Order{order8 | order_id: 8, active_qty: 10}
    msg    = {:state_update, %{order: order8, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    order9 = %Order{order9 | order_id: 9, active_qty: 10}
    msg    = {:state_update, %{order: order9, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: 9, price: 100, side: :bid}}}
    refute_receive _

    # ask@102, 103 activate confirmed
    order10 = %Order{order10 | order_id: 10, active_qty: 10}
    msg    = {:state_update, %{order: order10, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    order11 = %Order{order11 | order_id: 11, active_qty: 10}
    msg    = {:state_update, %{order: order11, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    end
end
