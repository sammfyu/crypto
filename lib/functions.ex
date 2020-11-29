defmodule Fun do
  def cancel(orders, valuations, state) do
    
    IO.puts("Cancelling Order")
    orders = 
      orders
      |> Enum.map(fn {{price, side}, %Order{state: order_state} = order} -> 
        order = case {order_state, price in Map.keys(valuations)} do
          {:active, false} ->
            order = %{order | state: :pending_cancel}
            GenServer.cast(state.gateway_pid, {:cancel, order})
            order
          _ ->
            order
        end
        {{price, side}, order}
      end)
      |> Map.new
      |> Enum.map(fn {{price, side}, %Order{state: order_state} = order} -> 
        order = case {
          order_state, 
          get_in(valuations, [price, :v_bid]) <= state.margin, 
          get_in(valuations, [price, :v_ask]) <= state.margin
        } do
          {:active, true, true} ->
            order = %{order | state: :pending_cancel}
            GenServer.cast(state.gateway_pid, {:cancel, order})
            order
          _ ->
            order
        end
        {{price, side}, order}
      end)
      |> Enum.map(fn {{price, side}, %Order{state: order_state} = order} -> 
        order = case {order_state, side == get_in(valuations, [price, :side])} do
          {:active, false} ->
            order = %{order | state: :pending_cancel}
            GenServer.cast(state.gateway_pid, {:cancel, order})
            order
          _ ->
            order
        end
        {{price, side}, order}
      end)
      |> Map.new
    %{state | orders: orders} 
  end

  def place(orders, valuations, state) do
    IO.puts("Place Order")
    orders =
      valuations
      |> Enum.map(fn {price, %{v_bid: v_bid, v_ask: v_ask, side: side}} -> 
        order = case {
          {price, side} in Map.keys(orders), 
          v_bid > state.margin, 
          v_ask > state.margin, 
          side
        } do
          {false, true, _, :bid} ->
            order = %Order{
              price:      price,
              qty:        state.book_printing_qty,
              side:       :bid,
              instrument: state.target_instrument,
              type:       :limit,
              state:      :pending_active
            }
            GenServer.cast(state.gateway_pid, {:place, order})
            order
          {false, _, true, :ask} ->
            order = %Order{
              price:      price,
              qty:        state.book_printing_qty,
              side:       :ask,
              instrument: state.target_instrument,
              type:       :limit,
              state:      :pending_active
            }
            GenServer.cast(state.gateway_pid, {:place, order})
            order
          {true, _, _, _} ->
            state.orders[{price, side}]
          _ -> nil
        end
          {{price, side}, order}  
      end)
      |> Enum.reject(fn{_, order} -> is_nil(order) end)
      |> Map.new
    %{state | orders: orders}
  end

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
    |> Enum.map(fn {price, v0, v1, v2} -> {price, %{v_bid: v0, v_ask: v1, side: v2}} end)
    |> Map.new
  end

end
