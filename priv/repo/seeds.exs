# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
require Logger
Logger.configure(level: :info)

WandererApp.EveDataService.update_eve_data()
