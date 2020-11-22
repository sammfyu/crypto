defmodule Algo do
  use GenServer


  defstruct target_instrument: nil,
            qty_limit:         nil,
            gateway_pid:       nil,
            book_printing_qty: nil,
            book_depth:        nil,
            margin:            nil,
            orders:            %{},
            inventory:           0,
            bbo:               nil,
            FV:                nil

  @impl true
  def init({gateway_pid, %{} = config}) do
    state = %Algo{
      target_instrument: config.instrument,
      qty_limit:         config.qty_limit,
      book_printing_qty: config.book_printing_qty,
      book_depth:        config.book_depth,
      margin:            config.margin,
      gateway_pid:       gateway_pid
    }

    {:ok, state}
  end

  # Store market data and go , if the instrument is the same
  @impl true
  def handle_cast(bbo = %BBO{instrument: instrument}, state = %Algo{target_instrument: target_instrument}) 
    when instrument == target_instrument
  do
    IO.puts("Update State: BBO")
    new_state = Map.put(state, :bbo, bbo)
    #new_state |> IO.inspect()
    {:noreply, new_state}
  end

  # Handle place and cancel order
  @impl true
  def handle_cast(%Model{FV: fv, instrument: instrument}, state = %{target_instrument: target_instrument}) 
    when instrument == target_instrument
  do
    values = get_values(fv, state.bbo, state.inventory, state.qty_limit)
    values |> IO.inspect()  
    # Order is a list of map in state
    order_price = Map.keys(state.orders)
    order_price |> IO.inspect()
    # If values > margin and there isn't any order at that price, then place order
    
    values 
      |> Enum.filter(fn {_, value, _} -> value > state.margin end)
      |> Enum.filter(fn {price, _, _} -> price not in order_price end)
      |> Enum.map(fn x -> 
           GenServer.cast(state.gateway_pid, {:place, order =  
             %Order{
               price:      elem(x, 0),
               qty:        state.book_printing_qty,
               side:       elem(x, 2),
               instrument: state.target_instrument,
               type:       :limit,
               state:      :pending_active
             }})
           Map.put(state, :orders, Map.put(state.orders, elem(x,0), order))
         end)
    state |> IO.inspect()
    
    # If values < margin and there is an order at the price already, then cancel order
    values
      |> Enum.filter(fn {_, value, _} -> value < state.margin end)
      |> Enum.filter(fn {price, _, _} -> price in order_price end)
      |> Enum.each(fn x ->
        x |> IO.inspect()
        GenServer.cast(state.gateway_pid, {:cancel, %Order{price: elem(x, 0)}})
      end)
    {:noreply, state}
  end

  # If the instrument are not the same, then do nothing
  @impl true
  def handle_cast(%BBO{}, state) do
    {:noreply, state}
  end
    
  # State update for active orders, now order is a list of order
  @impl true
  def handle_cast({:state_update, feedback = %{state: :active}}, state) do
    IO.puts("Order Activated")
    new_order = %Order{feedback.order | state: feedback.state, code: feedback.code}
    order_map = Map.put(state.orders, new_order.price, new_order) 
    new_state = Map.put(state, :orders, order_map) 
    
    {:noreply, new_state}
  end

  # Handle order cancellation
  @impl true
  def handle_cast({:state_update, %{state: :cancelled}}, state) do
    IO.puts("Order Cancelled")
    
    {:noreply, state}
  end

  # Handle Partially Filled Order, update inventory, update values
  @impl true
  def handle_cast({:fill, %{fill: fill, order: order}}, state) do
    IO.puts("Order Filled")
    # Adjust state inventory
    order |> IO.inspect()

    inventory = 
    case fill.side do
      :bid  -> state.inventory + fill.qty
      :ask  -> state.inventory - fill.qty
    end
    state = Map.put(state, :inventory, inventory)
    # Adjust active quantity. Use the price key to update the order.
    new_order = Map.put(state.orders, order.price, order)
    new_state = Map.put(state, :orders, new_order)
    new_state |> IO.inspect()

    {:noreply, new_state}
  end

  # Calculate expected values for each prices
  # Creates a list of tuples {price, value, side}
  def get_values(fv, md, inv, qty_limit) do
    bid_price = 
      md.bids 
        |> Enum.unzip() 
        |> elem(0) 
        |> Enum.map(fn p -> {p, fv - p - inv / qty_limit, :bid} end)

    ask_price = 
      md.asks
        |> Enum.unzip() 
        |> elem(0) 
        |> Enum.map(fn p -> {p, -1 * (fv - p - inv / qty_limit), :ask} end)

    bid_price ++ ask_price
  end 
end

