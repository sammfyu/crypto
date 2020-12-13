defmodule Valuations do
  def get(fv, %{bids: bids, asks: asks}, inv, d_inv, lim, margin, depth, tick) do
    bid_adj = inv >= 0 and d_inv < 0
    ask_adj = inv <= 0 and d_inv > 0
    {bid, _, _} = Enum.reduce_while(Enum.sort(bids ++ asks, :desc), {%{}, depth, bid_adj}, fn
      _,            {bid, depth, bid_adj} when depth == 0 and bid_adj == false or inv >= lim                   -> {:halt, {bid, depth, bid_adj}}
      {price,   _}, {bid, depth, bid_adj} when ((fv - price) / tick - inv / lim) >= margin and bid_adj == true -> {:cont, {bid, depth, false}}
      {price, qty}, {bid, depth, bid_adj} when ((fv - price) / tick - inv / lim) >= margin                     -> {:cont, {Map.put(bid, {price, :bid}, qty), depth - 1, bid_adj}}
      _,            {bid, depth, bid_adj}                                                                      -> {:cont, {bid, depth, bid_adj}}
    end)

    {ask, _, _} = Enum.reduce_while(Enum.sort(bids ++ asks, :asc) , {%{}, depth, ask_adj}, fn
      _,            {ask, depth, ask_adj} when depth == 0 and ask_adj == false or inv <= -1 * lim                   -> {:halt, {ask, depth, ask_adj}}
      {price,   _}, {ask, depth, ask_adj} when -1 * ((fv - price) / tick - inv / lim) >= margin and ask_adj == true -> {:cont, {ask, depth, false}}
      {price, qty}, {ask, depth, ask_adj} when -1 * ((fv - price) / tick - inv / lim) >= margin                     -> {:cont, {Map.put(ask, {price, :ask}, qty), depth - 1, ask_adj}}
      _,            {ask, depth, ask_adj}                                                                           -> {:cont, {ask, depth, ask_adj}}

    end)

    Map.merge(bid, ask)
  end
end





