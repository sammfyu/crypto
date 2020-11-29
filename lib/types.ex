defmodule BBO do
  defstruct instrument: nil,
            bids: nil,
            asks: nil
end

defmodule Order do
  defstruct account:         nil,
            market:          nil,
            instrument:      nil,
            type:            nil,
            order_id:        nil,
            client_order_id: nil,
            side:            nil,
            price:           nil,
            qty:             nil,
            active_qty:      nil,
            state:           nil,
            code:            nil
end

defmodule Fill do
  defstruct account:         nil,
            market:          nil,
            instrument:      nil,
            fill_type:       nil,
            fill_id:         nil,
            order_id:        nil,
            client_order_id: nil,
            side:            nil,
            price:           nil,
            qty:             nil
end


defmodule Model do
  defstruct fv:         nil,
            instrument: nil

end

