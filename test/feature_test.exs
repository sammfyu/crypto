defmodule FeatureTest do
	use ExUnit.Case

	test "Generate feautres" do
		this = self()
		{:ok, pid} = GenServer.start_link(Feature, {this,
			%{instrument: "BTCP"}})

		# Data 1
		GenServer.cast(pid, %BBO{
      		bids: [{99, 10}, {98, 12}, {97, 199}],
      		asks: [{100, 10}, {101, 12}, {102, 5}, {103, 12}],
      		instrument: "BTCP"
		})
		refute_receive _

		# Data 2
		GenServer.cast(pid, %BBO{
      		bids: [{99, 10}, {98, 12}, {97, 199}],
      		asks: [{100, 10}, {101, 12}, {102, 5}, {103, 12}],
      		instrument: "BTCP"
		})
		refute_receive _

		# Data 3
		GenServer.cast(pid, %BBO{
      		bids: [{99, 10}, {98, 12}, {97, 199}],
      		asks: [{100, 10}, {101, 12}, {102, 5}, {103, 12}],
      		instrument: "BTCP"
		})
		refute_receive _

		# Data 4
		GenServer.cast(pid, %BBO{
      		bids: [{99, 10}, {98, 12}, {97, 199}],
      		asks: [{100, 10}, {101, 12}, {102, 5}, {103, 12}],
      		instrument: "BTCP"
		})
		refute_receive _

		# Data 5
		GenServer.cast(pid, %BBO{
      		bids: [{99, 10}, {98, 12}, {97, 199}],
      		asks: [{100, 10}, {101, 12}, {102, 5}, {103, 12}],
      		instrument: "BTCP"
		})
		refute_receive _


		# THis part should send FV 
		GenServer.cast(pid, %BBO{
			bids: [{98, 10}, {96, 12}, {92, 199}],
      		asks: [{103, 10}, {105, 12}, {107, 5}, {101, 12}],
      		instrument: "BTCP"
		})
		assert_receive {:"$gen_cast",
			{:input, [0.0, -1, 3, 0, 0]}}

	end
end