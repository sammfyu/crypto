defmodule OrderManagement do
  def cancel(valuations, orders, gateway_pid) do
    orders
    |> Enum.map(fn {key, %Order{state: :active} = order} ->
        order = case Map.get(valuations, key) do
          nil ->
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

  def place(valuations, orders, gateway_pid, book_printing_qty, target_instrument) do
    valuations
    |> Enum.reduce(orders, fn {{price, side} = key, value}, orders ->
      case Map.get(orders, key) do
        nil ->
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
