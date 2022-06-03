defmodule PubsubliveWeb.Ticker do
  use Phoenix.LiveView

  # Boot up the process and initialize state.  State is maintained in the socket.
  # Specifically assigns is used for application state.  Params will track http params
  # and URL params
  #
  # In this example we are:
  # 1. Booting up the process for the user and connecting their client
  # 2. Listening to the internal "notifications" pubsub that will broadcast events coming
  #    from Kafka
  # 3. Setting up initital state to show the users (a simple hash with tables and ids)
  def mount(_params, _session, socket) do
    PubsubliveWeb.Endpoint.subscribe("notifications")

    # Could be an HTTP / GraphQL query (perhaps more memory efficient to manage elsewhere)
    selections = [
      # {id, name, value}
      {"1", "home", "1"}
    ]

    {:ok, assign(socket, :selections, selections)}
  end

  # Now we render the page from the intial mount/bootstrap above
  # We need to use LiveView Components to only send state for that one item in the list
  # Otherwise, on change the entire payload will send to the wire vs the state maintained
  # In the component by the "id" passed
  def render(assigns) do
    ~H"""
    <div class="flex flex-row flex-wrap justify-center text-xs">

      <div class="flex flex-row w-full mb-2 justify-between bg-slate-100">
        <div class="w-32">
          <div class="p-1 pl-2"> Event </div>
        </div>
        <div class="flex flex-row justify-end">
          <div class="w-14 py-1 mr-1 text-center"> Price</div>
        </div>
      </div>

      <%= for {id, name, value} <- @selections do %>
      <div class="flex flex-row w-full py-1 justify-between ">
        <% event_id = "event#{id}" %>
        <.live_component module={PubsubliveWeb.EventComponent} id={event_id} name={name}/>

        <div class="flex flex-row ">
          <% chart_id = "chart#{id}" %>
          <div class="py-2" phx-update="ignore" phx-hook="Sparkline" id={chart_id}></div>
          <.live_component module={PubsubliveWeb.PriceComponent}  id={id} name={name} value={value}/>
        </div>
      </div>
      <% end %>
    </div>
    """
  end

  # This is a poorly peformant example as it sends the ENTIRE payload on any update, must pull into a component
  # that can manage their own state
  # def render(assigns) do
  #   ~H"""
  #   <table>
  #   <%= for {id, name, value} <- @selections do %>
  #   <div>
  #     <span> <%= id %> <%= name %> <%= value %> </span>
  #   </div>
  #   <% end %>
  #   </table>
  #   """
  # end

  # Assumes fits the contract {id, name, value} from Broadway
  def handle_info(message, socket) do
    selections = update_selections(socket.assigns.selections, message)

    # manually send an event to the graphing hook, not needed if wasn't graphing
    # push_event(socket, "new-data", "test")

    {:noreply, assign(socket, :selections, selections)}
  end

  def update_selections([], message), do: [message]

  def update_selections([_head = {id, _name, _value} | tail], {id, new_name, new_value}),
    do: [{id, new_name, new_value} | tail]

  def update_selections([head | tail], message), do: [head | update_selections(tail, message)]
end
