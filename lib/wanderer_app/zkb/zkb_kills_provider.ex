defmodule WandererApp.Zkb.KillsProvider do
  use Fresh
  require Logger

  alias WandererApp.Zkb.KillsProvider.Websocket

  defstruct [:connected]

  def handle_connect(status, headers, state),
    do: Websocket.handle_connect(status, headers, state)

  def handle_in(frame, state),
    do: Websocket.handle_in(frame, state)

  def handle_control(msg, state),
    do: Websocket.handle_control(msg, state)

  def handle_info(msg, state),
    do: Websocket.handle_info(msg, state)

  def handle_disconnect(code, reason, state),
    do: Websocket.handle_disconnect(code, reason, state)

  def handle_error(err, state),
    do: Websocket.handle_error(err, state)

  def handle_terminate(reason, state),
    do: Websocket.handle_terminate(reason, state)
end
