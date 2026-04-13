# Seed script for example sponsor donations.
#
# Creates sample users, characters, a map, and donation transactions
# so the /sponsors page and /characters/:eve_id profile pages have data.
#
# Run with:
#   mix run priv/repo/seeds_sponsors.exs
#
require Logger
Logger.info("Seeding sponsor donation data...")

alias WandererApp.Repo

# Well-known EVE character data (real public info, no secrets)
characters_data = [
  %{
    eve_id: "96734492",
    name: "Oz Hasaki",
    corporation_id: 98_553_333,
    corporation_name: "Wormhole Wanderers",
    corporation_ticker: "W.W",
    alliance_id: nil,
    alliance_name: nil,
    alliance_ticker: nil
  },
  %{
    eve_id: "2119543215",
    name: "Katya Itzimansen",
    corporation_id: 98_681_432,
    corporation_name: "Anoikis Explorers",
    corporation_ticker: "A.EXP",
    alliance_id: 99_011_258,
    alliance_name: "Anoikis Coalition",
    alliance_ticker: "ANOK"
  },
  %{
    eve_id: "93568202",
    name: "Dmitriy Lancel",
    corporation_id: 98_712_045,
    corporation_name: "Signal Cartel",
    corporation_ticker: "1420.",
    alliance_id: 99_005_338,
    alliance_name: "EvE-Scout Enclave",
    alliance_ticker: "SCOUT"
  },
  %{
    eve_id: "94801715",
    name: "Heron Explorer",
    corporation_id: 98_553_333,
    corporation_name: "Wormhole Wanderers",
    corporation_ticker: "W.W",
    alliance_id: nil,
    alliance_name: nil,
    alliance_ticker: nil
  }
]

# Donation amounts (ISK) for each character — descending order
donation_amounts = [
  2_500_000_000.0,
  1_200_000_000.0,
  800_000_000.0,
  350_000_000.0
]

# ---------- Create users, characters, a map, and transactions ----------

Repo.transaction(fn ->
  # 1. Create a dummy map for the transactions (needs name + slug)
  {:ok, map} =
    WandererApp.Api.Map.new(%{
      name: "Seed Sponsors Map",
      slug: "seed-sponsors-map"
    })

  Logger.info("  Created map: #{map.id}")

  Enum.zip(characters_data, donation_amounts)
  |> Enum.each(fn {char_data, amount} ->
    # 2. Create a user
    {:ok, user} =
      WandererApp.Api.User
      |> Ash.Changeset.for_create(:create, %{
        name: char_data.name,
        hash: "seed_sponsor_#{char_data.eve_id}"
      })
      |> Ash.create()

    Logger.info("  Created user: #{user.id} (#{user.name})")

    # 3. Create a character linked to that user
    {:ok, character} =
      WandererApp.Api.Character
      |> Ash.Changeset.for_create(:create, %{
        eve_id: char_data.eve_id,
        name: char_data.name
      })
      |> Ash.create()

    # Assign user
    {:ok, character} = WandererApp.Api.Character.assign_user(character, %{user_id: user.id})

    # Update corporation info
    {:ok, character} =
      WandererApp.Api.Character.update_corporation(character, %{
        corporation_id: char_data.corporation_id,
        corporation_name: char_data.corporation_name,
        corporation_ticker: char_data.corporation_ticker
      })

    # Update alliance info (if present)
    if char_data.alliance_id do
      WandererApp.Api.Character.update_alliance(character, %{
        alliance_id: char_data.alliance_id,
        alliance_name: char_data.alliance_name,
        alliance_ticker: char_data.alliance_ticker
      })
    end

    Logger.info("  Created character: #{character.eve_id} (#{character.name})")

    # 4. Create a donation transaction (type: :in)
    {:ok, _txn} =
      WandererApp.Api.MapTransaction.create(%{
        map_id: map.id,
        user_id: user.id,
        type: :in,
        amount: amount
      })

    Logger.info("  Created donation: #{amount} ISK from #{char_data.name}")
  end)
end)

Logger.info("Sponsor seed data complete!")
