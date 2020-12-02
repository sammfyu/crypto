defmodule Valuations do
  def get(fv, %{bids: bids, asks: asks}, inv, qty_limit) do
    bid_valuation = Enum.map(bids, fn {p, _} ->
      value = fv - p - inv / qty_limit
      {p, %{v_bid: value, v_ask: -1 * value, side: :bid}}
    end)

    ask_valuation = Enum.map(asks, fn {p, _} ->
      value = fv - p - inv / qty_limit
      {p, %{v_bid: value, v_ask: -1 * value, side: :ask}}
    end)

    bid_valuation ++ ask_valuation
    |> Map.new
  end
end
