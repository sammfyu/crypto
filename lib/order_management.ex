defmodule OrderManagement do
  def cancel(valuations, orders, margin, gateway_pid, inventory, qty_limit) do
    orders
    |> Enum.map(fn
      {{_, side} = key, %Order{state: :active} = order} ->
        order = case Map.get(valuations, key) do
          value when is_nil(value) or value <= margin or inventory <= -qty_limit and side == :ask ->
            order = %{order | state: :pending_cancel}
            GenServer.cast(gateway_pid, {:cancel, order})
            order
          value when is_nil(value) or value <= margin or inventory >= qty_limit and side == :bid ->
            order = %{order | state: :pending_cancel}
            GenServer.cast(gateway_pid, {:cancel, order})
            order
          _ ->
            order
        end
        {key, order}
      {key, %Order{} = order} ->
        {key, order}
    end)
    |> Map.new
  end

  def place(valuations, orders, margin, gateway_pid, book_depth, {bid_depth, ask_depth}, book_printing_qty, target_instrument, inventory, qty_limit) do
    valuations
    |> Enum.reduce(orders, fn {{price, side} = key, value}, orders ->
      case {
        Map.get(orders, key),
        Enum.count(orders, fn {{_,s}, %{state: state}} -> s == side and state != :pending_cancel end),
      }
      do
        {nil, count} when value > margin and count < book_depth and price > bid_depth and price < ask_depth ->
          order = %Order{
            price:      price,
            qty:        book_printing_qty,
            side:       side,
            instrument: target_instrument,
            type:       :limit,
            state:      :pending_active
          }
          GenServer.cast(gateway_pid, {:place, order})
          Map.put(orders, {price, side}, order)
        # Place order only on the bid side, becaise we sold too much
        {nil, count} when value > margin and count < book_depth and inventory <= -qty_limit and side == :bid and price > bid_depth and price < ask_depth ->
          order = %Order{
            price:      price,
            qty:        book_printing_qty,
            side:       side,
            instrument: target_instrument,
            type:       :limit,
            state:      :pending_active
          }
          GenServer.cast(gateway_pid, {:place, order})
          Map.put(orders, {price, side}, order)
        # Place order only on the ask side, because we bought too much
        {nil, count} when value > margin and count < book_depth and inventory >= qty_limit and side == :ask and price > bid_depth and price < ask_depth ->
          order = %Order{
            price:      price,
            qty:        book_printing_qty,
            side:       side,
            instrument: target_instrument,
            type:       :limit,
            state:      :pending_active
          }
          GenServer.cast(gateway_pid, {:place, order})
          Map.put(orders, {price, side}, order)
        _ ->
          orders
      end
    end)
  end
end
