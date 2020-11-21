defmodule AlgoTest do
  use ExUnit.Case

  test "basic flow with FV" do
    this       = self()
    {:ok, pid} = GenServer.start_link(Algo, {this, 
      %{instrument: "BTCP", qty: 100, book_printing_qty: 20, book_depth: 5}})


    # Wrong instrument should do nothing
    GenServer.cast(pid, %BBO{
      bid0_price: 99,
      bid1_price: 98,
      bid2_price: 97,
      bid3_price: 96,
      bid4_price: 95,
      ask0_price: 100,
      ask1_price: 101,
      ask2_price: 102,
      ask3_price: 103,
      ask4_price: 104,
      instrument: "BTCCQ"
    })
    refute_receive _

    
    # Record Orderbook into states
    GenServer.cast(pid, %BBO{
      bid0_price: 99,
      bid1_price: 98,
      bid2_price: 97,
      bid3_price: 96,
      bid4_price: 95,
      ask0_price: 100,
      ask1_price: 101,
      ask2_price: 102,
      ask3_price: 103,
      ask4_price: 104,
      instrument: "BTCP"
    })
    refute_receive _


    # FV comes in, calculate the valuation and send orders
    GenServer.cast(pid, %Model{
      FV: 99.5, 
      instrument: "BTCP"
    })
    assert_receive {:"$gen_cast", {:place, %{qty: 20, price: 99,  side: :bid, type: :limit, instrument: "BTCP"} = order1}}
    assert_receive {:"$gen_cast", {:place, %{qty: 20, price: 98,  side: :bid, type: :limit, instrument: "BTCP"} = order2}}
    assert_receive {:"$gen_cast", {:place, %{qty: 20, price: 97,  side: :bid, type: :limit, instrument: "BTCP"} = order3}}
    assert_receive {:"$gen_cast", {:place, %{qty: 20, price: 96,  side: :bid, type: :limit, instrument: "BTCP"} = order4}}
    assert_receive {:"$gen_cast", {:place, %{qty: 20, price: 95,  side: :bid, type: :limit, instrument: "BTCP"} = order5}}
    assert_receive {:"$gen_cast", {:place, %{qty: 20, price: 100, side: :ask, type: :limit, instrument: "BTCP"} = order6}}
    assert_receive {:"$gen_cast", {:place, %{qty: 20, price: 101, side: :ask, type: :limit, instrument: "BTCP"} = order7}}
    assert_receive {:"$gen_cast", {:place, %{qty: 20, price: 102, side: :ask, type: :limit, instrument: "BTCP"} = order8}}
    assert_receive {:"$gen_cast", {:place, %{qty: 20, price: 103, side: :ask, type: :limit, instrument: "BTCP"} = order9}}
    assert_receive {:"$gen_cast", {:place, %{qty: 20, price: 104, side: :ask, type: :limit, instrument: "BTCP"} = order10}}    

    
    # Gets feedback
    order = %Order{order1 | order_id: 1, active_qty: 20}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order = %Order{order2 | order_id: 2, active_qty: 20}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _

    order = %Order{order3 | order_id: 3, active_qty: 20}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _ 

    order = %Order{order4 | order_id: 4, active_qty: 20}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _ 

    order = %Order{order5 | order_id: 5, active_qty: 20}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _ 

    order = %Order{order6 | order_id: 6, active_qty: 20}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _ 
    
    order = %Order{order7 | order_id: 7, active_qty: 20}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _ 
    # Does not react to the same BBO
    order = %Order{order8 | order_id: 8, active_qty: 20}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _ 
    
    order = %Order{order9 | order_id: 9, active_qty: 20}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _ 
    
    order = %Order{order10 | order_id: 10, active_qty: 20}
    msg   = {:state_update, %{order: order, state: :active, code: :ok}}
    GenServer.cast(pid, msg)
    refute_receive _ 
    
   
    # Does not react to the same BBO
    GenServer.cast(pid, %BBO{
      bid0_price: 99,
      bid1_price: 98,
      bid2_price: 97,
      bid3_price: 96,
      bid4_price: 95,
      ask0_price: 100,
      ask1_price: 101,
      ask2_price: 102,
      ask3_price: 103,
      ask4_price: 104,
      instrument: "BTCP"
    })
    refute_receive _

    # Does not react to the same FV
    GenServer.cast(pid, %Model{
      FV: 99.5,
      instrument: "BTCP"})
    refute_receive _

    # Fill message on a price 
    fill  = %Fill{price: 99, qty: 10, side: :bid, fill_id: 1337, order_id: 1, client_order_id: order.client_order_id}
    order = %Order{order1 | active_qty: 10}
    msg = {:fill, %{fill: fill, order: order}}
    GenServer.cast(pid, msg)
    refute_receive _

    # Inventory Changed, Valuation changed
    # New FV comes, valuation changed, Cancel Order at 99
    GenServer.cast(pid, %Model{
      FV: 99.1,
      instrument: "BTCP"
    })
    assert_receive {:"$gen_cast", {:cancel, %Order{order_id: order_id} = order1}}

    
    
    # Cancel Order successful, Update State
    msg = {:state_update, %{order: order1, state: :cancel, code: :ok}}
    GenServer.cast(pid, msg)
    


  end
end





















