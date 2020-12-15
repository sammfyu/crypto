defmodule Valuations do
  def get(fv, %{bids: bids, asks: asks}, inv, lim, margin, depth, tick) do
    {bid, _} = Enum.reduce_while(Enum.sort(bids ++ asks, :desc), {%{}, depth}, fn
      _,            {bid, depth} when depth == 0 or inv >= lim                      -> {:halt, {bid, depth}}
      {price, qty}, {bid, depth} when ((fv - price) / tick - inv / lim) >= margin   -> {:cont, {Map.put(bid, {price, :bid}, qty), depth - 1}}
      _,            {bid, depth}                                                    -> {:cont, {bid, depth}}
    end)

    {ask, _} = Enum.reduce_while(Enum.sort(bids ++ asks, :asc) , {%{}, depth}, fn
      _,            {ask, depth} when depth == 0 or inv <= -1 * lim                    -> {:halt, {ask, depth}}
      {price, qty}, {ask, depth} when -1 * ((fv - price) / tick - inv / lim) >= margin -> {:cont, {Map.put(ask,{price, :ask}, qty), depth - 1}}
      _,            {ask, depth}                                                       -> {:cont, {ask, depth}}
    end)
    Map.merge(bid, ask)
  end

  def drop_key(valuations, fill) do
    drop_key = Enum.reduce(valuations, [], fn {{price, side}, _}, acc ->
      case fill do
        {p, s} when (price <= p and s == :bid or price >= p and s == :ask) and side != s ->
          [{price, side} | acc]
        _ ->
          acc
      end
    end)
  Map.drop(valuations, drop_key)
  end
end





