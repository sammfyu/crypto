defmodule AlgoTest2 do
  use ExUnit.Case




  test "test valuation function" do
    # Test the function
    md = %BBO{
      bids: [{99,  10}, {98,  10}, {97, 10}],
      asks: [{100, 10}, {101, 12}, {102, 5}],
      instrument: "BTCCQ"
    }
    assert Algo.get_values(99.5, md, 0) == [
      {99,  0.5, :bid}, {98,  1.5, :bid}, {97,  2.5, :bid},
      {100, 0.5, :ask}, {101, 1.5, :ask}, {102, 2.5, :ask}
    ]
  end


  test "basic flow Market Making" do
    this   = self()
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


    # FV comes, place order
    GenServer.cast(pid, %Model{
      FV: 99.5,
      instrument: "BTCP"
    })
    assert_receive {:"$gen_cast", 
      {:place, %{qty: 10, price: 99,  side: :bid, type: :limit, instrument: "BTCP"} = order1}}
    assert_receive {:"$gen_cast", 
      {:place, %{qty: 10, price: 98,  side: :bid, type: :limit, instrument: "BTCP"} = order2}}
    assert_receive {:"$gen_cast", 
      {:place, %{qty: 10, price: 97,  side: :bid, type: :limit, instrument: "BTCP"} = order3}}
    assert_receive {:"$gen_cast", 
      {:place, %{qty: 10, price: 100, side: :ask, type: :limit, instrument: "BTCP"} = order4}}
    assert_receive {:"$gen_cast", 
      {:place, %{qty: 10, price: 101, side: :ask, type: :limit, instrument: "BTCP"} = order5}}
    assert_receive {:"$gen_cast", 
      {:place, %{qty: 10, price: 102, side: :ask, type: :limit, instrument: "BTCP"} = order6}}
     
 
    # Gets Feedback
    order = %Order{order1 | order_id: 1, active_qty: 10}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order = %Order{order2 | order_id: 1, active_qty: 10}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order = %Order{order3 | order_id: 1, active_qty: 10}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _
    
    order = %Order{order4 | order_id: 1, active_qty: 10}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _
    
    order = %Order{order5 | order_id: 1, active_qty: 10}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _
    
    order = %Order{order6 | order_id: 1, active_qty: 10}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

   
    # FV comes again, algo recalculate the valuation, do nothing
    GenServer.cast(pid, %Model{
      FV: 99.3,
      instrument: "BTCP"
    })
    refute_receive _


    # Fill message came, inventory changed, store and go
    fill  = %Fill{price: 99, qty: 3, side: :bid, fill_id: 1337, order_id: 1, client_order_id: order.client_order_id}
    order = %Order{order1 | active_qty: 7}
    msg   = {:fill, %{fill: fill, order: order}}
    GenServer.cast(pid, msg)
    refute_receive _ 

    
    #New FV comes, cancel order
    GenServer.cast(pid, %Model{
      FV: 99.1,
      instrument: "BTCP"
    })
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: order_id} = order1}}
  end
end
 





    





