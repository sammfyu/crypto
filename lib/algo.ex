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
  def handle_cast(%Model{FV: fv, instrument: instrument}, state = %{target_instrument: target_instrument})
    when instrument == target_instrument
  do
    values = get_values(fv, state.bbo, state.inventory, state.qty_limit)
    order_price = Map.keys(state.orders)
    order = %{
      price:           nil,
      qty:             state.book_printing_qty,
      active_qty:      nil,
      side:            nil,
      instrument:      state.target_instrument,
      type:            :limit,
      state:           nil,
      code:            nil,
      order_id:        nil,
      client_order_id: nil,
      account:         nil,
      market:          nil
    }

    # New implementation of cancellation algo with state update
    # 1. Cancel order if order_price not in values.price
    values_price = Enum.map(values, fn x -> elem(x, 0) end)
    cancel       = Enum.filter(order_price, fn x -> x not in values_price end)

    Enum.each(cancel, fn x ->
      GenServer.cast(state.gateway_pid, {:cancel, %{
        price: state.orders[x].price,
        state: :pending_cancel,
        code:  nil
      }})
    end)

    order_list =
      Enum.into(cancel, state.orders, fn x ->
        {x, %{state.orders[x] | state: :pending_cancel, code: nil}}
      end)
    state      = Map.put(state, :orders, order_list)

    # 2. Cancel order according to Bid Ask valuation
    # Cancel Bid
    cancel =
      values
        |>  Enum.filter(fn {price, _, _, _} -> price in order_price end)
        |>  Enum.filter(fn {_, v_bid, _, _} -> v_bid <= state.margin end)
        |>  Enum.filter(fn {_, _, _,  side} -> side == :bid end)
        |>  Enum.filter(fn {price, _, _, _} -> :pending_cancel != state.orders[price][:state] end)
    Enum.each(cancel, fn x ->
      GenServer.cast(state.gateway_pid, {:cancel, %{
        price: state.orders[elem(x,0)].price,
        state: :pending_cancel,
        code:  nil
      }})
      end)

    order_list =
      Enum.into(cancel, state.orders, fn x -> {elem(x, 0),
        %{state.orders[elem(x, 0)] | state: :pending_cancel, code: nil}}
      end)
    state = Map.put(state, :orders, order_list)

    # Cancel Ask
    cancel =
      values
      |>  Enum.filter(fn {price, _, _, _} -> price in order_price end)
      |>  Enum.filter(fn {_, _, v_ask, _} -> v_ask <= state.margin end)
      |>  Enum.filter(fn {_, _, _,  side} -> side == :ask end)
      |>  Enum.filter(fn {price, _, _, _} -> :pending_cancel != Map.get(state.orders[price], :state) end)
    Enum.each(cancel, fn x ->
      GenServer.cast(state.gateway_pid, {:cancel, %{
        price: state.orders[elem(x,0)].price,
        state: :pending_cancel,
        code:  nil
      }})
    end)

    order_list =
      Enum.into(cancel, state.orders, fn x -> {elem(x, 0),
        %{state.orders[elem(x, 0)] | state: :pending_cancel, code: nil}}
      end)
    state = Map.put(state, :orders, order_list)

    # 3. Cancel Order if the order is at the wrong side
    cancel =
      values
        |>  Enum.filter(fn {price, _, _, _   } -> price in order_price end)
        |>  Enum.filter(fn {price, _, _, side} -> side != Map.get(state.orders[price], :side) end)
        |>  Enum.filter(fn {price, _, _,    _} -> :pending_cancel != Map.get(state.orders[price], :state) end)
    Enum.each(cancel, fn x ->
      GenServer.cast(state.gateway_pid, {:cancel, %{
        price: state.orders[elem(x,0)].price,
        state: :pending_cancel,
        code:  nil
      }})
      end)

    order_list =
      Enum.into(cancel, state.orders, fn x -> {elem(x, 0),
        %{state.orders[elem(x, 0)] | state: :pending_cancel, code: nil}}
      end)
    state = Map.put(state, :orders, order_list)

    # Placing order
    # If values > margin and there isn't any order at that price, then place order
    # Bid case
    place =
    values
    |>  Enum.filter(fn {_, v_bid, _, _} -> v_bid > state.margin end)
    |>  Enum.filter(fn {price, _, _, _} -> :active != state.orders[price][:state] end)
    |>  Enum.filter(fn {price, _, _, _} -> :pending_active != state.orders[price][:state] end)
    Enum.each(place, fn x ->
      GenServer.cast(state.gateway_pid, {:place,
        %{order | price: elem(x, 0), side: elem(x, 3), state: :pending_active}})
    end)

    order_list =
      Enum.into(place, state.orders, fn x -> {elem(x, 0),
        %{order | price: elem(x, 0), side: elem(x, 3), state: :pending_active}}
      end)
    state = Map.put(state, :orders, order_list)

    #Ask Case
    place =
    values
    |>  Enum.filter(fn {_, _, v_ask, _} -> v_ask > state.margin end)
    |>  Enum.filter(fn {price, _, _, _} -> :active != state.orders[price][:state] end)
    |>  Enum.filter(fn {price, _, _, _} -> :pending_active != state.orders[price][:state] end)
    Enum.each(place, fn x ->
      GenServer.cast(state.gateway_pid, {:place,
        %{order | price: elem(x, 0), side: elem(x, 3), state: :pending_active}})
    end)

    order_list =
      Enum.into(place, state.orders, fn x -> {elem(x, 0),
        %{order | price: elem(x, 0), side: elem(x, 3), state: :pending_active}}
      end)
    state = Map.put(state, :orders, order_list)

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
    new_order = %{feedback.order | state: feedback.state, code: feedback.code}
    order_map = Map.put(state.orders, new_order.price, new_order)
    new_state = Map.put(state, :orders, order_map)

    {:noreply, new_state}
  end

  # Handle order cancellation
  @impl true
  def handle_cast({:state_update, feedback = %{state: :cancelled}}, state) do
    order_map = Map.delete(state.orders, feedback.order.price)
    new_state = Map.put(state, :orders, order_map)

    {:noreply, new_state}
  end

  # Handle Fill filled Order, update invenotory and remove order from state
  @impl true
  def handle_cast({:fill, feedback = %{fill: fill, order: %{active_qty: 0}}}, state) do
    inventory =
    case fill.side do
      :bid  -> state.inventory + fill.qty
      :ask  -> state.inventory - fill.qty
    end
    state = Map.put(state, :inventory, inventory)

    order_map = Map.delete(state.orders, feedback.order.price)
    new_state = Map.put(state, :orders, order_map)

    {:noreply, new_state}
  end

  # Handle Partially Filled Order, update inventory, update values
  @impl true
  def handle_cast({:fill, %{fill: fill, order: order}}, state) do
    # Adjust state inventory
    inventory =
    case fill.side do
      :bid  -> state.inventory + fill.qty
      :ask  -> state.inventory - fill.qty
    end
    state = Map.put(state, :inventory, inventory)
    # Adjust active quantity. Use the price key to update the order.
    new_order = Map.put(state.orders, order.price, order)
    new_state = Map.put(state, :orders, new_order)

    {:noreply, new_state}
  end

  # Handle rejected orders
  @impl true
  def handle_cast({:state_update, feedback = %{state: :filled, code: :too_late_to_cancel}}, state) do
    new_order = %{feedback.order | state: feedback.state, code: feedback.code}
    order_map = Map.put(state.orders, new_order.price, new_order)
    new_state = Map.put(state, :orders, order_map)

    {:noreply, new_state}
  end

  # Calculate expected values for each prices
  # Creates a list of tuples {price, value_bid, value_ask, side}
  def get_values(fv, %{bids: bids, asks: asks}, inv, qty_limit) do
    bid_valuation = Enum.map(bids, fn {p, _} ->
      value = fv - p - inv / qty_limit
      {p, value, -1 * value, :bid}
    end)

    ask_valuation = Enum.map(asks, fn {p, _} ->
      value = fv - p - inv / qty_limit
      {p, value, -1 * value, :ask}
    end)

    bid_valuation ++ ask_valuation
  end
end
