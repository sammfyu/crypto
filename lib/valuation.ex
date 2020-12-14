defmodule Valuations do
  def get(fv, %{bids: bids, asks: asks}, inv, lim, margin, depth, tick, inv0 \\ 0) do
    # Here inv0 represent last inventory. This helps handle self-osillation.
    # This arguement default is zero. That means unless fill messages are triggers, then the inventory protection will be ignored. Please check handle fill
    # x is a threshold that handles this problem for some inventory in real number
    # bid_adj and ask_adj are logic to handle this problem, just a short hand for bid/ask adjustment
    # When inventory is within x and inv0 was large enough to make valuation move, adjustment effect triggered
    # This will pattern match the second condition within Enum.reduce_while, which ignores the first coming price, and then it turns adjustment to false
    #
    # There is 1 thing I think it's not the best idea
    # To deal with aggressive order on 1 side, I had to Enum.sort(bid++ask, :desc) (for bid) to pick ask side pries which has good bid valuation
    # This is accurate but not the fastest solution.
    x = lim * (0.5 + margin)
    bid_adj = (inv >= -x and inv <= x) and (inv0 >  x and inv0 <  lim)
    {bid, _, _} = Enum.reduce_while(Enum.sort(bids ++ asks, :desc), {%{}, depth, bid_adj}, fn
      _,            {bid, depth, bid_adj} when depth == 0 and bid_adj == false or inv >= lim                   -> {:halt, {bid, depth, bid_adj}}
      {price,   _}, {bid, depth, bid_adj} when ((fv - price) / tick - inv / lim) >= margin and bid_adj == true -> {:cont, {bid, depth, false}}
      {price, qty}, {bid, depth, bid_adj} when ((fv - price) / tick - inv / lim) >= margin                     -> {:cont, {Map.put(bid, {price, :bid}, qty), depth - 1, bid_adj}}
      _,            {bid, depth, bid_adj}                                                                      -> {:cont, {bid, depth, bid_adj}}
    end)

    ask_adj = (inv >= -x and inv <= x) and (inv0 < -x and inv0 > -lim)
    {ask, _, _} = Enum.reduce_while(Enum.sort(bids ++ asks, :asc) , {%{}, depth, ask_adj}, fn
      _,            {ask, depth, ask_adj} when depth == 0 and ask_adj == false or inv <= -1 * lim                   -> {:halt, {ask, depth, ask_adj}}
      {price,   _}, {ask, depth, ask_adj} when -1 * ((fv - price) / tick - inv / lim) >= margin and ask_adj == true -> {:cont, {ask, depth, false}}
      {price, qty}, {ask, depth, ask_adj} when -1 * ((fv - price) / tick - inv / lim) >= margin                     -> {:cont, {Map.put(ask, {price, :ask}, qty), depth - 1, ask_adj}}
      _,            {ask, depth, ask_adj}                                                                           -> {:cont, {ask, depth, ask_adj}}

    end)

    Map.merge(bid, ask)
  end
end





