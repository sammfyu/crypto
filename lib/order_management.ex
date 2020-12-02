defmodule Order_Management do
  def cancel(valuations, orders, margin, gateway_pid) do
    IO.puts("Cancelling Order")
    orders = 
      orders
      # Cancel orders if the price is in the valuation map or the price is at the wrong side of valuationn
      |> Enum.map(fn {{price, side}, %Order{state: order_state} = order} -> 
        order = case {
          order_state, 
          price in Map.keys(valuations),
          side == get_in(valuations, [price, :side])
        } 
        do
          {:active, false, _} ->
            order = %{order | state: :pending_cancel}
            GenServer.cast(gateway_pid, {:cancel, order})
            order
          {:active, _, false} ->
            order = %{order | state: :pending_cancel}
            GenServer.cast(gateway_pid, {:cancel, order})
            order
          _ ->
            order
        end
        {{price, side}, order}
      end)
      # Cancel Orders with valuation below state margin
      |> Enum.map(fn {{price, side}, %Order{state: order_state} = order} -> 
        order = case {
          order_state, 
          get_in(valuations, [price, :v_bid]) <= margin, 
          get_in(valuations, [price, :v_ask]) <= margin
        } 
        do
          {:active, true, true} ->
            order = %{order | state: :pending_cancel}
            GenServer.cast(gateway_pid, {:cancel, order})
            order
          _ ->
            order
        end
        {{price, side}, order}
      end)
      |> Map.new
    orders
  end

  def place(valuations, orders, margin, gateway_pid, book_printing_qty, target_instrument) do
    IO.puts("Place Order")
    # Place order if
    # 1. There isn't existing order at {price, side}
    # 2. Place order if valuation is lower than state margin according to the side
    orders =
      valuations
      |> Enum.reduce(%{}, fn {price, %{v_bid: v_bid, v_ask: v_ask, side: side}}, acc -> 
        case {
          {price, side} in Map.keys(orders), 
          v_bid > margin, 
          v_ask > margin, 
          side
        } 
        do
          {false, true, _, :bid} ->
            order = %Order{
              price:      price,
              qty:        book_printing_qty,
              side:       :bid,
              instrument: target_instrument,
              type:       :limit,
              state:      :pending_active
            }
            GenServer.cast(gateway_pid, {:place, order})
            Map.put(acc, {price, side}, order)
          {false, _, true, :ask} ->
            order = %Order{
              price:      price,
              qty:        book_printing_qty,
              side:       :ask,
              instrument: target_instrument,
              type:       :limit,
              state:      :pending_active
            }
            GenServer.cast(gateway_pid, {:place, order})
            Map.put(acc, {price, side}, order)
          {true, _, _, _} ->
            Map.put(acc, {price, side}, orders[{price, side}])
          _ -> 
            acc
        end
      end)
    orders
  end

end
