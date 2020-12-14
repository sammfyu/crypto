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
            fv:                nil,
            price_depth:       nil,
            tick:              nil

  @impl true
  def init({gateway_pid, %{} = config}) do
    state = %Algo{
      target_instrument: config.instrument,
      qty_limit:         config.qty_limit,
      book_printing_qty: config.book_printing_qty,
      book_depth:        config.book_depth,
      margin:            config.margin,
      tick:              config.tick,
      gateway_pid:       gateway_pid
    }

    {:ok, state}
  end

  # Store market data and go, if the instrument is the same
  @impl true
  def handle_cast(bbo = %BBO{instrument: instrument}, state = %Algo{target_instrument: target_instrument})
    when instrument == target_instrument
  do
    state = case state.fv do
      nil ->
        %{state | bbo: bbo}
      _ ->
        valuations = Valuations.get(state.fv, bbo, state.inventory, state.qty_limit, state.margin, state.book_depth, state.tick)
        orders = OrderManagement.cancel(valuations, state.orders,  state.gateway_pid)
        state = %{state | orders: orders}

        orders = OrderManagement.place(
          valuations,
          state.orders,
          state.gateway_pid,
          state.book_printing_qty,
          state.target_instrument
        )
        %{state | orders: orders, bbo: bbo}
    end
    {:noreply, state}
  end

  # Handle place and cancel order
  @impl true
  def handle_cast(%Model{fv: fv, instrument: instrument}, state = %{target_instrument: target_instrument})
    when instrument == target_instrument
  do
    IO.puts("FV : #{fv}")
    state = case state.bbo do
      nil ->
        %{state | fv: fv}
      _ ->
        valuations = Valuations.get(fv, state.bbo, state.inventory, state.qty_limit, state.margin, state.book_depth, state.tick)
        orders = OrderManagement.cancel(valuations, state.orders,  state.gateway_pid)
        state = %{state | orders: orders}

        orders = OrderManagement.place(
          valuations,
          state.orders,
          state.gateway_pid,
          state.book_printing_qty,
          state.target_instrument
        )
        %{state | orders: orders, fv: fv}
    end
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

    valuations = Valuations.get(state.fv, state.bbo, state.inventory, state.qty_limit, state.margin, state.book_depth, state.tick)
    orders = OrderManagement.cancel(valuations, state.orders,  state.gateway_pid)
    state = %{state | orders: orders}

    orders = OrderManagement.place(
      valuations,
      state.orders,
      state.gateway_pid,
      state.book_printing_qty,
      state.target_instrument
    )
    state = %{state | orders: orders}

    {:noreply, state}
  end

  # Handle order cancellation
  @impl true
  def handle_cast({:state_update, feedback = %{state: :cancelled}}, state) do
    IO.puts("Order Cancelled")
    orders = Map.delete(state.orders, {feedback.order.price, feedback.order.side})
    state = %{state | orders: orders}

    valuations = Valuations.get(state.fv, state.bbo, state.inventory, state.qty_limit, state.margin, state.book_depth, state.tick)
    orders = OrderManagement.cancel(valuations, state.orders,  state.gateway_pid)
    state = %{state | orders: orders}

    orders = OrderManagement.place(
      valuations,
      state.orders,
      state.gateway_pid,
      state.book_printing_qty,
      state.target_instrument
    )
    state = %{state | orders: orders}

    {:noreply, state}
  end

  # Handle Fully filled Order, update invenotory and remove order from state
  @impl true
  def handle_cast({:fill, %{fill: fill, order: %{active_qty: active_qty} = order}}, state) do
    IO.puts("Order Fully Filled")
    orders = case active_qty do
      0 -> Map.delete(state.orders, {order.price, order.side})
      _ -> Map.put(state.orders, {order.price, order.side}, order)
    end

    inventory = case fill.side do
      :bid  -> state.inventory + fill.qty
      :ask  -> state.inventory - fill.qty
    end

    # Only handle self-oscillation problem when fil messages comes in
    # This makes the valuation function here has extra input  "inv0"
    # This argument is not inside other callback functions , as it is fill specific
    inv0 = state.inventory
    state = %{state | orders: orders, inventory: inventory}
    valuations = Valuations.get(state.fv, state.bbo, state.inventory, state.qty_limit, state.margin, state.book_depth, state.tick, inv0)
    orders = OrderManagement.cancel(valuations, state.orders,  state.gateway_pid)
    state = %{state | orders: orders}

    orders = OrderManagement.place(
      valuations,
      state.orders,
      state.gateway_pid,
      state.book_printing_qty,
      state.target_instrument
    )
    state = %{state | orders: orders}

    {:noreply, state}
  end

  # Handle rejected orders
  @impl true
  def handle_cast({:state_update, feedback = %{state: :filled, code: :too_late_to_cancel}}, state) do
    IO.puts("Order Rejected")
    new_order = %{feedback.order | state: feedback.state, code: feedback.code}
    orders = Map.put(state.orders, {new_order.price, new_order.side}, new_order)
    state = Map.put(state, :orders, orders)

    {:noreply, state}
  end
end
