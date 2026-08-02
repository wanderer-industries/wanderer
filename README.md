# Wanderer

[Wanderer](https://wanderer.ltd/) is an #1 EVE Online mapper tool, light and fast alternative to Pathfinder. You can self-host Wanderer Community Edition or have us manage Wanderer for you in the cloud. Made and hosted in the EU 🇪🇺

![Wanderer](https://wanderer.ltd/images/news/09-10-map-features-guide/cover.png)

## Why Wanderer?

Here's what makes Wanderer a great Pathfinder alternative:

- **Clutter Free**: Wanderer provides simple interface and it cuts through the noise. No training necessary.
- **Lightweight, fast and secure**: Wanderer is lightweight and fast. It uses a self-hosted database and a self-hosted server.
- **See all your characaters on a single page**: Wanderer provides a simple interface to see all your characters on a single page.
- **SPA support**: Wanderer is built with modern web frameworks in core.
- **Active development**: Wanderer is actively developed and improved with new features and updates every week based on user feedback.

Interested to learn more? [Check more on our website](https://wanderer.ltd/news).

### Can Wanderer be self-hosted?

Wanderer is open source project and we have a free as in beer and self-hosted solution called [Wanderer Community Edition (CE)](https://wanderer.ltd/news/community-edition). Here are the differences between Wanderer and Wanderer CE:

|                               | Wanderer Cloud                                                                                                                                                                                                                                                                                                                              | Wanderer Community Edition                                                                                                                                                                                                                           |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Infrastructure management** | Easy and convenient. It takes 2 minutes to register your character and create a map. We manage everything so you don’t have to worry about anything and can focus on gameplay.                                                                                                                                                              | You do it all yourself. You need to get a server and you need to manage your infrastructure. You are responsible for installation, maintenance, upgrades, server capacity, uptime, backup, security, stability, consistency, loading time and so on. |
| **Release schedule**          | Continuously developed and improved with new features and updates multiple times per week.                                                                                                                                                                                                                                                  | Latest features and improvements won't be immediately available.                                                                                                                                                                                     |
| **Server location**           | All visitor data is exclusively processed on EU-owned cloud infrastructure. We keep your site data on a secure, encrypted and green energy powered server in Germany. This ensures that your site data is protected by the strict European Union data privacy laws and ensures compliance with GDPR. Your website data never leaves the EU. | You have full control and can host your instance on any server in any country that you wish. Host it on a server in your basement or host it with any cloud provider wherever you want, even those that are not GDPR compliant.                      |

Interested in self-hosting Wanderer CE on your server? Take a look at our [Wanderer CE installation instructions](https://github.com/wanderer-industries/community-edition/).

Wanderer CE is a community supported project and there are no guarantees that you will get support from the creators of Wanderer to troubleshoot your self-hosting issues. There is a [community supported forum](https://github.com/orgs/wanderer-industries/discussions/4) where you can ask for help.

Our only source of funding is your donations.

## Technology

Wanderer is a standard Elixir/Phoenix application backed by a PostgreSQL database for general data. On the frontend we use [TailwindCSS](https://tailwindcss.com/) for styling and React to make the map interactive.

## Development

### Setup

- Copy `.env.example` to `.env` and fill in the values

- Run `mix setup` to install and setup dependencies
- (optional step) run `make yarn` to install client dependencies

### Run

- Start server with `make server` or `make s`

Now you can visit [`localhost:8000`](http://localhost:8000) from your browser.

#### Using .devcontainer

- Run devcontainer
- Install additional dependencies inside Dev container
- `root@0d0a785313b6:/app# apt update`
- `root@0d0a785313b6:/app# curl -sL https://deb.nodesource.com/setup_18.x  | bash -`
- `root@0d0a785313b6:/app# apt-get install nodejs inotify-tools -y`
- `root@0d0a785313b6:/app# npm install -g yarn`
- `root@0d0a785313b6:/app# mix setup`

- See how to run server in #Run section

#### Using nix flakes

- Run `nix develop`
- Run local postgres server: `pg-setup` & `pg-start`
- See how to start server in #setup section

### Migrations

#### Reset database

`mix ecto.reset`

#### Run seed data

- `mix run priv/repo/seeds.exs`

#### Generate new migration

- `mix ash.codegen <name_of_migration>`
- `mix ash.migrate`

#### Generate cloak key

- `iex> 32 |> :crypto.strong_rand_bytes() |> Base.encode64()`
