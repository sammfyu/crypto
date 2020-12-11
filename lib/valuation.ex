defmodule Valuations do
  def get(fv, %{bids: bids, asks: asks}, inv, lim, margin, depth) do
    {bids, _} = Enum.reduce_while(bids, {%{}, depth}, fn
      _, {bids, depth}            when depth == 0 or inv >= lim           -> {:halt, {bids, depth}}
      {price, qty}, {bids, depth} when (fv - price - inv / lim) >= margin -> {:cont, {Map.put(bids, {price, :bid}, qty), depth - 1}}
      _, {bids, depth}                                                    -> {:cont, {bids, depth}}
    end)

    {asks, _} = Enum.reduce_while(asks, {%{}, depth}, fn
      _, {asks, depth}            when depth == 0 or inv <= -1 * lim           -> {:halt, {asks, depth}}
      {price, qty}, {asks, depth} when -1 * (fv - price - inv / lim) >= margin -> {:cont, {Map.put(asks, {price, :ask}, qty), depth - 1}}
      _, {asks, depth}                                                         -> {:cont, {asks, depth}}
    end)

    Map.merge(bids, asks)
  end

end
