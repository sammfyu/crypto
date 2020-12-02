defmodule Valuations do
  def get(fv, %{bids: bids, asks: asks}, inv, qty_limit) do
    bid_valuation = Enum.map(bids, fn {p, _} ->
      value = fv - p - inv / qty_limit
      {{p, :bid}, value}
    end)

    ask_valuation = Enum.map(asks, fn {p, _} ->
      value = fv - p - inv / qty_limit
      {{p, :ask}, -1 * value}
    end)

    bid_valuation ++ ask_valuation
    |> Map.new
  end
end
