defmodule Valuations do
  # In here I took a step back to figure out all the logic to be done in this function.
  # It handles empty orderbook, self-trading, valuation, book depth and hard-limit problems.
  # --------------Description-------------
  # 1. Compute best_bid and best_ask for self-trade condition use
  # 2. Concatenate both bid and ask lists from the order book
  # 3. Calculate values for bid and ask
  # 4. Determine sides by comparing v_bid and v_ask
  # 5. Use Enum.reduce to add favourable orders into new_list
  # by checking margin and self-trade condition
  # 6. Sort the list by values in ascending order so that it becomes
  # easier to add orders in the next Enum.reduce
  # 7. Use Enum.reduce to add favourable orders into new_list
  # by checking book depth on each side and checking hard limit
  # 8. Return map in form  %{{price, side}, qty}
  def get(fv, %{bids: bids, asks: asks}, inv, lim, margin, depth) do
    best_bid = case bids do
      [] -> -1  # Avoid issue of number < nil -> true situation
      [{price, _} | _] -> price
    end
    best_ask = case asks do
      [] -> nil
      [{price, _} | _] -> price
    end

    bids ++ asks
    |> Enum.reduce([], fn {price, qty} , acc ->
      v_bid = (fv - price - inv / lim)
      v_ask = v_bid * -1
      side = case v_bid > v_ask do
        true  -> :bid
        false -> :ask
      end
      bid_selftrade = price >= best_ask and side == :bid
      ask_selftrade = price <= best_bid and side == :ask
      case max(v_bid, v_ask) do
        value when value < margin or bid_selftrade or ask_selftrade ->
          acc
        value when value >= margin ->
          [{price, side, qty, value} | acc]
      end
    end)
    |> Enum.sort_by(fn {_, _, _, value} -> value end)
    |> Enum.reduce([], fn {price, side, qty, _}, acc ->
      bid_in_limit = inv < lim  and side == :bid
      ask_in_limit = inv > -lim and side == :ask
      case Enum.count(acc, fn {{_,s}, _} -> s == side end) < depth do
        true when bid_in_limit or ask_in_limit ->
          [{{price, side}, qty} | acc]
        _ ->
          acc
      end
    end)
    |> Map.new
  end
end
