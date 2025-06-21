defmodule WandererApp.Test.EsiMock do
  @moduledoc """
  Test-specific ESI mock implementations.

  This module provides configurable mock responses for EVE ESI API calls during tests.
  It can be configured to return specific data or errors for different test scenarios.
  """

  use GenServer

  # Client API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  def set_character_info(pid \\ __MODULE__, character_id, response) do
    GenServer.call(pid, {:set_character_info, character_id, response})
  end

  def set_corporation_info(pid \\ __MODULE__, corporation_id, response) do
    GenServer.call(pid, {:set_corporation_info, corporation_id, response})
  end

  def set_alliance_info(pid \\ __MODULE__, alliance_id, response) do
    GenServer.call(pid, {:set_alliance_info, alliance_id, response})
  end

  def reset(pid \\ __MODULE__) do
    GenServer.call(pid, :reset)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    {:ok,
     %{
       characters: %{},
       corporations: %{},
       alliances: %{}
     }}
  end

  @impl true
  def handle_call({:set_character_info, character_id, response}, _from, state) do
    new_state = put_in(state, [:characters, character_id], response)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:set_corporation_info, corporation_id, response}, _from, state) do
    new_state = put_in(state, [:corporations, corporation_id], response)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:set_alliance_info, alliance_id, response}, _from, state) do
    new_state = put_in(state, [:alliances, alliance_id], response)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{characters: %{}, corporations: %{}, alliances: %{}}}
  end

  @impl true
  def handle_call({:get_character_info, character_id}, _from, state) do
    response = Map.get(state.characters, character_id, :not_configured)
    {:reply, response, state}
  end

  @impl true
  def handle_call({:get_corporation_info, corporation_id}, _from, state) do
    response = Map.get(state.corporations, corporation_id, :not_configured)
    {:reply, response, state}
  end

  @impl true
  def handle_call({:get_alliance_info, alliance_id}, _from, state) do
    response = Map.get(state.alliances, alliance_id, :not_configured)
    {:reply, response, state}
  end

  # Helper functions for use in tests

  def get_configured_response(type, id, pid \\ __MODULE__) do
    GenServer.call(pid, {:"get_#{type}_info", id})
  end
end
