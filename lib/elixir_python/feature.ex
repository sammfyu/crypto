defmodule Feature do
	use GenServer

	defstruct instrument: nil,
		pid:  nil,
		bbo1: nil,
		bbo2: nil,
		bbo3: nil,
		bbo4: nil,
		bbo5: nil


	@impl true
	def init({pid, %{} = config}) do
		state = %Feature{
			instrument: nil,
			pid:  pid,
			bbo1: nil,
			bbo2: nil,
			bbo3: nil,
			bbo4: nil,
			bbo5: nil
		}

		{:ok, state}
	end

	# Do nothing until states record all BBO memory
	def handle_cast(bbo, state = %{bbo5: nil}) do
 		state = %{state | bbo1: bbo, bbo2: state.bbo1, bbo3: state.bbo2, bbo4: state.bbo3, bbo5: state.bbo4}

 		#state |> IO.inspect()
 		{:noreply, state}
 	end

	# Main Function
	@impl true 
	def handle_cast(bbo, state) do
 		bbo.bids = [{bp0, bq0}, {bp1, bq1}, {bp2, bq2}, {bp3, bq3}, {bp4, bq4}]
 		bbo.asks = [{ap0, aq0}, {ap1, aq1}, {ap2, aq2}, {ap3, aq3}, {ap4, aq4}]

 		# Call all functions here
 		diff_bid_price = diff_bid_price(bbo, state)
 		diff_ask_price = diff_ask_price(bbo, state) 
 		diff_bid_qty   = diff_bid_qty(bbo, state)
 		diff_ask_qty   = diff_ask_qty(bbo, state)
 		mid_price      = 0.5 * (bp0 + ap0)
		bid1_cum_qty   = bq0 + bq1
		bid2_cum_qty   = bq0 + bq1 + bq2
		bid3_cum_qty   = bq0 + bq1 + bq2 + bq3
		bid4_cum_qty   = bq0 + bq1 + bq2 + bq3 + bq4
		ask1_cum_qty   = aq0 + aq1
		ask2_cum_qty   = aq0 + aq1 + aq2
		ask3_cum_qty   = aq0 + aq1 + aq2 + aq3
		ask4_cum_qty   = aq0 + aq1 + aq2 + aq3 + aq4
		imbalance      = (bq0 - aq0) / (bq0 + aq0)
		imbalance_cum1 = (bid1_cum_qty - ask1_cum_qty) / (bid1_cum_qty + ask1_cum_qty)
		imbalance_cum4 = (bid4_cum_qty - ask4_cum_qty) / (bid4_cum_qty + ask4_cum_qty)
		vwap           = (bp0 * bq0 + ap0 * aq0) / (bq0 + aq0)
		delta__vwap__mid_price = vwap - mid_price


		input = [
			ap0, 
			aq0, aq1, aq2, aq3, aq4,
			bp0,
			bq0, bq1, bq2, bq3, bq4,
			diff_bid_price,
			diff_ask_price,
			diff_bid_qty,
			diff_ask_qty,
			mid_price,
			bid1_cum_qty, bid2_cum_qty, bid3_cum_qty, bid4_cum_qty,
			ask1_cum_qty, ask2_cum_qty, ask3_cum_qty, ask4_cum_qty,
			imbalance,
			imbalance_cum_1,
			imbalance_cum_4,
			vwap,
			delta__vwap__mid_price
		]


 		# Call GenServer Cast
 		GenServer.cast(state.pid, {:input, input})

 		# Update States
 		state = %{state | bbo1: bbo, bbo2: state.bbo1, bbo3: state.bbo2, bbo4: state.bbo3, bbo5: state.bbo4}

 		state |> IO.inspect()
 		{:noreply, state}
 	end
 		
	
	# Compute book imbalance
	# Consider multiple levels orderbook
	def imbalance(%{bids: [{_, bq0} | _], asks: [{_, aq0} | _]}) do
		(bq0 - aq0) / (bq0 + aq0) 
	end

	def diff_bid_price(%{bids: [{bp0, _} | _]}, %Feature{bbo1: %{bids: [{bp1, _} | _]}}) do
		(bp0 - bp1)
	end

	def diff_ask_price(%{asks: [{ap0, _} | _]}, %Feature{bbo1: %{asks: [{ap1, _} | _]}}) do
		(ap0 - ap1)
	end

	def diff_bid_qty(%{bids: [{_, bq0} | _]}, %Feature{bbo1: %{bids: [{_, bq1} | _]}}) do
		(bq0 - bq1)
	end

	def diff_ask_qty(%{asks: [{_, aq0} | _]}, %Feature{bbo1: %{asks: [{_, aq1} | _]}}) do
		(aq0 - aq1)
	end

end
