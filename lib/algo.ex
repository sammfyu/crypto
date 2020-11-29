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
            fv:                nil

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

  # Store market data and go, if the instrument is the same
  @impl true
  def handle_cast(bbo = %BBO{instrument: instrument}, state = %Algo{target_instrument: target_instrument})
    when instrument == target_instrument
  do
    new_state = Map.put(state, :bbo, bbo)

    {:noreply, new_state}
  end

  # Handle place and cancel order
  @impl true
  def handle_cast(%Model{fv: fv, instrument: instrument}, state = %{target_instrument: target_instrument, orders: orders})
    when instrument == target_instrument
  do
    IO.puts("FV : #{fv}")
    state = %{state | fv: fv}
    valuations = Fun.get_values(fv, state.bbo, state.inventory, state.qty_limit)
    state = Fun.cancel(orders, valuations, state)
    state = Fun.place(orders, valuations, state)
    
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
    new_order = %{feedback.order | state: feedback.state, code: feedback.code}
    orders = Map.put(state.orders, {new_order.price, new_order.side}, new_order)
    state = %{state | orders: orders}

    valuations = Fun.get_values(state.fv, state.bbo, state.inventory, state.qty_limit)
    state = Fun.cancel(orders, valuations, state)
    state = Fun.place(orders, valuations, state)

    {:noreply, state}
  end

  # Handle order cancellation
  @impl true
  def handle_cast({:state_update, feedback = %{state: :cancelled}}, state) do
    IO.puts("Order Cancelled")
    orders = Map.delete(state.orders, {feedback.order.price, feedback.order.side})
    state = %{state | orders: orders}

    valuations = Fun.get_values(state.fv, state.bbo, state.inventory, state.qty_limit)
    state = Fun.cancel(state.orders, valuations, state)
    state = Fun.place(state.orders, valuations, state)
    
    {:noreply, state}
  end

  # Handle Fully filled Order, update invenotory and remove order from state
  @impl true
  def handle_cast({:fill, %{fill: fill, order: %{active_qty: active_qty} = order}}, state) do
    IO.puts("Order Fully Filled")
    inventory = case fill.side do
      :bid  -> state.inventory + fill.qty
      :ask  -> state.inventory - fill.qty
    end
    state = Map.put(state, :inventory, inventory)

    orders = case active_qty == 0 do
      :true -> Map.delete(state.orders, {order.price, order.side})
      :false-> Map.put(state.orders, {order.price, order.side}, order)  
    end
    state = Map.put(state, :orders, orders)

    {:noreply, state}
  end
  
  # Handle rejected orders
  @impl true
  def handle_cast({:state_update, feedback = %{state: :filled, code: :too_late_to_cancel}}, state) do
    IO.puts("Order Rejected")
    new_order = %{feedback.order | state: feedback.state, code: feedback.code}
    order_map = Map.put(state.orders, {new_order.price, new_order.side}, new_order)
    new_state = Map.put(state, :orders, order_map)

    {:noreply, new_state}
  end

end
