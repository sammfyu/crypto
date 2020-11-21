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
  defstruct FV:         nil,
            instrument: nil

end

defmodule Value do
  defstruct bid0: nil,
            bid1: nil,
            bid2: nil,
            ask0: nil,
            ask1: nil,
            ask2: nil
end
