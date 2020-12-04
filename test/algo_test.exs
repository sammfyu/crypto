defmodule AlgoTest do
  use ExUnit.Case

  test "should handle various number of price levels in book" do
    this = self()
    {:ok, pid} = GenServer.start_link(Algo, {this,
      %{instrument: "BTCP", qty_limit: 30, book_printing_qty: 10, book_depth: 3, margin: 0.1}})

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
      %{instrument: "BTCP", qty_limit: 30, book_printing_qty: 10, book_depth: 3, margin: 0.1}})

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
  end

  test "basic flow Market Making" do
    this = self()
    {:ok, pid} = GenServer.start_link(Algo, {this,
      %{instrument: "BTCP", qty_limit: 30, book_printing_qty: 10, book_depth: 3, margin: 0.1}})

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
    assert_receive {:"$gen_cast", {:cancel, %Order{price: 99, state: :pending_cancel, code: nil}}}

    # New fv comes. New cancel is still pending so do nothing.
    GenServer.cast(pid, %Model{
      fv: 99.0,
      instrument: "BTCP"
    })
    refute_receive _


    # Cancel Successful
    msg = {:state_update, %{order: order1, state: :cancelled, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _


    # Market moves
    GenServer.cast(pid, %BBO{
      bids: [{100,  10}, {99,  10}, {98, 10}],
      asks: [{101, 10}, {102, 12}, {103, 5}],
      instrument: "BTCP"
    })
    assert_receive {:"$gen_cast", {:cancel, %Order{price: 97,  state: :pending_cancel}}}

    # Case 1
    # fv comes, cancel ask @100,101; bid@97, place bid@99,100, ask@103
    GenServer.cast(pid, %Model{
      fv: 101,
      instrument: "BTCP"
    })
    assert_receive {:"$gen_cast", {:cancel, %Order{price: 100, state: :pending_cancel}}}
    assert_receive {:"$gen_cast", {:cancel, %Order{price: 101, state: :pending_cancel}}}
    assert_receive {:"$gen_cast", {:place,
      %Order{qty: 10, price: 99, side: :bid, type: :limit, instrument: "BTCP", state: :pending_active} = order8}}
    assert_receive {:"$gen_cast", {:place,
      %Order{qty: 10, price: 100,  side: :bid, type: :limit, instrument: "BTCP", state: :pending_active} = order7}}
    assert_receive {:"$gen_cast", {:place,
      %Order{qty: 10, price: 103, side: :ask, type: :limit, instrument: "BTCP", state: :pending_active} = order9}}

    # Receive feedback, but ask@100 too late to cancel
    # bid@97
    msg    = {:state_update, %{order: order3, state: :cancelled, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    # ask@100, too late to cancel
    order4 = %Order{order4 | order_id: 4, active_qty: 0}
    msg    = {:state_update, %{order: order4, state: :filled, code: :too_late_to_cancel}}
    GenServer.cast(pid, msg)
    # Receive fill
    fill   = %Fill{price: 100, qty: 10, side: :ask, fill_id: 1339, order_id: order4.order_id, client_order_id: order4.client_order_id}
    order4 = %Order{order4 | active_qty: 0}
    msg    = {:fill, %{fill: fill, order: order4}}
    GenServer.cast(pid, msg)
    refute_receive _

    # ask@101
    msg    = {:state_update, %{order: order5, state: :cancelled, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    # bid@100
    order7 = %Order{order7 | order_id: 7, active_qty: 10}
    msg    = {:state_update, %{order: order7, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    # bid@99
    order8 = %Order{order8 | order_id: 8, active_qty: 10}
    msg    = {:state_update, %{order: order8, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    # bid@103
    order9 = %Order{order9 | order_id: 9, active_qty: 10}
    msg    = {:state_update, %{order: order9, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _
  end
end
