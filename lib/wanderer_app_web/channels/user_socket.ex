defmodule WandererAppWeb.UserSocket do
  use Phoenix.Socket

  # External events channel for webhooks/WebSocket delivery
  channel "external_events:map:*", WandererAppWeb.MapEventsChannel

  @impl true
  def connect(params, socket, connect_info) do
    # Extract API key from connection params
    # Client should connect with: /socket/websocket?api_key=<key>
    require Logger
    
    # Log connection attempt for security auditing
    remote_ip = get_remote_ip(connect_info)
    Logger.info("WebSocket connection attempt from #{remote_ip}")
    
    case params["api_key"] do
      api_key when is_binary(api_key) and api_key != "" ->
        # Store the API key in socket assigns for channel authentication
        # Full validation happens in channel join where we have the map context
        socket = socket
          |> assign(:api_key, api_key)
          |> assign(:remote_ip, remote_ip)
        
        Logger.info("WebSocket connection accepted from #{remote_ip}, pending channel authentication")
        {:ok, socket}
      
      _ ->
        # Require API key for external events
        Logger.warning("WebSocket connection rejected - missing API key from #{remote_ip}")
        :error
    end
  end
  
  # Extract remote IP from connection info
  defp get_remote_ip(connect_info) do
    case connect_info do
      %{peer_data: %{address: {a, b, c, d}}} ->
        "#{a}.#{b}.#{c}.#{d}"
      
      %{x_headers: headers} ->
        # Check for X-Forwarded-For or X-Real-IP headers (for proxied connections)
        Enum.find_value(headers, "unknown", fn
          {"x-forwarded-for", ip} -> String.split(ip, ",") |> List.first() |> String.trim()
          {"x-real-ip", ip} -> ip
          _ -> nil
        end)
      
      _ ->
        "unknown"
    end
  end

  @impl true
  def id(_socket), do: nil
end